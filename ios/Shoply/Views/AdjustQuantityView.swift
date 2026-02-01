import SwiftUI

struct AdjustQuantityView: View {
    private let item: ShoppingItem
    private let onApply: (Int) -> Void
    private let onEditDetails: () -> Void

    @State private var amount: Int
    @State private var mode: QuantityMode

    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutDirection) private var layoutDirection

    init(item: ShoppingItem, onApply: @escaping (Int) -> Void, onEditDetails: @escaping () -> Void) {
        self.item = item
        let defaultMode: QuantityMode = item.quantity <= 0 ? .need : .bought
        self._mode = State(initialValue: defaultMode)
        let startingAmount = defaultMode == .bought ? max(1, item.quantity) : 1
        self._amount = State(initialValue: startingAmount)
        self.onApply = onApply
        self.onEditDetails = onEditDetails
    }

    var body: some View {
        let alignment: HorizontalAlignment = layoutDirection == .rightToLeft ? .trailing : .leading
        let title = NSLocalizedString("Update Item", comment: "")
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: alignment, spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 18, weight: .semibold))
                    Text(String(format: NSLocalizedString("left_to_buy_format", comment: ""), item.quantity))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: layoutDirection == .rightToLeft ? .trailing : .leading)

                Picker(NSLocalizedString("Mode", comment: ""), selection: $mode) {
                    ForEach(QuantityMode.allCases) { selection in
                        Text(selection.title).tag(selection)
                    }
                }
                .pickerStyle(.segmented)

                Button(NSLocalizedString("Edit Item", comment: "")) {
                    onEditDetails()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, alignment: layoutDirection == .rightToLeft ? .trailing : .leading)

                Text(NSLocalizedString("How much?", comment: ""))
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: layoutDirection == .rightToLeft ? .trailing : .leading)

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
                    Button(NSLocalizedString("Apply", comment: "")) {
                        let resolved = max(1, amount)
                        let delta = mode == .bought ? -resolved : resolved
                        onApply(delta)
                        dismiss()
                    }
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

private enum QuantityMode: String, CaseIterable, Identifiable {
    case bought
    case need

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bought:
            return NSLocalizedString("Bought", comment: "")
        case .need:
            return NSLocalizedString("Need", comment: "")
        }
    }
}
