import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import * as crypto from "crypto";

admin.initializeApp();
const db = admin.firestore();

const inviteUrlBase =
  functions.config().app?.invite_url || process.env.INVITE_URL || "https://shoply.app/invite";
const publicCallable = functions.runWith({ invoker: "public" }).https.onCall;

function requireAuth(context: functions.https.CallableContext) {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }
  return context.auth.uid;
}

function normalizeEmail(email: string) {
  const trimmed = email.trim();
  const lower = trimmed.toLowerCase();
  const isValid = /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(lower);
  if (!isValid) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid email");
  }
  return { email: trimmed, emailLower: lower };
}

function validateRole(role?: string) {
  if (role === "owner") {
    throw new functions.https.HttpsError("invalid-argument", "Owner role not allowed in invites");
  }
  return role === "viewer" ? "viewer" : "editor";
}

export const sendInvite = publicCallable(async (data, context) => {
  const uid = requireAuth(context);
  const listId = String(data.listId || "").trim();
  if (!listId) {
    throw new functions.https.HttpsError("invalid-argument", "listId required");
  }

  const { email, emailLower } = normalizeEmail(String(data.email || ""));
  const role = validateRole(data.role);

  const memberSnap = await db
    .collection("lists")
    .doc(listId)
    .collection("members")
    .doc(uid)
    .get();

  const memberRole = memberSnap.data()?.role;
  if (!memberSnap.exists || (memberRole !== "owner" && memberRole !== "editor")) {
    throw new functions.https.HttpsError("permission-denied", "Not allowed to invite");
  }

  const token = crypto.randomBytes(24).toString("hex");
  const inviteRef = db.collection("lists").doc(listId).collection("invites").doc();
  const inboxRef = db.collection("invitesInbox").doc(token);
  const expiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + 7 * 24 * 60 * 60 * 1000);
  const listSnap = await db.collection("lists").doc(listId).get();
  const listTitle = listSnap.data()?.title || "Shoply list";
  const allowedEmails = Array.from(new Set([email, emailLower]));

  await inviteRef.set({
    email,
    role,
    token,
    status: "pending",
    listId,
    listTitle,
    emailLower,
    allowedEmails,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: uid,
    expiresAt
  });

  await inboxRef.set({
    email,
    emailLower,
    allowedEmails,
    role,
    status: "pending",
    listId,
    listTitle,
    token,
    listInviteId: inviteRef.id,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: uid,
    expiresAt
  });

  const inviteLink = `${inviteUrlBase}?token=${token}`;
  functions.logger.info("Invite created. Send email from client.", { inviteLink });

  return { inviteId: inviteRef.id, inviteLink };
});

export const notifyInviteCreated = functions.firestore
  .document("lists/{listId}/invites/{inviteId}")
  .onCreate(async (snap) => {
    return;
    const invite = snap.data();
    if (!invite || invite.status !== "pending") {
      return;
    }

    const inviteEmailLower = String(invite.emailLower || invite.email || "").toLowerCase();
    if (!inviteEmailLower) {
      return;
    }

    const usersByLower = await db
      .collection("users")
      .where("emailLower", "==", inviteEmailLower)
      .get();
    const usersByEmail = usersByLower.empty
      ? await db.collection("users").where("email", "==", inviteEmailLower).get()
      : usersByLower;

    if (usersByEmail.empty) {
      return;
    }

    const tokens: string[] = [];
    const tokenRefs: Array<{ token: string; ref: admin.firestore.DocumentReference }> = [];

    for (const userDoc of usersByEmail.docs) {
      const tokenSnap = await userDoc.ref.collection("tokens").get();
      tokenSnap.forEach((doc) => {
        const token = doc.id;
        if (token) {
          tokens.push(token);
          tokenRefs.push({ token, ref: doc.ref });
        }
      });
    }

    if (tokens.length === 0) {
      return;
    }

    const listTitle = String(invite.listTitle || "Shoply list");
    const inviteToken = String(invite.token || "");

    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: "Shoply invite",
        body: `You were invited to ${listTitle}`
      },
      data: {
        listId: String(invite.listId || ""),
        inviteId: snap.id,
        token: inviteToken
      }
    });

    const failed = response.responses
      .map((res, index) => ({ res, index }))
      .filter(({ res }) => !res.success)
      .map(({ res, index }) => ({ error: res.error, token: tokens[index] }));

    const invalidCodes = new Set([
      "messaging/registration-token-not-registered",
      "messaging/invalid-registration-token"
    ]);

    const deletions = failed
      .filter(({ error }) => error && invalidCodes.has(error.code || ""))
      .map(({ token }) => tokenRefs.find((ref) => ref.token == token)?.ref)
      .filter((ref): ref is FirebaseFirestore.DocumentReference => Boolean(ref))
      .map((ref) => ref.delete());

    await Promise.all(deletions);
  });

