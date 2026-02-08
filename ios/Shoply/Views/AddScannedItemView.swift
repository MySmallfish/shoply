import SwiftUI

struct AddScannedItemView: View {
    let barcode: String
    @Binding var draft: ItemDetailsDraft
    let onAdd: (ItemDetailsDraft) -> Void

    @AppStorage("appLanguage") private var appLanguage = "he"
    @Environment(\.dismiss) private var dismiss
    @State private var showBarcodeScanner = false

    init(barcode: String, draft: Binding<ItemDetailsDraft>, onAdd: @escaping (ItemDetailsDraft) -> Void) {
        self.barcode = barcode
        self._draft = draft
        self.onAdd = onAdd
    }

    var body: some View {
        let isRTL = appLanguage.hasPrefix("he") || appLanguage.hasPrefix("ar")
        let title = L10n.string("Add Item", language: appLanguage)
        let addTitle = L10n.string("Add", language: appLanguage)
        let cancelTitle = L10n.string("Cancel", language: appLanguage)
        NavigationStack {
            Form {
                ItemDetailsForm(
                    draft: $draft,
                    allowBarcodeEdit: false,
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
                    Button(addTitle) {
                        onAdd(draft)
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
