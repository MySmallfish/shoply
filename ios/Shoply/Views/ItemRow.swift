import SwiftUI

struct ItemRow: View {
    let item: ShoppingItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: item.isBought ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(item.isBought ? .green : .secondary)
            }

            Text(item.name)
                .strikethrough(item.isBought, color: .secondary)
                .foregroundColor(item.isBought ? .secondary : .primary)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
