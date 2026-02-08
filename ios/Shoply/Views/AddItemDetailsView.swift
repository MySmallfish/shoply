import SwiftUI

struct AddItemDetailsView: View {
    @Binding var draft: ItemDetailsDraft
    private let allowBarcodeEdit: Bool
    private let titleKey: String
    private let primaryTitleKey: String
    let onSave: (ItemDetailsDraft) -> Void

    @AppStorage("appLanguage") private var appLanguage = "he"
    @Environment(\.dismiss) private var dismiss
    @State private var showBarcodeScanner = false

    init(
        draft: Binding<ItemDetailsDraft>,
        allowBarcodeEdit: Bool,
        titleKey: String = "Add Item",
        primaryTitleKey: String = "Add",
        onSave: @escaping (ItemDetailsDraft) -> Void
    ) {
        self._draft = draft
        self.allowBarcodeEdit = allowBarcodeEdit
        self.titleKey = titleKey
        self.primaryTitleKey = primaryTitleKey
        self.onSave = onSave
    }

    var body: some View {
        let isRTL = appLanguage.hasPrefix("he") || appLanguage.hasPrefix("ar")
        let title = L10n.string(titleKey, language: appLanguage)
        let primaryTitle = L10n.string(primaryTitleKey, language: appLanguage)
        let cancelTitle = L10n.string("Cancel", language: appLanguage)
        NavigationStack {
            Form {
                ItemDetailsForm(
                    draft: $draft,
                    allowBarcodeEdit: allowBarcodeEdit,
                    onScanBarcode: { showBarcodeScanner = true }
                )
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        if isRTL { Spacer() }
                        Text(title)
                            .font(.headline)
                        if !isRTL { Spacer() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(primaryTitle) {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(cancelTitle) {
                        dismiss()
                    }
                }
            }
        }
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
        .sheet(isPresented: $showBarcodeScanner) {
            ScannerView { code in
                draft.barcode = code
                showBarcodeScanner = false
            }
        }
    }
}
