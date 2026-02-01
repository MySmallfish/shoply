import SwiftUI

struct AddItemDetailsView: View {
    @State private var draft: ItemDetailsDraft
    private let allowBarcodeEdit: Bool
    let onSave: (ItemDetailsDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutDirection) private var layoutDirection

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
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Add Item")
                        .font(.headline)
                        .frame(
                            maxWidth: .infinity,
                            alignment: layoutDirection == .rightToLeft ? .trailing : .leading
                        )
                }
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
