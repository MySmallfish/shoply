import Foundation
import FirebaseFirestore

struct ShoppingItem: Identifiable {
    let id: String
    let name: String
    let normalizedName: String
    let barcode: String?
    let isBought: Bool
    let createdAt: Date
    let createdBy: String
    let updatedAt: Date
    let boughtAt: Date?
    let boughtBy: String?

    init(id: String, data: [String: Any]) {
        self.id = id
        self.name = data["name"] as? String ?? ""
        self.normalizedName = data["normalizedName"] as? String ?? ""
        self.barcode = data["barcode"] as? String
        self.isBought = data["isBought"] as? Bool ?? false
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.createdBy = data["createdBy"] as? String ?? ""
        self.updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        self.boughtAt = (data["boughtAt"] as? Timestamp)?.dateValue()
        self.boughtBy = data["boughtBy"] as? String
    }
}
