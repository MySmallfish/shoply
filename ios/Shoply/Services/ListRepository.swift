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
                onChange(items)
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
                    self.deleteList(listId: sourceListId, completion: completion)
                    return
                }

                batch.commit { error in
                    if let error {
                        completion(.failure(error))
                        return
                    }
                    self.deleteList(listId: sourceListId, completion: completion)
                }
            }
        }
    }

    func addItem(listId: String, name: String, barcode: String?, userId: String) {
        let itemRef = db.collection("lists").document(listId).collection("items").document()
        let now = FieldValue.serverTimestamp()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        var data: [String: Any] = [
            "name": trimmed,
            "normalizedName": normalizedName(trimmed),
            "isBought": false,
            "createdAt": now,
            "createdBy": userId,
            "updatedAt": now
        ]

        if let barcode = barcode {
            data["barcode"] = barcode
        }

        itemRef.setData(data)
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

    private func deleteList(listId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let listRef = db.collection("lists").document(listId)
        let group = DispatchGroup()
        var firstError: Error?

        let collections = [
            listRef.collection("items"),
            listRef.collection("members"),
            listRef.collection("invites")
        ]

        for collection in collections {
            group.enter()
            deleteCollection(collection) { error in
                if firstError == nil {
                    firstError = error
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if let error = firstError {
                completion(.failure(error))
                return
            }
            listRef.delete { error in
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
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
