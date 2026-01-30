import SwiftUI

struct AddItemDetailsView: View {
    @State private var draft: ItemDetailsDraft
    private let allowBarcodeEdit: Bool
    let onSave: (ItemDetailsDraft) -> Void

    @Environment(\.dismiss) private var dismiss

    init(draft: ItemDetailsDraft, allowBarcodeEdit: Bool, onSave: @escaping (ItemDetailsDraft) -> Void) {
        self._draft = State(initialValue: draft)
        self.allowBarcodeEdit = allowBarcodeEdit
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                ItemDetailsForm(draft: $draft, allowBarcodeEdit: allowBarcodeEdit)
            }
            .navigationTitle("Item Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
