package com.shoply.app

import android.app.Application
import android.content.Context
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import android.util.Log
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.GoogleAuthProvider
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.messaging.FirebaseMessaging
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.util.UUID

class MainViewModel(application: Application) : AndroidViewModel(application) {
    private val inviteLogTag = "ShoplyInvite"
    private val auth = FirebaseAuth.getInstance()
    private val repo = ListRepository()
    private val _user = MutableStateFlow(auth.currentUser)
    val user: StateFlow<com.google.firebase.auth.FirebaseUser?> = _user

    private val _lists = MutableStateFlow<List<ShoppingList>>(emptyList())
    val lists: StateFlow<List<ShoppingList>> = _lists

    private val _selectedListId = MutableStateFlow<String?>(null)
    val selectedListId: StateFlow<String?> = _selectedListId

    private val _items = MutableStateFlow<List<ShoppingItem>>(emptyList())
    val items: StateFlow<List<ShoppingItem>> = _items

    private val _members = MutableStateFlow<List<MemberViewData>>(emptyList())
    val members: StateFlow<List<MemberViewData>> = _members

    private val _invites = MutableStateFlow<List<InviteViewData>>(emptyList())
    val invites: StateFlow<List<InviteViewData>> = _invites

    private val _currentRole = MutableStateFlow<String?>(null)
    val currentRole: StateFlow<String?> = _currentRole

    private val _pendingInvites = MutableStateFlow<List<PendingInvite>>(emptyList())
    val pendingInvites: StateFlow<List<PendingInvite>> = _pendingInvites

    private val _inviteActionError = MutableStateFlow<String?>(null)
    val inviteActionError: StateFlow<String?> = _inviteActionError

    private var listListener: ListenerRegistration? = null
    private var itemListener: ListenerRegistration? = null
    private var memberListener: ListenerRegistration? = null
    private var inviteListener: ListenerRegistration? = null
    private var pendingInviteListener: ListenerRegistration? = null
    private var isCreatingDefault = false
    private var pendingInviteToken: String? = null
    private var pendingInviteListId: String? = null
    private var rawMembers: List<ListMember> = emptyList()
    private val profileCache = mutableMapOf<String, MemberProfile>()

    private val prefs = application.getSharedPreferences("shoply", Context.MODE_PRIVATE)
    private val db = FirebaseFirestore.getInstance()

    init {
        auth.addAuthStateListener { firebaseAuth ->
            handleUserChanged(firebaseAuth.currentUser)
        }
    }

    fun signInWithGoogle(idToken: String) {
        val credential = GoogleAuthProvider.getCredential(idToken, null)
        auth.signInWithCredential(credential)
    }

    fun signOut() {
        auth.signOut()
    }

    fun createList(title: String) {
        val userId = _user.value?.uid ?: return
        val trimmed = title.trim()
        if (trimmed.isEmpty()) return
        repo.createList(trimmed, userId) { listId ->
            listId?.let { selectList(it) }
        }
    }

    fun selectList(listId: String) {
        val userId = _user.value?.uid ?: return
        _selectedListId.value = listId
        prefs.edit().putString("lastListId_$userId", listId).apply()
        repo.updateLastList(userId, listId)
        bindItems(listId)
        bindMembers(listId)
    }

    fun refreshSelectedList() {
        val listId = _selectedListId.value ?: return
        bindItems(listId)
    }

    fun addItem(name: String, barcode: String? = null) {
        val listId = _selectedListId.value ?: return
        val userId = _user.value?.uid ?: return
        if (name.trim().isEmpty()) return
        repo.addItem(listId, name, barcode, userId)
    }

    fun toggleBought(item: ShoppingItem) {
        val listId = _selectedListId.value ?: return
        val userId = _user.value?.uid ?: return
        repo.toggleBought(listId, item, userId)
    }

    fun sendInvite(
        email: String,
        role: String,
        onInviteCreated: (String) -> Unit,
        onError: (String) -> Unit
    ) {
        val listId = _selectedListId.value ?: run {
            onError("Select a list before sending an invite.")
            return
        }
        val userId = _user.value?.uid ?: run {
            onError("Please sign in before inviting someone.")
            return
        }
        val trimmed = email.trim()
        if (trimmed.isEmpty()) {
            onError("Please enter a valid email address.")
            return
        }
        val creatorName = _user.value?.displayName ?: ""
        val creatorEmail = _user.value?.email ?: ""
        val listTitle = _lists.value.firstOrNull { it.id == listId }?.title ?: "Shoply list"
        val token = UUID.randomUUID().toString().replace("-", "")
        val emailLower = trimmed.lowercase()
        val allowedEmails = if (trimmed == emailLower) listOf(trimmed) else listOf(trimmed, emailLower)
        val inviteRef = db.collection("lists").document(listId).collection("invites").document()
        val data = hashMapOf(
            "listId" to listId,
            "listTitle" to listTitle,
            "email" to trimmed,
            "emailLower" to emailLower,
            "allowedEmails" to allowedEmails,
            "role" to role,
            "status" to "pending",
            "token" to token,
            "createdBy" to userId,
            "createdAt" to com.google.firebase.firestore.FieldValue.serverTimestamp(),
            "creatorName" to creatorName,
            "creatorEmail" to creatorEmail
        )
        val inboxData = HashMap(data).apply {
            put("listInviteId", inviteRef.id)
        }
        val inboxRef = db.collection("invitesInbox").document(token)
        db.runBatch { batch ->
            batch.set(inviteRef, data)
            batch.set(inboxRef, inboxData)
        }
            .addOnSuccessListener { onInviteCreated(token) }
            .addOnFailureListener { error ->
                onError(error.localizedMessage ?: "Unable to send invite.")
            }
    }

