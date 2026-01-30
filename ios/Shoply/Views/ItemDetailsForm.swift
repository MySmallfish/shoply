import SwiftUI

struct ItemDetailsForm: View {
    @Binding var draft: ItemDetailsDraft
    let allowBarcodeEdit: Bool

    var body: some View {
        Section("Item") {
            TextField("Name", text: $draft.name)
            TextField("Barcode", text: $draft.barcode)
                .keyboardType(.numberPad)
                .disabled(!allowBarcodeEdit)
                .foregroundColor(allowBarcodeEdit ? .primary : .secondary)
        }

        Section("Details") {
            TextField("Price", text: $draft.priceText)
                .keyboardType(.decimalPad)
            TextField("Icon", text: $draft.icon)
            TextField("Description", text: $draft.descriptionText, axis: .vertical)
        }
    }
}
