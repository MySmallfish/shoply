import SwiftUI

struct AddItemBar: View {
    @Binding var text: String
    let onAdd: () -> Void
    let onDetails: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("Add item", text: $text)
                .textFieldStyle(.plain)
                .submitLabel(.done)
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
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .top)
    }
}
