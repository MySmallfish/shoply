import SwiftUI

struct InviteView: View {
    @EnvironmentObject private var session: SessionViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutDirection) private var layoutDirection

    @State private var email = ""
    @State private var role = "editor"
    @State private var errorMessage: String?
    @State private var isSending = false
    @State private var shareURL: URL?
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Invite") {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .multilineTextAlignment(layoutDirection == .rightToLeft ? .trailing : .leading)

                    Picker("Role", selection: $role) {
                        Text("Editor").tag("editor")
                        Text("Viewer").tag("viewer")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Invite")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Send") {
                        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
                        isSending = true
                        session.sendInvite(email: trimmed, role: role) { result in
                            DispatchQueue.main.async {
                                isSending = false
                                switch result {
                                case .success(let token):
                                    let urlString = "https://shoply.simplevision.co.il/invite/\(token)"
                                    if let url = URL(string: urlString) {
                                        shareURL = url
                                        showShareSheet = true
                                    } else {
                                        dismiss()
                                    }
                                case let .failure(error):
                                    errorMessage = error.localizedDescription
                                }
                            }
                        }
                    }
                    .disabled(
                        isSending
                            || session.selectedListId == nil
                            || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet, onDismiss: {
            dismiss()
        }) {
            if let url = shareURL {
                ShareSheet(activityItems: [url])
            }
        }
        .alert(
            "Invite failed",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unable to send invite.")
        }
    }
}
