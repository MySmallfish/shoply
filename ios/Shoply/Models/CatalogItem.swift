import FirebaseFirestore
import Foundation

struct CatalogItem: Identifiable {
    let id: String
    let name: String
    let normalizedName: String
    let barcode: String?
    let price: Double?
    let itemDescription: String?
    let icon: String?
    let createdAt: Date
    let updatedAt: Date

    init(id: String, data: [String: Any]) {
        self.id = id
        self.name = data["name"] as? String ?? ""
        self.normalizedName = data["normalizedName"] as? String ?? ""
        self.barcode = data["barcode"] as? String
        if let number = data["price"] as? NSNumber {
            self.price = number.doubleValue
        } else {
            self.price = nil
        }
        self.itemDescription = data["description"] as? String
        self.icon = data["icon"] as? String
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
    }
}
