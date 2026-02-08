import SwiftUI

struct MembersView: View {
    @EnvironmentObject private var session: SessionViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutDirection) private var layoutDirection
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
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        if layoutDirection == .rightToLeft {
                            Spacer()
                        }
                        Text("Members")
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
    @Environment(\.layoutDirection) private var layoutDirection

    private var isRTL: Bool { layoutDirection == .rightToLeft }

    var body: some View {
        HStack(spacing: 12) {
            if isRTL {
                if isOwner && !member.isCurrentUser {
                    memberMenu
                }
                roleBadge
                Spacer()
                memberInfo
            } else {
                memberInfo
                Spacer()
                roleBadge
                if isOwner && !member.isCurrentUser {
                    memberMenu
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var memberInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if isRTL {
                    if member.isCurrentUser {
                        youBadge
                    }
                    Text(member.name)
                        .fontWeight(.semibold)
                } else {
                    Text(member.name)
                        .fontWeight(.semibold)
                    if member.isCurrentUser {
                        youBadge
                    }
                }
            }
            if !member.email.isEmpty {
                Text(member.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var youBadge: some View {
        Text("You")
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.08))
            .cornerRadius(6)
    }

    private var roleBadge: some View {
        Text(roleLabel(member.role))
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.08))
            .cornerRadius(8)
    }

    private var memberMenu: some View {
        Menu {
            Button("Make Editor") { onRoleChange("editor") }
            Button("Make Viewer") { onRoleChange("viewer") }
            Divider()
            Button("Remove", role: .destructive) { onRemove() }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
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
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        let isRTL = layoutDirection == .rightToLeft
        HStack(spacing: 12) {
            if isRTL {
                if invite.status == "pending" {
                    Button("Revoke", role: .destructive) {
                        onRevoke()
                    }
                }
                Spacer()
                inviteInfo
            } else {
                inviteInfo
                Spacer()
                if invite.status == "pending" {
                    Button("Revoke", role: .destructive) {
                        onRevoke()
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var inviteInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(invite.email)
                .fontWeight(.semibold)
            Text("\(roleLabel(invite.role)) • \(statusLabel(invite.status))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
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
