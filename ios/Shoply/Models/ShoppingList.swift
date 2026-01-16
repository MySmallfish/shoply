import Foundation
import FirebaseFirestore

struct ShoppingList: Identifiable {
    let id: String
    let title: String
    let createdAt: Date
    let updatedAt: Date
    let memberIds: [String]

    init(id: String, data: [String: Any]) {
        self.id = id
        self.title = data["title"] as? String ?? "Untitled"
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        self.memberIds = data["memberIds"] as? [String] ?? []
    }
}
