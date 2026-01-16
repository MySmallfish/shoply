import SwiftUI

struct PendingInvitesView: View {
    @EnvironmentObject private var session: SessionViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if session.pendingInvites.isEmpty {
                    Text("No pending invitations")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(session.pendingInvites) { invite in
                        PendingInviteRow(invite: invite) {
                            session.acceptPendingInvite(invite)
                        }
                    }
                }
            }
            .navigationTitle("Pending Invitations")
            .alert(
                "Invitation",
                isPresented: Binding(
                    get: { session.inviteActionError != nil },
                    set: { if !$0 { session.inviteActionError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(session.inviteActionError ?? "")
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct PendingInviteRow: View {
    let invite: PendingInvite
    let onAccept: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(invite.listTitle.isEmpty ? invite.listId : invite.listTitle)
                    .fontWeight(.semibold)
                Text(roleLabel(invite.role))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Accept") {
                onAccept()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 4)
    }

    private func roleLabel(_ role: String) -> String {
        switch role {
        case "owner": return "Owner"
        case "viewer": return "Viewer"
        default: return "Editor"
        }
    }
}
