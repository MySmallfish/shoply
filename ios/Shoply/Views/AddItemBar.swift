import SwiftUI

struct AddItemBar: View {
    @Binding var text: String
    let onAdd: () -> Void
    let onDetails: () -> Void
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        let isRTL = layoutDirection == .rightToLeft
        HStack(spacing: 12) {
            if isRTL {
                addButton
                detailsButton
                inputField
            } else {
                inputField
                detailsButton
                addButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .top)
    }

    private var inputField: some View {
        return TextField("Add item", text: $text)
            .textFieldStyle(.plain)
            .submitLabel(.done)
            .multilineTextAlignment(.leading)
            .onSubmit {
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }
                onAdd()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
    }

    private var detailsButton: some View {
        Button(action: onDetails) {
            Image(systemName: "tag")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(Color(.secondarySystemBackground))
                .foregroundColor(.primary)
                .clipShape(Circle())
        }
        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
    }

    private var addButton: some View {
        Button(action: onAdd) {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .bold))
                .frame(width: 44, height: 44)
                .background(Color.black)
                .foregroundColor(.white)
                .clipShape(Circle())
        }
        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
    }
}
