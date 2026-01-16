import FirebaseAuth
import FirebaseFirestore
import Foundation

final class InviteService {
    private let db = Firestore.firestore()

    func sendInvite(
        listId: String,
        listTitle: String,
        createdBy: String,
        creatorName: String,
        creatorEmail: String,
        email: String,
        role: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let inviteRef = db.collection("lists").document(listId).collection("invites").document()
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let inboxRef = db.collection("invitesInbox").document(token)
        let emailLower = email.lowercased()
        let allowedEmails = email == emailLower ? [email] : [email, emailLower]
        let now = FieldValue.serverTimestamp()
        let data: [String: Any] = [
            "email": email,
            "emailLower": emailLower,
            "allowedEmails": allowedEmails,
            "role": role,
            "status": "pending",
            "listId": listId,
            "listTitle": listTitle,
            "token": token,
            "createdAt": now,
            "createdBy": createdBy,
            "creatorName": creatorName,
            "creatorEmail": creatorEmail
        ]

        var inboxData = data
        inboxData["listInviteId"] = inviteRef.documentID

        let batch = db.batch()
        batch.setData(data, forDocument: inviteRef)
        batch.setData(inboxData, forDocument: inboxRef)
        batch.commit { error in
            if let error {
                completion(.failure(error))
                return
            }
            completion(.success(token))
        }
    }

    func acceptInvite(
        token: String,
        documentId: String? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let user = Auth.auth().currentUser else {
            completion(.failure(NSError(domain: "Invite", code: 401, userInfo: nil)))
            return
        }
        let updates: [String: Any] = [
            "status": "accepted",
            "acceptedAt": FieldValue.serverTimestamp(),
            "acceptedBy": user.uid
        ]
        let inbox = db.collection("invitesInbox")
        if let documentId {
            inbox.document(documentId).updateData(updates) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
            return
        }
        inbox.whereField("token", isEqualTo: token).limit(to: 1).getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let doc = snapshot?.documents.first else {
                completion(.failure(InviteServiceError.notFound))
                return
            }
            inbox.document(doc.documentID).updateData(updates) { updateError in
                if let updateError = updateError {
                    completion(.failure(updateError))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
}

private enum InviteServiceError: LocalizedError {
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Invitation not found."
        }
    }
}
