import SwiftUI

struct AdjustQuantityView: View {
    private let item: ShoppingItem
    private let onApply: (Int) -> Void

    @State private var amountText: String
    @State private var mode: QuantityMode
    private let defaultAmount: Int

    @Environment(\.dismiss) private var dismiss

    init(item: ShoppingItem, onApply: @escaping (Int) -> Void) {
        self.item = item
        let defaultMode: QuantityMode = item.quantity <= 0 ? .need : .bought
        self._mode = State(initialValue: defaultMode)
        let amount = defaultMode == .bought ? max(1, item.quantity) : 1
        self.defaultAmount = amount
        self._amountText = State(initialValue: "\(amount)")
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    Text(item.name)
                    Text("Left to buy: \(item.quantity)")
                        .foregroundColor(.secondary)
                }

                Section("How much did you buy?") {
                    Picker("Mode", selection: $mode) {
                        ForEach(QuantityMode.allCases) { selection in
                            Text(selection.title).tag(selection)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("Amount", text: $amountText)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Update Item")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        let trimmed = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
                        let amount = Int(trimmed) ?? defaultAmount
                        if amount > 0 {
                            let delta = mode == .bought ? -amount : amount
                            onApply(delta)
                        }
                        dismiss()
                    }
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

private enum QuantityMode: String, CaseIterable, Identifiable {
    case bought
    case need

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bought:
            return "Bought"
        case .need:
            return "Need"
        }
    }
}
