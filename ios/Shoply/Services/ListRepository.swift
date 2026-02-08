import FirebaseAuth
import FirebaseFirestore
import Foundation

final class ListRepository {
    private let db = Firestore.firestore()

    func listenToLists(userId: String, onChange: @escaping ([ShoppingList]) -> Void) -> ListenerRegistration {
        return db.collection("lists")
            .whereField("memberIds", arrayContains: userId)
            .addSnapshotListener { snapshot, _ in
                let lists = snapshot?.documents.map {
                    ShoppingList(id: $0.documentID, data: $0.data())
                } ?? []
                let ordered = lists.sorted { $0.updatedAt > $1.updatedAt }
                onChange(ordered)
            }
    }

    func listenToItems(listId: String, onChange: @escaping ([ShoppingItem]) -> Void) -> ListenerRegistration {
        return db.collection("lists").document(listId).collection("items")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, _ in
                let items = snapshot?.documents.map {
                    ShoppingItem(id: $0.documentID, data: $0.data())
                } ?? []
                let ordered = items.sorted {
                    if $0.quantity != $1.quantity {
                        return $0.quantity > $1.quantity
                    }
                    return $0.updatedAt > $1.updatedAt
                }
                onChange(ordered)
            }
    }

    func listenToMembers(listId: String, onChange: @escaping ([ListMember]) -> Void) -> ListenerRegistration {
        return db.collection("lists").document(listId).collection("members")
            .addSnapshotListener { snapshot, _ in
                let members = snapshot?.documents.map {
                    ListMember(id: $0.documentID, data: $0.data())
                } ?? []
                onChange(members)
            }
    }

    func listenToInvites(listId: String, onChange: @escaping ([ListInvite]) -> Void) -> ListenerRegistration {
        return db.collection("lists").document(listId).collection("invites")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, _ in
                let invites = snapshot?.documents.map {
                    ListInvite(id: $0.documentID, data: $0.data())
                } ?? []
                onChange(invites)
            }
    }

    func listenToPendingInvites(
        emailLower: String?,
        onChange: @escaping ([PendingInvite]) -> Void
    ) -> ListenerRegistration {
        let trimmedLower = emailLower?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        var query: Query = db.collection("invitesInbox")
        if !trimmedLower.isEmpty {
            query = query.whereField("emailLower", isEqualTo: trimmedLower)
        }
        return query.addSnapshotListener { [weak self] snapshot, _ in
            let invites = snapshot?.documents.compactMap { self?.pendingInvite(from: $0) } ?? []
            onChange(invites.filter { $0.status == "pending" })
        }
    }

    func listenToCatalogItems(userId: String, onChange: @escaping ([CatalogItem]) -> Void) -> ListenerRegistration {
        return db.collection("users").document(userId).collection("catalog")
            .order(by: "updatedAt", descending: true)
            .addSnapshotListener { snapshot, _ in
                let items = snapshot?.documents.map {
                    CatalogItem(id: $0.documentID, data: $0.data())
                } ?? []
                onChange(items)
            }
    }

    func createList(title: String, ownerId: String, completion: @escaping (Result<String, Error>) -> Void) {
        let listRef = db.collection("lists").document()
        let now = FieldValue.serverTimestamp()

        let listData: [String: Any] = [
            "title": title,
            "createdAt": now,
            "updatedAt": now,
            "createdBy": ownerId,
            "memberIds": [ownerId]
        ]

        let memberData: [String: Any] = [
            "role": "owner",
            "addedAt": now,
            "addedBy": ownerId
        ]

        listRef.setData(listData) { error in
            if let error = error {
                completion(.failure(error))
                return
            }
            let memberRef = listRef.collection("members").document(ownerId)
            memberRef.setData(memberData) { memberError in
                if let memberError = memberError {
                    completion(.failure(memberError))
                } else {
                    completion(.success(listRef.documentID))
                }
            }
        }
    }

    func updateListTitle(listId: String, title: String, completion: ((Error?) -> Void)? = nil) {
        db.collection("lists").document(listId).updateData([
            "title": title,
            "updatedAt": FieldValue.serverTimestamp()
        ]) { error in
            completion?(error)
        }
    }

    func mergeLists(
        sourceListId: String,
        targetListId: String,
        actingUserId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let sourceRef = db.collection("lists").document(sourceListId).collection("items")
        let targetRef = db.collection("lists").document(targetListId).collection("items")

        targetRef.getDocuments { [weak self] targetSnapshot, targetError in
            if let targetError {
                completion(.failure(targetError))
                return
            }
            let existingKeys = Set((targetSnapshot?.documents ?? []).compactMap { doc in
                self?.itemKey(from: doc.data())
            })

            sourceRef.getDocuments { [weak self] sourceSnapshot, sourceError in
                guard let self else { return }
                if let sourceError {
                    completion(.failure(sourceError))
                    return
                }
                let batch = self.db.batch()
                var added = 0
                for doc in sourceSnapshot?.documents ?? [] {
                    let data = doc.data()
                    let key = self.itemKey(from: data)
                    if key.isEmpty || existingKeys.contains(key) {
                        continue
                    }
                    var payload = data
                    payload["createdAt"] = FieldValue.serverTimestamp()
                    payload["updatedAt"] = FieldValue.serverTimestamp()
                    let newDoc = targetRef.document()
                    batch.setData(payload, forDocument: newDoc)
                    added += 1
                }

                if added == 0 {
                    self.deleteList(listId: sourceListId, ownerId: actingUserId, completion: completion)
                    return
                }

                batch.commit { error in
                    if let error {
                        completion(.failure(error))
                        return
                    }
                    self.deleteList(listId: sourceListId, ownerId: actingUserId, completion: completion)
                }
            }
        }
    }

    func deleteList(
        listId: String,
        ownerId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let listRef = db.collection("lists").document(listId)

        deleteCollection(listRef.collection("items")) { [weak self] itemsError in
            guard let self else { return }
            if let itemsError {
                completion(.failure(itemsError))
                return
            }
            self.deleteCollection(listRef.collection("invites")) { invitesError in
                if let invitesError {
                    completion(.failure(invitesError))
                    return
                }
                self.deleteMembersExceptOwner(listRef: listRef, ownerId: ownerId) { membersError in
                    if let membersError {
                        completion(.failure(membersError))
                        return
                    }
                    self.deleteInvitesInbox(listId: listId) { inboxError in
                        if let inboxError {
                            completion(.failure(inboxError))
                            return
                        }
                        listRef.delete { listError in
                            if let listError {
                                completion(.failure(listError))
                                return
                            }
                            // Best-effort cleanup. Once the list doc is gone this is mostly unreachable,
                            // but we remove the owner member doc to avoid leaving an orphaned document.
                            listRef.collection("members").document(ownerId).delete { _ in
                                completion(.success(()))
                            }
                        }
                    }
                }
            }
        }
    }

    func addItem(
        listId: String,
        name: String,
        barcode: String?,
        price: Double?,
        description: String?,
        icon: String?,
        userId: String
    ) {
        let itemRef = db.collection("lists").document(listId).collection("items").document()
        let now = FieldValue.serverTimestamp()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        var data: [String: Any] = [
            "name": trimmed,
            "normalizedName": normalizedName(trimmed),
            "quantity": 1,
            "isBought": false,
            "createdAt": now,
            "createdBy": userId,
            "updatedAt": now
        ]

        if let barcode = barcode {
            data["barcode"] = barcode
        }
        if let price = price {
            data["price"] = price
        }
        if let description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            data["description"] = description
        }
        if let icon, !icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            data["icon"] = icon
        }

        itemRef.setData(data)
        touchList(listId: listId)
    }

    func adjustQuantity(
        listId: String,
        itemId: String,
        delta: Int,
        markUnbought: Bool,
        barcode: String?,
        price: Double?,
        description: String?,
        icon: String?
    ) {
        let itemRef = db.collection("lists").document(listId).collection("items").document(itemId)
        db.runTransaction({ transaction, errorPointer in
            do {
                let snapshot = try transaction.getDocument(itemRef)
                let current: Int
                if let value = snapshot.data()?["quantity"] as? NSNumber {
                    current = value.intValue
                } else if let value = snapshot.data()?["quantity"] as? Int {
                    current = value
                } else {
                    current = 1
                }
                let next = current + delta
                var updates: [String: Any] = [
                    "quantity": next,
                    "updatedAt": FieldValue.serverTimestamp()
                ]

                if markUnbought {
                    updates["isBought"] = false
                    updates["boughtAt"] = FieldValue.delete()
                    updates["boughtBy"] = FieldValue.delete()
                }

                if let barcode, !barcode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    updates["barcode"] = barcode
                }
                if let price = price {
                    updates["price"] = price
                }
                if let description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    updates["description"] = description
                }
                if let icon, !icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    updates["icon"] = icon
                }

                transaction.updateData(updates, forDocument: itemRef)
            } catch let error {
                errorPointer?.pointee = error as NSError
                return nil
            }
            return nil
        }, completion: { _, _ in })
        touchList(listId: listId)
    }

    func updateQuantity(
        listId: String,
        itemId: String,
        quantity: Int,
        markUnbought: Bool
    ) {
        let itemRef = db.collection("lists").document(listId).collection("items").document(itemId)
        var updates: [String: Any] = [
            "quantity": quantity,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if markUnbought {
            updates["isBought"] = false
            updates["boughtAt"] = FieldValue.delete()
            updates["boughtBy"] = FieldValue.delete()
        }

        itemRef.updateData(updates)
        touchList(listId: listId)
    }

    func updateItemDetails(
        listId: String,
        itemId: String,
        name: String,
        barcode: String,
        price: Double?,
        description: String?,
        icon: String?
    ) {
        let itemRef = db.collection("lists").document(listId).collection("items").document(itemId)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        var updates: [String: Any] = [
            "name": trimmedName,
            "normalizedName": normalizedName(trimmedName),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        let trimmedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedBarcode.isEmpty {
            updates["barcode"] = FieldValue.delete()
        } else {
            updates["barcode"] = trimmedBarcode
        }

        if let price = price {
            updates["price"] = price
        } else {
            updates["price"] = FieldValue.delete()
        }

        if let description {
            let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
            updates["description"] = trimmedDescription.isEmpty ? FieldValue.delete() : trimmedDescription
        } else {
            updates["description"] = FieldValue.delete()
        }

        if let icon {
            let trimmedIcon = icon.trimmingCharacters(in: .whitespacesAndNewlines)
            updates["icon"] = trimmedIcon.isEmpty ? FieldValue.delete() : trimmedIcon
        } else {
            updates["icon"] = FieldValue.delete()
        }

        itemRef.updateData(updates)
        touchList(listId: listId)
    }

    func toggleBought(listId: String, item: ShoppingItem, userId: String) {
        let itemRef = db.collection("lists").document(listId).collection("items").document(item.id)
        var updates: [String: Any] = [
            "isBought": !item.isBought,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if item.isBought {
            updates["boughtAt"] = FieldValue.delete()
            updates["boughtBy"] = FieldValue.delete()
        } else {
            updates["boughtAt"] = FieldValue.serverTimestamp()
            updates["boughtBy"] = userId
        }

        itemRef.updateData(updates)
        touchList(listId: listId)
    }

    func deleteItem(listId: String, itemId: String) {
        let itemRef = db.collection("lists").document(listId).collection("items").document(itemId)
        itemRef.delete()
        touchList(listId: listId)
    }

    func restoreItem(listId: String, item: ShoppingItem, userId: String) {
        let itemRef = db.collection("lists").document(listId).collection("items").document(item.id)
        var data: [String: Any] = [
            "name": item.name,
            "normalizedName": normalizedName(item.name),
            "quantity": item.quantity,
            "isBought": item.isBought,
            "createdAt": Timestamp(date: item.createdAt),
            "createdBy": item.createdBy.isEmpty ? userId : item.createdBy,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let barcode = item.barcode, !barcode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            data["barcode"] = barcode
        }
        if let price = item.price {
            data["price"] = price
        }
        if let description = item.itemDescription, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            data["description"] = description
        }
        if let icon = item.icon, !icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            data["icon"] = icon
        }
        if item.isBought {
            if let boughtAt = item.boughtAt {
                data["boughtAt"] = Timestamp(date: boughtAt)
            } else {
                data["boughtAt"] = FieldValue.serverTimestamp()
            }
            data["boughtBy"] = item.boughtBy ?? userId
        }

        itemRef.setData(data)
        touchList(listId: listId)
    }

    func setBought(listId: String, itemId: String, isBought: Bool, userId: String) {
        let itemRef = db.collection("lists").document(listId).collection("items").document(itemId)
        var updates: [String: Any] = [
            "isBought": isBought,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if isBought {
            updates["boughtAt"] = FieldValue.serverTimestamp()
            updates["boughtBy"] = userId
        } else {
            updates["boughtAt"] = FieldValue.delete()
            updates["boughtBy"] = FieldValue.delete()
        }

        itemRef.updateData(updates)
        touchList(listId: listId)
    }

    func updateMemberRole(listId: String, memberId: String, role: String) {
        let memberRef = db.collection("lists").document(listId).collection("members").document(memberId)
        memberRef.updateData([
            "role": role,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        touchList(listId: listId)
    }

    func removeMember(listId: String, memberId: String) {
        let listRef = db.collection("lists").document(listId)
        let memberRef = listRef.collection("members").document(memberId)
        let batch = db.batch()
        batch.deleteDocument(memberRef)
        batch.updateData([
            "memberIds": FieldValue.arrayRemove([memberId]),
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: listRef)
        batch.commit { _ in }
    }

    func revokeInvite(listId: String, inviteId: String) {
        let inviteRef = db.collection("lists").document(listId).collection("invites").document(inviteId)
        let updates: [String: Any] = [
            "status": "revoked",
            "updatedAt": FieldValue.serverTimestamp()
        ]
        inviteRef.updateData(updates)
        inviteRef.getDocument { [weak self] snapshot, _ in
            guard let token = snapshot?.data()?["token"] as? String, !token.isEmpty else { return }
            self?.db.collection("invitesInbox").document(token).updateData(updates)
        }
        touchList(listId: listId)
    }

    func ensureUserProfile(user: User) {
        let email = user.email ?? ""
        let emailLower = email.lowercased()
        var data: [String: Any] = [
            "displayName": user.displayName ?? "",
            "email": email,
            "emailLower": emailLower,
            "photoURL": user.photoURL?.absoluteString ?? "",
            "lastSeenAt": FieldValue.serverTimestamp()
        ]

        if user.metadata.creationDate == user.metadata.lastSignInDate {
            data["createdAt"] = FieldValue.serverTimestamp()
        }

        db.collection("users").document(user.uid).setData(data, merge: true)
    }

    func updateLastList(userId: String, listId: String) {
        db.collection("users").document(userId).setData([
            "lastListId": listId,
            "lastSeenAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func upsertCatalogItem(
        userId: String,
        itemId: String?,
        name: String,
        barcode: String?,
        price: Double?,
        description: String?,
        icon: String?
    ) {
        let catalogRef = db.collection("users").document(userId).collection("catalog")
        let docRef = itemId != nil ? catalogRef.document(itemId!) : catalogRef.document()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var data: [String: Any] = [
            "name": trimmed,
            "normalizedName": normalizedName(trimmed),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if itemId == nil {
            data["createdAt"] = FieldValue.serverTimestamp()
        }

        if let barcode, !barcode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            data["barcode"] = barcode
        }
        if let price = price {
            data["price"] = price
        }
        if let description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            data["description"] = description
        }
        if let icon, !icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            data["icon"] = icon
        }

        docRef.setData(data, merge: true)
    }

    private func touchList(listId: String) {
        db.collection("lists").document(listId).updateData([
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    private func normalizedName(_ name: String) -> String {
        return name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func itemKey(from data: [String: Any]) -> String {
        let barcode = data["barcode"] as? String ?? ""
        if !barcode.isEmpty {
            return "barcode:\(barcode)"
        }
        let normalized = data["normalizedName"] as? String ?? normalizedName(data["name"] as? String ?? "")
        return normalized.isEmpty ? "" : "name:\(normalized)"
    }

    private func deleteMembersExceptOwner(
        listRef: DocumentReference,
        ownerId: String,
        completion: @escaping (Error?) -> Void
    ) {
        listRef.collection("members").getDocuments { [weak self] snapshot, error in
            guard let self else { return }
            if let error {
                completion(error)
                return
            }
            let docs = (snapshot?.documents ?? []).filter { $0.documentID != ownerId }
            guard !docs.isEmpty else {
                completion(nil)
                return
            }
            let batch = self.db.batch()
            docs.forEach { batch.deleteDocument($0.reference) }
            batch.commit { commitError in
                completion(commitError)
            }
        }
    }

    private func deleteInvitesInbox(listId: String, completion: @escaping (Error?) -> Void) {
        db.collection("invitesInbox")
            .whereField("listId", isEqualTo: listId)
            .getDocuments { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    completion(error)
                    return
                }
                let docs = snapshot?.documents ?? []
                guard !docs.isEmpty else {
                    completion(nil)
                    return
                }
                let batch = self.db.batch()
                docs.forEach { batch.deleteDocument($0.reference) }
                batch.commit { commitError in
                    completion(commitError)
                }
            }
    }

    private func deleteCollection(_ collection: CollectionReference, completion: @escaping (Error?) -> Void) {
        collection.getDocuments { [weak self] snapshot, error in
            guard let self else { return }
            if let error {
                completion(error)
                return
            }
            guard let documents = snapshot?.documents, !documents.isEmpty else {
                completion(nil)
                return
            }
            let batch = self.db.batch()
            documents.forEach { batch.deleteDocument($0.reference) }
            batch.commit { commitError in
                completion(commitError)
            }
        }
    }

    private func pendingInvite(from doc: QueryDocumentSnapshot) -> PendingInvite? {
        let data = doc.data()
        let listId = data["listId"] as? String ?? doc.reference.parent.parent?.documentID ?? ""
        let token = data["token"] as? String ?? ""
        if listId.isEmpty || token.isEmpty {
            return nil
        }
        return PendingInvite(
            id: doc.documentID,
            listId: listId,
            listTitle: data["listTitle"] as? String ?? "Shoply list",
            email: data["email"] as? String ?? "",
            role: data["role"] as? String ?? "editor",
            status: data["status"] as? String ?? "pending",
            token: token,
            creatorName: data["creatorName"] as? String ?? "",
            creatorEmail: data["creatorEmail"] as? String ?? "",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue()
        )
    }
}