export const acceptInvite = publicCallable(async (data, context) => {
  functions.logger.info("acceptInvite called", {
    hasAuth: Boolean(context.auth),
    hasIdToken: Boolean(data?.idToken),
    tokenLength: String(data?.token || "").length,
    idTokenLength: String(data?.idToken || "").length
  });
  let uid = context.auth?.uid;
  if (!uid) {
    const idToken = String(data.idToken || "").trim();
    if (!idToken) {
      throw new functions.https.HttpsError("unauthenticated", "Authentication required");
    }
    try {
      const decoded = await admin.auth().verifyIdToken(idToken);
      uid = decoded.uid;
    } catch (error) {
      functions.logger.warn("acceptInvite invalid idToken", { error });
      throw new functions.https.HttpsError("unauthenticated", "Authentication required");
    }
  }
  const token = String(data.token || "").trim();
  if (!token) {
    throw new functions.https.HttpsError("invalid-argument", "token required");
  }

  const inviteQuery = await db
    .collectionGroup("invites")
    .where("token", "==", token)
    .where("status", "==", "pending")
    .limit(1)
    .get();

  if (inviteQuery.empty) {
    throw new functions.https.HttpsError("not-found", "Invite not found");
  }

  const inviteDoc = inviteQuery.docs[0];
  const inviteData = inviteDoc.data();
  const listRef = inviteDoc.ref.parent.parent;
  if (!listRef) {
    throw new functions.https.HttpsError("internal", "Invalid invite location");
  }

  const now = admin.firestore.Timestamp.now();
  const expiresAt = inviteData.expiresAt as admin.firestore.Timestamp | undefined;
  if (expiresAt && expiresAt.toMillis() < now.toMillis()) {
    await inviteDoc.ref.update({ status: "expired" });
    const inboxRef = db.collection("invitesInbox").doc(token);
    const inboxSnap = await inboxRef.get();
    if (inboxSnap.exists) {
      await inboxRef.update({ status: "expired" });
    }
    throw new functions.https.HttpsError("failed-precondition", "Invite expired");
  }

  const role = validateRole(inviteData.role);

  const memberRef = listRef.collection("members").doc(uid);
  await memberRef.set(
    {
      role,
      addedAt: admin.firestore.FieldValue.serverTimestamp(),
      addedBy: inviteData.createdBy || ""
    },
    { merge: true }
  );

  await listRef.update({
    memberIds: admin.firestore.FieldValue.arrayUnion(uid),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });

  await inviteDoc.ref.update({
    status: "accepted",
    acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
    acceptedBy: uid
  });

  const inboxRef = db.collection("invitesInbox").doc(token);
  const inboxSnap = await inboxRef.get();
  if (inboxSnap.exists) {
    await inboxRef.update({
      status: "accepted",
      acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
      acceptedBy: uid
    });
  }

  return { listId: listRef.id, role };
});

export const processInviteAccepted = functions.firestore
  .document("invitesInbox/{token}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (!after) {
      return;
    }
    if (before?.status === after.status) {
      return;
    }
    if (after.status !== "accepted") {
      return;
    }

    const listId = String(after.listId || "").trim();
    const uid = String(after.acceptedBy || "").trim();
    if (!listId || !uid) {
      functions.logger.warn("processInviteAccepted missing listId or uid", {
        token: context.params.token
      });
      return;
    }

    const now = admin.firestore.Timestamp.now();
    const expiresAt = after.expiresAt as admin.firestore.Timestamp | undefined;
    if (expiresAt && expiresAt.toMillis() < now.toMillis()) {
      await change.after.ref.update({ status: "expired" });
      return;
    }

    const role = validateRole(after.role);
    const listRef = db.collection("lists").doc(listId);
    const memberRef = listRef.collection("members").doc(uid);

    await memberRef.set(
      {
        role,
        addedAt: admin.firestore.FieldValue.serverTimestamp(),
        addedBy: after.createdBy || ""
      },
      { merge: true }
    );

    await listRef.update({
      memberIds: admin.firestore.FieldValue.arrayUnion(uid),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    const listInviteId = String(after.listInviteId || "").trim();
    if (listInviteId) {
      await listRef
        .collection("invites")
        .doc(listInviteId)
        .set(
          {
            status: "accepted",
            acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
            acceptedBy: uid
          },
          { merge: true }
        );
    } else {
      const inviteSnap = await listRef
        .collection("invites")
        .where("token", "==", context.params.token)
        .limit(1)
        .get();
      if (!inviteSnap.empty) {
        await inviteSnap.docs[0].ref.update({
          status: "accepted",
          acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
          acceptedBy: uid
        });
      }
    }

    if (!after.acceptedAt || after.acceptedBy !== uid) {
      await change.after.ref.update({
        acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
        acceptedBy: uid
      });
    }
  });
