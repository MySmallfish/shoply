import SwiftUI

struct AddScannedItemView: View {
    let barcode: String
    @State private var draft: ItemDetailsDraft
    let onAdd: (ItemDetailsDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutDirection) private var layoutDirection

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
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    let title = NSLocalizedString("Add Item", comment: "")
                    HStack {
                        if layoutDirection == .rightToLeft {
                            Spacer()
                        }
                        Text(title)
                            .font(.headline)
                        if layoutDirection == .leftToRight {
                            Spacer()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("Add", comment: "")) {
                        onAdd(draft)
                        dismiss()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(NSLocalizedString("Cancel", comment: "")) {
                        dismiss()
                    }
                }
            }
        }
    }
}
