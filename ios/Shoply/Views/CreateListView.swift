import SwiftUI

struct CreateListView: View {
    @EnvironmentObject private var session: SessionViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutDirection) private var layoutDirection

    @State private var title = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("List name") {
                    TextField("e.g. Grocery", text: $title)
                        .multilineTextAlignment(layoutDirection == .rightToLeft ? .trailing : .leading)
                }
            }
            .navigationTitle("New List")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        session.createList(title: title)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
