import SwiftUI

struct MembersView: View {
    @EnvironmentObject private var session: SessionViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = MembersViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section("Members") {
                    if viewModel.members.isEmpty {
                        Text("No members found")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.members) { member in
                            MemberRowView(
                                member: member,
                                isOwner: viewModel.isOwner,
                                onRoleChange: { role in
                                    viewModel.updateRole(memberId: member.id, role: role)
                                },
                                onRemove: {
                                    viewModel.removeMember(memberId: member.id)
                                }
                            )
                        }
                    }
                }

                if viewModel.isOwner {
                    Section("Invites") {
                        if viewModel.invites.isEmpty {
                            Text("No pending invites")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(viewModel.invites) { invite in
                                InviteRowView(invite: invite) {
                                    viewModel.revokeInvite(inviteId: invite.id)
                                }
                            }
                        }
                    }
                } else {
                    Section("Management") {
                        Text("Only the list owner can manage members and invites.")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Members")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { bindIfNeeded() }
        .onChange(of: session.selectedListId) { _ in bindIfNeeded() }
        .onChange(of: session.user?.uid) { _ in bindIfNeeded() }
    }

    private func bindIfNeeded() {
        guard let listId = session.selectedListId,
              let userId = session.user?.uid else { return }
        viewModel.bind(listId: listId, userId: userId)
    }
}

private struct MemberRowView: View {
    let member: MemberRow
    let isOwner: Bool
    let onRoleChange: (String) -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(member.name)
                        .fontWeight(.semibold)
                    if member.isCurrentUser {
                        Text("You")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.08))
                            .cornerRadius(6)
                    }
                }
                if !member.email.isEmpty {
                    Text(member.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

                Text(roleLabel(member.role))
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.08))
                    .cornerRadius(8)

            if isOwner && !member.isCurrentUser {
                Menu {
                    Button("Make Editor") { onRoleChange("editor") }
                    Button("Make Viewer") { onRoleChange("viewer") }
                    Divider()
                    Button("Remove", role: .destructive) { onRemove() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func roleLabel(_ role: String) -> String {
        switch role {
        case "owner": return NSLocalizedString("role_owner", comment: "")
        case "editor": return NSLocalizedString("role_editor", comment: "")
        default: return NSLocalizedString("role_viewer", comment: "")
        }
    }
}

private struct InviteRowView: View {
    let invite: InviteRow
    let onRevoke: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(invite.email)
                    .fontWeight(.semibold)
                Text("\(roleLabel(invite.role)) • \(statusLabel(invite.status))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if invite.status == "pending" {
                Button("Revoke", role: .destructive) {
                    onRevoke()
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func roleLabel(_ role: String) -> String {
        switch role {
        case "owner": return NSLocalizedString("role_owner", comment: "")
        case "editor": return NSLocalizedString("role_editor", comment: "")
        default: return NSLocalizedString("role_viewer", comment: "")
        }
    }

    private func statusLabel(_ status: String) -> String {
        switch status {
        case "accepted": return NSLocalizedString("status_accepted", comment: "")
        case "revoked": return NSLocalizedString("status_revoked", comment: "")
        default: return NSLocalizedString("status_pending", comment: "")
        }
    }
}
