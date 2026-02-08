import SwiftUI

struct PendingInvitesView: View {
    @EnvironmentObject private var session: SessionViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutDirection) private var layoutDirection

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
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
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
                ToolbarItem(placement: .principal) {
                    HStack {
                        if layoutDirection == .rightToLeft {
                            Spacer()
                        }
                        Text("Pending Invitations")
                            .font(.headline)
                        if layoutDirection == .leftToRight {
                            Spacer()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct PendingInviteRow: View {
    let invite: PendingInvite
    let onAccept: () -> Void
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        let isRTL = layoutDirection == .rightToLeft
        HStack(spacing: 12) {
            if isRTL {
                Button("Accept") {
                    onAccept()
                }
                .buttonStyle(.borderedProminent)
                Spacer()
                inviteInfo
            } else {
                inviteInfo
                Spacer()
                Button("Accept") {
                    onAccept()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
    }

    private var inviteInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(invite.listTitle.isEmpty ? invite.listId : invite.listTitle)
                .fontWeight(.semibold)
            Text(roleLabel(invite.role))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func roleLabel(_ role: String) -> String {
        switch role {
        case "owner": return NSLocalizedString("role_owner", comment: "")
        case "viewer": return NSLocalizedString("role_viewer", comment: "")
        default: return NSLocalizedString("role_editor", comment: "")
        }
    }
}
