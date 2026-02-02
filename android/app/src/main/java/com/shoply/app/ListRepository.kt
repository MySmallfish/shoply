package com.shoply.app

import com.google.firebase.auth.FirebaseUser
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration

class ListRepository {
    private val db = FirebaseFirestore.getInstance()

    fun listenToLists(userId: String, onChange: (List<ShoppingList>) -> Unit): ListenerRegistration {
        return db.collection("lists")
            .whereArrayContains("memberIds", userId)
            .addSnapshotListener { snapshot, _ ->
                val lists = snapshot?.documents?.map { it.toShoppingList() } ?: emptyList()
                onChange(lists.sortedByDescending { it.updatedAt })
            }
    }

    fun listenToItems(listId: String, onChange: (List<ShoppingItem>) -> Unit): ListenerRegistration {
        return db.collection("lists").document(listId).collection("items")
            .orderBy("createdAt")
            .addSnapshotListener { snapshot, _ ->
                val items = snapshot?.documents?.map { it.toShoppingItem() } ?: emptyList()
                val ordered = items.sortedWith(
                    compareByDescending<ShoppingItem> { it.quantity }
                        .thenByDescending { it.updatedAt }
                )
                onChange(ordered)
            }
    }

    fun listenToCatalogItems(userId: String, onChange: (List<CatalogItem>) -> Unit): ListenerRegistration {
        return db.collection("users").document(userId).collection("catalog")
            .orderBy("updatedAt", com.google.firebase.firestore.Query.Direction.DESCENDING)
            .addSnapshotListener { snapshot, _ ->
                val items = snapshot?.documents?.map { it.toCatalogItem() } ?: emptyList()
                onChange(items)
            }
    }

    fun listenToMembers(listId: String, onChange: (List<ListMember>) -> Unit): ListenerRegistration {
        return db.collection("lists").document(listId).collection("members")
            .addSnapshotListener { snapshot, _ ->
                val members = snapshot?.documents?.map { it.toListMember() } ?: emptyList()
                onChange(members)
            }
    }

    fun listenToInvites(listId: String, onChange: (List<ListInvite>) -> Unit): ListenerRegistration {
        return db.collection("lists").document(listId).collection("invites")
            .orderBy("createdAt")
            .addSnapshotListener { snapshot, _ ->
                val invites = snapshot?.documents?.map { it.toListInvite() } ?: emptyList()
                onChange(invites)
            }
    }

    fun listenToPendingInvites(
        emailLower: String?,
        onChange: (List<PendingInvite>) -> Unit
    ): ListenerRegistration {
        val trimmedLower = emailLower?.trim()?.lowercase().orEmpty()
        var query: com.google.firebase.firestore.Query = db.collection("invitesInbox")
        if (trimmedLower.isNotEmpty()) {
            query = query.whereEqualTo("emailLower", trimmedLower)
        }
        return query.addSnapshotListener { snapshot, _ ->
            val invites = snapshot?.documents?.mapNotNull { it.toPendingInvite() } ?: emptyList()
            onChange(invites.filter { it.status == "pending" })
        }
    }

    fun createList(title: String, ownerId: String, onComplete: (String?) -> Unit) {
        val listRef = db.collection("lists").document()
        val now = FieldValue.serverTimestamp()

        val listData = hashMapOf(
            "title" to title,
            "createdAt" to now,
            "updatedAt" to now,
            "createdBy" to ownerId,
            "memberIds" to listOf(ownerId)
        )

        val memberData = hashMapOf(
            "role" to "owner",
            "addedAt" to now,
            "addedBy" to ownerId
        )

        listRef.set(listData).addOnCompleteListener { listTask ->
            if (!listTask.isSuccessful) {
                onComplete(null)
                return@addOnCompleteListener
            }
            val memberRef = listRef.collection("members").document(ownerId)
            memberRef.set(memberData).addOnCompleteListener { memberTask ->
                onComplete(if (memberTask.isSuccessful) listRef.id else null)
            }
        }
    }

