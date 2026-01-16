import SwiftUI

struct AddScannedItemView: View {
    let barcode: String
    @State private var name: String
    let onAdd: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    init(barcode: String, name: String, onAdd: @escaping (String) -> Void) {
        self.barcode = barcode
        self._name = State(initialValue: name)
        self.onAdd = onAdd
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Scanned") {
                    Text(barcode)
                        .font(.system(size: 14, weight: .semibold))
                }
                Section("Item") {
                    TextField("Name", text: $name)
                }
            }
            .navigationTitle("Add Item")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(name)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
