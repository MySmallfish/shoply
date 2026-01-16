import Foundation

struct PendingInvite: Identifiable {
    let id: String
    let listId: String
    let listTitle: String
    let email: String
    let role: String
    let status: String
    let token: String
    let createdAt: Date?
}
