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
            .navigationTitle("Add Item")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        onSave(draft)
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
