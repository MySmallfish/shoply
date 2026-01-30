import SwiftUI

struct AdjustQuantityView: View {
    private let item: ShoppingItem
    private let onApply: (Int) -> Void

    @State private var amount: Int
    @State private var mode: QuantityMode

    @Environment(\.dismiss) private var dismiss

    init(item: ShoppingItem, onApply: @escaping (Int) -> Void) {
        self.item = item
        let defaultMode: QuantityMode = item.quantity <= 0 ? .need : .bought
        self._mode = State(initialValue: defaultMode)
        let startingAmount = defaultMode == .bought ? max(1, item.quantity) : 1
        self._amount = State(initialValue: startingAmount)
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 18, weight: .semibold))
                    Text("Left to buy: \(item.quantity)")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Picker("Mode", selection: $mode) {
                    ForEach(QuantityMode.allCases) { selection in
                        Text(selection.title).tag(selection)
                    }
                }
                .pickerStyle(.segmented)

                Text("How much?")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 24) {
                    Button {
                        if amount > 1 {
                            amount -= 1
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 20, weight: .bold))
                            .frame(width: 56, height: 56)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Circle())
                    }

                    Text("\(max(1, amount))")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .frame(minWidth: 80)

                    Button {
                        amount += 1
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .bold))
                            .frame(width: 56, height: 56)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                }
                .frame(maxWidth: .infinity)

                Spacer()
            }
            .padding(20)
            .navigationTitle("Update Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        let resolved = max(1, amount)
                        let delta = mode == .bought ? -resolved : resolved
                        onApply(delta)
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
