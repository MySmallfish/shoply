import SwiftUI

struct AddItemDetailsView: View {
    @State private var draft: ItemDetailsDraft
    private let allowBarcodeEdit: Bool
    private let title: String
    private let primaryTitle: String
    let onSave: (ItemDetailsDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutDirection) private var layoutDirection

    init(
        draft: ItemDetailsDraft,
        allowBarcodeEdit: Bool,
        title: String = NSLocalizedString("Add Item", comment: ""),
        primaryTitle: String = NSLocalizedString("Add", comment: ""),
        onSave: @escaping (ItemDetailsDraft) -> Void
    ) {
        self._draft = State(initialValue: draft)
        self.allowBarcodeEdit = allowBarcodeEdit
        self.title = title
        self.primaryTitle = primaryTitle
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
                    Button(primaryTitle) {
                        onSave(draft)
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