    fun handleInviteLink(uri: Uri) {
        val queryToken = uri.getQueryParameter("token")?.trim()
        if (!queryToken.isNullOrBlank()) {
            handleInviteToken(queryToken)
            return
        }
        val segments = uri.pathSegments
        val inviteIndex = segments.indexOf("invite")
        if (inviteIndex != -1 && segments.size > inviteIndex + 1) {
            handleInviteToken(segments[inviteIndex + 1])
        }
    }

    fun handleInviteToken(token: String) {
        val trimmed = token.trim()
        if (trimmed.isEmpty()) return
        if (_user.value == null) {
            pendingInviteToken = trimmed
        } else {
            acceptInvite(trimmed)
        }
    }

    fun clearInviteActionError() {
        _inviteActionError.value = null
    }

    private fun acceptInvite(token: String) {
        val trimmed = token.trim()
        if (trimmed.isEmpty()) return
        val user = auth.currentUser
        if (user == null) {
            Log.w(inviteLogTag, "acceptInvite: no current user")
            _inviteActionError.value = "Please sign in again to accept the invite."
            return
        }
        val invite = _pendingInvites.value.firstOrNull { it.token == trimmed }
        val updates = hashMapOf(
            "status" to "accepted",
            "acceptedAt" to FieldValue.serverTimestamp(),
            "acceptedBy" to user.uid
        )
        val docId = invite?.id
        if (!docId.isNullOrBlank()) {
            updateInviteDoc(docId, trimmed, updates, invite.listId, user.uid)
            return
        }
        db.collection("invitesInbox")
            .whereEqualTo("token", trimmed)
            .limit(1)
            .get()
            .addOnSuccessListener { snapshot ->
                val doc = snapshot.documents.firstOrNull()
                if (doc == null) {
                    _inviteActionError.value = "Accept failed (NOT_FOUND). Invitation not found. Attempt: invitesInbox where token=='$trimmed'"
                    return@addOnSuccessListener
                }
                val listId = doc.getString("listId")
                updateInviteDoc(doc.id, trimmed, updates, listId, user.uid)
            }
            .addOnFailureListener { error ->
                val firestoreError = error as? com.google.firebase.firestore.FirebaseFirestoreException
                val code = firestoreError?.code?.name ?: "UNKNOWN"
                val message = firestoreError?.message ?: error.localizedMessage ?: "Unable to accept invite."
                val attempt = "invitesInbox where token=='$trimmed'"
                Log.w(inviteLogTag, "acceptInvite: invitesInbox query failed [$code] $message")
                _inviteActionError.value = "Accept failed ($code). $message. Attempt: $attempt"
            }
    }

    private fun updateInviteDoc(
        docId: String,
        token: String,
        updates: Map<String, Any>,
        listId: String?,
        uid: String
    ) {
        db.collection("invitesInbox").document(docId).update(updates)
            .addOnSuccessListener {
                Log.d(inviteLogTag, "acceptInvite: invitesInbox updated")
                pendingInviteListId = listId
            }
            .addOnFailureListener { error ->
                val firestoreError = error as? com.google.firebase.firestore.FirebaseFirestoreException
                val code = firestoreError?.code?.name ?: "UNKNOWN"
                val message = firestoreError?.message ?: error.localizedMessage ?: "Unable to accept invite."
                val attempt = "invitesInbox/$docId (token:'$token') update {status:'accepted', acceptedAt:serverTimestamp, acceptedBy:'$uid'}"
                Log.w(inviteLogTag, "acceptInvite: invitesInbox update failed [$code] $message")
                _inviteActionError.value = "Accept failed ($code). $message. Attempt: $attempt"
            }
    }

    fun updateMemberRole(memberId: String, role: String) {
        val listId = _selectedListId.value ?: return
        if (_currentRole.value != "owner") return
        repo.updateMemberRole(listId, memberId, role)
    }

    fun removeMember(memberId: String) {
        val listId = _selectedListId.value ?: return
        if (_currentRole.value != "owner") return
        repo.removeMember(listId, memberId)
    }

    fun revokeInvite(inviteId: String) {
        val listId = _selectedListId.value ?: return
        if (_currentRole.value != "owner") return
        repo.revokeInvite(listId, inviteId)
    }