    fun updateListTitle(listId: String, title: String, onComplete: (Exception?) -> Unit) {
        db.collection("lists").document(listId).update(
            hashMapOf(
                "title" to title,
                "updatedAt" to FieldValue.serverTimestamp()
            )
        )
            .addOnSuccessListener { onComplete(null) }
            .addOnFailureListener { error -> onComplete(error) }
    }

    fun mergeLists(sourceListId: String, targetListId: String, onComplete: (Exception?) -> Unit) {
        val sourceRef = db.collection("lists").document(sourceListId).collection("items")
        val targetRef = db.collection("lists").document(targetListId).collection("items")

        targetRef.get()
            .addOnSuccessListener { targetSnapshot ->
                val existingKeys = targetSnapshot.documents.mapNotNull { itemKey(it.data) }.toSet()
                sourceRef.get()
                    .addOnSuccessListener { sourceSnapshot ->
                        val batch = db.batch()
                        var added = 0
                        sourceSnapshot.documents.forEach { doc ->
                            val data = doc.data
                            val key = itemKey(data)
                            if (key.isNullOrEmpty() || existingKeys.contains(key)) {
                                return@forEach
                            }
                            val payload = HashMap(data).apply {
                                put("createdAt", FieldValue.serverTimestamp())
                                put("updatedAt", FieldValue.serverTimestamp())
                            }
                            batch.set(targetRef.document(), payload)
                            added += 1
                        }

                        if (added == 0) {
                            deleteList(sourceListId, onComplete)
                            return@addOnSuccessListener
                        }

                        batch.commit()
                            .addOnSuccessListener { deleteList(sourceListId, onComplete) }
                            .addOnFailureListener { error -> onComplete(error) }
                    }
                    .addOnFailureListener { error -> onComplete(error) }
            }
            .addOnFailureListener { error -> onComplete(error) }
    }

    fun addItem(
        listId: String,
        name: String,
        barcode: String?,
        price: Double?,
        description: String?,
        icon: String?,
        userId: String
    ) {
        val itemRef = db.collection("lists").document(listId).collection("items").document()
        val now = FieldValue.serverTimestamp()
        val trimmed = name.trim()

        val data = hashMapOf(
            "name" to trimmed,
            "normalizedName" to normalizedName(trimmed),
            "quantity" to 1,
            "isBought" to false,
            "createdAt" to now,
            "createdBy" to userId,
            "updatedAt" to now
        )

        if (!barcode.isNullOrBlank()) {
            data["barcode"] = barcode
        }
        if (price != null) {
            data["price"] = price
        }
        if (!description.isNullOrBlank()) {
            data["description"] = description
        }
        if (!icon.isNullOrBlank()) {
            data["icon"] = icon
        }

        itemRef.set(data)
        touchList(listId)
    }

    fun updateItemDetails(
        listId: String,
        itemId: String,
        name: String,
        barcode: String?,
        price: Double?,
        description: String?,
        icon: String?
    ) {
        val itemRef = db.collection("lists").document(listId).collection("items").document(itemId)
        val trimmed = name.trim()
        if (trimmed.isEmpty()) return
        val updates = hashMapOf<String, Any>(
            "name" to trimmed,
            "normalizedName" to normalizedName(trimmed),
            "updatedAt" to FieldValue.serverTimestamp()
        )
        updates["barcode"] = if (barcode.isNullOrBlank()) FieldValue.delete() else barcode
        updates["price"] = price ?: FieldValue.delete()
        updates["description"] = if (description.isNullOrBlank()) FieldValue.delete() else description
        updates["icon"] = if (icon.isNullOrBlank()) FieldValue.delete() else icon
        itemRef.update(updates)
        touchList(listId)
    }

    fun toggleBought(listId: String, item: ShoppingItem, userId: String) {
        val itemRef = db.collection("lists").document(listId).collection("items").document(item.id)
        val updates = hashMapOf<String, Any>(
            "isBought" to !item.isBought,
            "updatedAt" to FieldValue.serverTimestamp()
        )

        if (item.isBought) {
            updates["boughtAt"] = FieldValue.delete()
            updates["boughtBy"] = FieldValue.delete()
        } else {
            updates["boughtAt"] = FieldValue.serverTimestamp()
            updates["boughtBy"] = userId
        }

        itemRef.update(updates)
        touchList(listId)
    }

