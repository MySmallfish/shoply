import SwiftUI

struct CreateListView: View {
    @EnvironmentObject private var session: SessionViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutDirection) private var layoutDirection

    @State private var title = ""

    var body: some View {
        let isRTL = layoutDirection == .rightToLeft
        NavigationStack {
            Form {
                Section("List name") {
                    TextField("e.g. Grocery", text: $title)
                        .multilineTextAlignment(isRTL ? .trailing : .leading)
                        .environment(\.layoutDirection, .leftToRight)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        if layoutDirection == .rightToLeft {
                            Spacer()
                        }
                        Text("New List")
                            .font(.headline)
                        if layoutDirection == .leftToRight {
                            Spacer()
                        }
                    }
                }
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
