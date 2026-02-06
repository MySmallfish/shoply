import SwiftUI

struct ItemRow: View {
    let item: ShoppingItem
    let onTap: () -> Void
    let onIconTap: ((String) -> Void)?
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    init(
        item: ShoppingItem,
        onTap: @escaping () -> Void,
        onIconTap: ((String) -> Void)? = nil,
        onIncrement: @escaping () -> Void,
        onDecrement: @escaping () -> Void
    ) {
        self.item = item
        self.onTap = onTap
        self.onIconTap = onIconTap
        self.onIncrement = onIncrement
        self.onDecrement = onDecrement
    }

    var body: some View {
        HStack(spacing: 12) {
            if let icon = item.icon, !icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let onIconTap {
                    Button {
                        onIconTap(icon)
                    } label: {
                        ItemIconView(icon: icon, size: 20)
                    }
                    .buttonStyle(.plain)
                } else {
                    ItemIconView(icon: icon, size: 20)
                }
            }

            Button(action: onTap) {
                Text(item.name)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                Button(action: onDecrement) {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 26, height: 26)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.borderless)
                Text("\(item.quantity)")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(minWidth: 18)
                Button(action: onIncrement) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 26, height: 26)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }
}
