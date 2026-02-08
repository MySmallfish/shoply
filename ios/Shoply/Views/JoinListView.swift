import SwiftUI

struct JoinListView: View {
    @EnvironmentObject private var session: SessionViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutDirection) private var layoutDirection

    @State private var input = ""

    var body: some View {
        let isRTL = layoutDirection == .rightToLeft
        NavigationStack {
            Form {
                Section("Invite link or token") {
                    TextField("Paste invite link", text: $input)
                        .textInputAutocapitalization(.never)
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
                        Text("Join List")
                            .font(.headline)
                        if layoutDirection == .leftToRight {
                            Spacer()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Join") {
                        if let token = extractToken(from: input) {
                            session.handleInviteToken(token)
                            dismiss()
                        }
                    }
                    .disabled(extractToken(from: input) == nil)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func extractToken(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        if let url = URL(string: trimmed),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
           !token.isEmpty {
            return token
        }

        if let url = URL(string: trimmed) {
            let pathParts = url.pathComponents.filter { $0 != "/" }
            if let inviteIndex = pathParts.firstIndex(of: "invite"),
               pathParts.count > inviteIndex + 1 {
                return pathParts[inviteIndex + 1]
            }
        }

        return trimmed
    }
}
