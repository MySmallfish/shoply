import SwiftUI

struct CreateListView: View {
    @EnvironmentObject private var session: SessionViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("List name") {
                    TextField("e.g. Grocery", text: $title)
                }
            }
            .navigationTitle("New List")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        session.createList(title: title)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
