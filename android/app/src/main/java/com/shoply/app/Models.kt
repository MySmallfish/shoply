package com.shoply.app

import com.google.firebase.Timestamp
import com.google.firebase.firestore.DocumentSnapshot

data class ShoppingList(
    val id: String,
    val title: String,
    val createdAt: Long,
    val updatedAt: Long,
    val memberIds: List<String>
)

data class ShoppingItem(
    val id: String,
    val name: String,
    val normalizedName: String,
    val barcode: String?,
    val isBought: Boolean,
    val createdAt: Long,
    val createdBy: String,
    val updatedAt: Long,
    val boughtAt: Long?,
    val boughtBy: String?
)

data class ListMember(
    val id: String,
    val role: String,
    val addedAt: Long,
    val addedBy: String
)

data class ListInvite(
    val id: String,
    val email: String,
    val role: String,
    val status: String,
    val createdAt: Long
)

data class MemberViewData(
    val id: String,
    val name: String,
    val email: String,
    val role: String,
    val isCurrentUser: Boolean
)

data class InviteViewData(
    val id: String,
    val email: String,
    val role: String,
    val status: String
)

data class MergePrompt(
    val existingListId: String,
    val existingListTitle: String,
    val invitedListId: String,
    val invitedListTitle: String,
    val creatorName: String
)

data class PendingInvite(
    val id: String,
    val listId: String,
    val listTitle: String,
    val email: String,
    val role: String,
    val status: String,
    val token: String,
    val creatorName: String,
    val creatorEmail: String,
    val createdAt: Long
)

fun DocumentSnapshot.toShoppingList(): ShoppingList {
    val title = getString("title") ?: "Untitled"
    val createdAt = getTimestamp("createdAt")?.toDate()?.time ?: 0L
    val updatedAt = getTimestamp("updatedAt")?.toDate()?.time ?: createdAt
    val memberIds = get("memberIds") as? List<String> ?: emptyList()
    return ShoppingList(
        id = id,
        title = title,
        createdAt = createdAt,
        updatedAt = updatedAt,
        memberIds = memberIds
    )
}

fun DocumentSnapshot.toShoppingItem(): ShoppingItem {
    val name = getString("name") ?: ""
    val normalizedName = getString("normalizedName") ?: ""
    val barcode = getString("barcode")
    val isBought = getBoolean("isBought") ?: false
    val createdAt = getTimestamp("createdAt")?.toDate()?.time ?: 0L
    val updatedAt = getTimestamp("updatedAt")?.toDate()?.time ?: createdAt
    val createdBy = getString("createdBy") ?: ""
    val boughtAt = getTimestamp("boughtAt")?.toDate()?.time
    val boughtBy = getString("boughtBy")

    return ShoppingItem(
        id = id,
        name = name,
        normalizedName = normalizedName,
        barcode = barcode,
        isBought = isBought,
        createdAt = createdAt,
        createdBy = createdBy,
        updatedAt = updatedAt,
        boughtAt = boughtAt,
        boughtBy = boughtBy
    )
}

fun DocumentSnapshot.toListMember(): ListMember {
    val role = getString("role") ?: "viewer"
    val addedAt = getTimestamp("addedAt")?.toDate()?.time ?: 0L
    val addedBy = getString("addedBy") ?: ""
    return ListMember(
        id = id,
        role = role,
        addedAt = addedAt,
        addedBy = addedBy
    )
}

fun DocumentSnapshot.toListInvite(): ListInvite {
    val email = getString("email") ?: ""
    val role = getString("role") ?: "editor"
    val status = getString("status") ?: "pending"
    val createdAt = getTimestamp("createdAt")?.toDate()?.time ?: 0L
    return ListInvite(
        id = id,
        email = email,
        role = role,
        status = status,
        createdAt = createdAt
    )
}

fun DocumentSnapshot.toPendingInvite(): PendingInvite? {
    val listId = getString("listId") ?: reference.parent.parent?.id ?: return null
    val token = getString("token") ?: return null
    val email = getString("email") ?: ""
    val role = getString("role") ?: "editor"
    val status = getString("status") ?: "pending"
    val listTitle = getString("listTitle") ?: "Shoply list"
    val creatorName = getString("creatorName") ?: ""
    val creatorEmail = getString("creatorEmail") ?: ""
    val createdAt = getTimestamp("createdAt")?.toDate()?.time ?: 0L
    return PendingInvite(
        id = id,
        listId = listId,
        listTitle = listTitle,
        email = email,
        role = role,
        status = status,
        token = token,
        creatorName = creatorName,
        creatorEmail = creatorEmail,
        createdAt = createdAt
    )
}

fun Timestamp?.toMillis(): Long? = this?.toDate()?.time