    fun setBought(listId: String, itemId: String, isBought: Boolean, userId: String) {
        val itemRef = db.collection("lists").document(listId).collection("items").document(itemId)
        val updates = hashMapOf<String, Any>(
            "isBought" to isBought,
            "updatedAt" to FieldValue.serverTimestamp()
        )

        if (isBought) {
            updates["boughtAt"] = FieldValue.serverTimestamp()
            updates["boughtBy"] = userId
        } else {
            updates["boughtAt"] = FieldValue.delete()
            updates["boughtBy"] = FieldValue.delete()
        }

        itemRef.update(updates)
        touchList(listId)
    }

    fun deleteItem(listId: String, itemId: String) {
        val itemRef = db.collection("lists").document(listId).collection("items").document(itemId)
        itemRef.delete()
        touchList(listId)
    }

    fun adjustQuantity(
        listId: String,
        itemId: String,
        delta: Int,
        markUnbought: Boolean,
        barcode: String?,
        price: Double?,
        description: String?,
        icon: String?
    ) {
        val itemRef = db.collection("lists").document(listId).collection("items").document(itemId)
        db.runTransaction { transaction ->
            val snapshot = transaction.get(itemRef)
            val current = (snapshot.getLong("quantity")?.toInt() ?: 1)
            val next = current + delta
            val updates = hashMapOf<String, Any>(
                "quantity" to next,
                "updatedAt" to FieldValue.serverTimestamp()
            )
            if (markUnbought) {
                updates["isBought"] = false
                updates["boughtAt"] = FieldValue.delete()
                updates["boughtBy"] = FieldValue.delete()
            }
            if (!barcode.isNullOrBlank()) {
                updates["barcode"] = barcode
            }
            if (price != null) {
                updates["price"] = price
            }
            if (!description.isNullOrBlank()) {
                updates["description"] = description
            }
            if (!icon.isNullOrBlank()) {
                updates["icon"] = icon
            }
            transaction.update(itemRef, updates)
            null
        }
        touchList(listId)
    }

    fun updateQuantity(listId: String, itemId: String, quantity: Int, markUnbought: Boolean) {
        val itemRef = db.collection("lists").document(listId).collection("items").document(itemId)
        val updates = hashMapOf<String, Any>(
            "quantity" to quantity,
            "updatedAt" to FieldValue.serverTimestamp()
        )
        if (markUnbought) {
            updates["isBought"] = false
            updates["boughtAt"] = FieldValue.delete()
            updates["boughtBy"] = FieldValue.delete()
        }
        itemRef.update(updates)
        touchList(listId)
    }

    fun updateMemberRole(listId: String, memberId: String, role: String) {
        val memberRef = db.collection("lists").document(listId).collection("members").document(memberId)
        memberRef.update(
            hashMapOf(
                "role" to role,
                "updatedAt" to FieldValue.serverTimestamp()
            )
        )
        touchList(listId)
    }

    fun removeMember(listId: String, memberId: String) {
        val listRef = db.collection("lists").document(listId)
        val memberRef = listRef.collection("members").document(memberId)
        val batch = db.batch()
        batch.delete(memberRef)
        batch.update(
            listRef,
            hashMapOf<String, Any>(
                "memberIds" to FieldValue.arrayRemove(memberId),
                "updatedAt" to FieldValue.serverTimestamp()
            )
        )
        batch.commit()
    }

    fun revokeInvite(listId: String, inviteId: String) {
        val inviteRef = db.collection("lists").document(listId).collection("invites").document(inviteId)
        val updates = hashMapOf(
            "status" to "revoked",
            "updatedAt" to FieldValue.serverTimestamp()
        )
        inviteRef.update(updates)
        inviteRef.get().addOnSuccessListener { snapshot ->
            val token = snapshot.getString("token")
            if (!token.isNullOrBlank()) {
                db.collection("invitesInbox").document(token).update(updates)
            }
        }
        touchList(listId)
    }

