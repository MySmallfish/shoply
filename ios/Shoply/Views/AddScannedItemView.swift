import SwiftUI

struct AddScannedItemView: View {
    let barcode: String
    @State private var draft: ItemDetailsDraft
    let onAdd: (ItemDetailsDraft) -> Void

    @Environment(\.dismiss) private var dismiss

    init(barcode: String, draft: ItemDetailsDraft, onAdd: @escaping (ItemDetailsDraft) -> Void) {
        self.barcode = barcode
        var seeded = draft
        seeded.barcode = barcode
        self._draft = State(initialValue: seeded)
        self.onAdd = onAdd
    }

    var body: some View {
        NavigationStack {
            Form {
                ItemDetailsForm(draft: $draft, allowBarcodeEdit: false)
            }
            .navigationTitle("Add Item")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        onAdd(draft)
                        dismiss()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
