import Foundation
import FirebaseFirestore

struct ListMember: Identifiable {
    let id: String
    let role: String
    let addedAt: Date
    let addedBy: String

    init(id: String, data: [String: Any]) {
        self.id = id
        self.role = data["role"] as? String ?? "viewer"
        self.addedAt = (data["addedAt"] as? Timestamp)?.dateValue() ?? Date()
        self.addedBy = data["addedBy"] as? String ?? ""
    }
}

struct ListInvite: Identifiable {
    let id: String
    let email: String
    let role: String
    let status: String
    let createdAt: Date

    init(id: String, data: [String: Any]) {
        self.id = id
        self.email = data["email"] as? String ?? ""
        self.role = data["role"] as? String ?? "editor"
        self.status = data["status"] as? String ?? "pending"
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }
}