    private fun handleUserChanged(user: com.google.firebase.auth.FirebaseUser?) {
        _user.value = user
        listListener?.remove()
        itemListener?.remove()
        memberListener?.remove()
        inviteListener?.remove()
        pendingInviteListener?.remove()
        _lists.value = emptyList()
        _items.value = emptyList()
        _members.value = emptyList()
        _invites.value = emptyList()
        _pendingInvites.value = emptyList()
        _selectedListId.value = null
        _currentRole.value = null
        profileCache.clear()
        rawMembers = emptyList()

        if (user == null) {
            return
        }

        repo.ensureUserProfile(user)
        PushTokenStore.sync(getApplication())
        FirebaseMessaging.getInstance().token.addOnSuccessListener { token ->
            PushTokenStore.updateToken(getApplication(), token)
        }
        listListener = repo.listenToLists(user.uid) { lists ->
            _lists.value = lists
            selectListIfNeeded(user.uid)
            if (lists.isEmpty()) {
                createDefaultListIfNeeded(user.uid)
            }
        }

        pendingInviteListener = repo.listenToPendingInvites(user.email?.lowercase()) { invites ->
            _pendingInvites.value = invites.sortedByDescending { it.createdAt }
        }

        consumePendingInviteIfNeeded()
    }

    private fun selectListIfNeeded(userId: String) {
        val selected = _selectedListId.value
        if (selected != null && _lists.value.any { it.id == selected }) {
            return
        }
        val pending = pendingInviteListId
        if (pending != null && _lists.value.any { it.id == pending }) {
            pendingInviteListId = null
            selectList(pending)
            return
        }
        val stored = prefs.getString("lastListId_$userId", null)
        val next = when {
            stored != null && _lists.value.any { it.id == stored } -> stored
            _lists.value.isNotEmpty() -> _lists.value.first().id
            else -> null
        }
        next?.let { selectList(it) }
    }

    private fun bindItems(listId: String) {
        itemListener?.remove()
        itemListener = repo.listenToItems(listId) { items ->
            _items.value = items
        }
    }

    private fun bindMembers(listId: String) {
        val userId = _user.value?.uid ?: return
        memberListener?.remove()
        inviteListener?.remove()
        _members.value = emptyList()
        _invites.value = emptyList()
        _currentRole.value = null
        rawMembers = emptyList()
        profileCache.clear()

        memberListener = repo.listenToMembers(listId) { members ->
            rawMembers = members
            val role = members.firstOrNull { it.id == userId }?.role
            _currentRole.value = role
            updateMemberViewData(userId)
            fetchProfilesIfNeeded(members)
            updateInviteListenerIfNeeded(listId)
        }
    }

    private fun fetchProfilesIfNeeded(members: List<ListMember>) {
        for (member in members) {
            if (profileCache.containsKey(member.id)) continue
            db.collection("users").document(member.id).get().addOnSuccessListener { snapshot ->
                val data = snapshot.data ?: emptyMap<String, Any>()
                val profile = MemberProfile(
                    name = data["displayName"] as? String ?: "",
                    email = data["email"] as? String ?: ""
                )
                profileCache[member.id] = profile
                val userId = _user.value?.uid ?: return@addOnSuccessListener
                updateMemberViewData(userId)
            }
        }
    }

    private fun updateMemberViewData(userId: String) {
        val rows = rawMembers.map { member ->
            val profile = profileCache[member.id]
            val displayName = profile?.name ?: ""
            val email = profile?.email ?: ""
            val name = if (displayName.isNotEmpty()) displayName else if (email.isNotEmpty()) email else member.id
            MemberViewData(
                id = member.id,
                name = name,
                email = email,
                role = member.role,
                isCurrentUser = member.id == userId
            )
        }.sortedBy { rolePriority(it.role) }

        _members.value = rows
    }

    private fun updateInviteListenerIfNeeded(listId: String) {
        if (_currentRole.value == "owner") {
            if (inviteListener == null) {
                inviteListener = repo.listenToInvites(listId) { invites ->
                    _invites.value = invites.map {
                        InviteViewData(id = it.id, email = it.email, role = it.role, status = it.status)
                    }
                }
            }
        } else {
            inviteListener?.remove()
            inviteListener = null
            _invites.value = emptyList()
        }
    }

    private fun rolePriority(role: String): Int {
        return when (role) {
            "owner" -> 0
            "editor" -> 1
            else -> 2
        }
    }

    private fun consumePendingInviteIfNeeded() {
        val token = pendingInviteToken ?: return
        if (_user.value == null) return
        pendingInviteToken = null
        acceptInvite(token)
    }

    private fun createDefaultListIfNeeded(userId: String) {
        if (isCreatingDefault) return
        if (_lists.value.any { it.title.equals("Grocery", ignoreCase = true) }) return
        isCreatingDefault = true
        repo.createList("Grocery", userId) { listId ->
            listId?.let { selectList(it) }
            isCreatingDefault = false
        }
    }
}

private data class MemberProfile(
    val name: String,
    val email: String
)