    fun ensureUserProfile(user: FirebaseUser) {
        val email = user.email ?: ""
        val data = hashMapOf(
            "displayName" to (user.displayName ?: ""),
            "email" to email,
            "emailLower" to email.lowercase(),
            "photoURL" to (user.photoUrl?.toString() ?: ""),
            "lastSeenAt" to FieldValue.serverTimestamp()
        )

        if (user.metadata?.creationTimestamp == user.metadata?.lastSignInTimestamp) {
            data["createdAt"] = FieldValue.serverTimestamp()
        }

        db.collection("users").document(user.uid).set(data, com.google.firebase.firestore.SetOptions.merge())
    }

    fun updateLastList(userId: String, listId: String) {
        db.collection("users").document(userId).set(
            hashMapOf(
                "lastListId" to listId,
                "lastSeenAt" to FieldValue.serverTimestamp()
            ),
            com.google.firebase.firestore.SetOptions.merge()
        )
    }

    fun upsertCatalogItem(
        userId: String,
        itemId: String?,
        name: String,
        barcode: String?,
        price: Double?,
        description: String?,
        icon: String?
    ) {
        val catalogRef = db.collection("users").document(userId).collection("catalog")
        val docRef = if (itemId != null) catalogRef.document(itemId) else catalogRef.document()
        val trimmed = name.trim()
        if (trimmed.isEmpty()) return
        val data = hashMapOf<String, Any>(
            "name" to trimmed,
            "normalizedName" to normalizedName(trimmed),
            "updatedAt" to FieldValue.serverTimestamp()
        )
        if (itemId == null) {
            data["createdAt"] = FieldValue.serverTimestamp()
        }
        if (!barcode.isNullOrBlank()) {
            data["barcode"] = barcode
        }
        if (price != null) {
            data["price"] = price
        }
        if (!description.isNullOrBlank()) {
            data["description"] = description
        }
        if (!icon.isNullOrBlank()) {
            data["icon"] = icon
        }
        docRef.set(data, com.google.firebase.firestore.SetOptions.merge())
    }

    private fun touchList(listId: String) {
        db.collection("lists").document(listId).update(
            hashMapOf<String, Any>("updatedAt" to FieldValue.serverTimestamp())
        )
    }

    private fun itemKey(data: Map<String, Any>?): String? {
        if (data == null) return null
        val barcode = data["barcode"] as? String
        if (!barcode.isNullOrBlank()) {
            return "barcode:$barcode"
        }
        val normalized = data["normalizedName"] as? String ?: normalizedName(data["name"] as? String ?: "")
        return if (normalized.isBlank()) null else "name:$normalized"
    }

    private fun deleteList(listId: String, onComplete: (Exception?) -> Unit) {
        val listRef = db.collection("lists").document(listId)
        deleteCollection(listRef.collection("items")) { itemsError ->
            if (itemsError != null) {
                onComplete(itemsError)
                return@deleteCollection
            }
            deleteCollection(listRef.collection("invites")) { invitesError ->
                if (invitesError != null) {
                    onComplete(invitesError)
                    return@deleteCollection
                }
                listRef.delete()
                    .addOnSuccessListener {
                        deleteCollection(listRef.collection("members")) { membersError ->
                            onComplete(membersError)
                        }
                    }
                    .addOnFailureListener { error -> onComplete(error) }
            }
        }
    }

    private fun deleteCollection(
        collection: com.google.firebase.firestore.CollectionReference,
        onComplete: (Exception?) -> Unit
    ) {
        collection.get()
            .addOnSuccessListener { snapshot ->
                if (snapshot.isEmpty) {
                    onComplete(null)
                    return@addOnSuccessListener
                }
                val batch = db.batch()
                snapshot.documents.forEach { batch.delete(it.reference) }
                batch.commit()
                    .addOnSuccessListener { onComplete(null) }
                    .addOnFailureListener { error -> onComplete(error) }
            }
            .addOnFailureListener { error -> onComplete(error) }
    }

    private fun normalizedName(name: String): String {
        return name.lowercase().trim()
    }
}
