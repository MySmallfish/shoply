import Foundation

struct ItemDetailsDraft: Equatable {
    var name: String = ""
    var barcode: String = ""
    var priceText: String = ""
    var descriptionText: String = ""
    var icon: String = ""

    var priceValue: Double? {
        let trimmed = priceText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
}
