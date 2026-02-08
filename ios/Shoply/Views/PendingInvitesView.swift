import SwiftUI

struct PendingInvitesView: View {
    @EnvironmentObject private var session: SessionViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutDirection) private var layoutDirection
    @AppStorage("appLanguage") private var appLanguage = "he"

    var body: some View {
        NavigationStack {
            List {
                if session.pendingInvites.isEmpty {
                    Text(L10n.string("No pending invitations", language: appLanguage))
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
                L10n.string("Invitation", language: appLanguage),
                isPresented: Binding(
                    get: { session.inviteActionError != nil },
                    set: { if !$0 { session.inviteActionError = nil } }
                )
            ) {
                Button(L10n.string("OK", language: appLanguage), role: .cancel) {}
            } message: {
                Text(session.inviteActionError ?? "")
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        if layoutDirection == .rightToLeft {
                            Spacer()
                        }
                        Text(L10n.string("Pending Invitations", language: appLanguage))
                            .font(.headline)
                        if layoutDirection == .leftToRight {
                            Spacer()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("Done", language: appLanguage)) { dismiss() }
                }
            }
        }
    }
}

private struct PendingInviteRow: View {
    let invite: PendingInvite
    let onAccept: () -> Void
    @Environment(\.layoutDirection) private var layoutDirection
    @AppStorage("appLanguage") private var appLanguage = "he"

    var body: some View {
        let isRTL = layoutDirection == .rightToLeft
        HStack(spacing: 12) {
            if isRTL {
                Button(L10n.string("Accept", language: appLanguage)) {
                    onAccept()
                }
                .buttonStyle(.borderedProminent)
                Spacer()
                inviteInfo
            } else {
                inviteInfo
                Spacer()
                Button(L10n.string("Accept", language: appLanguage)) {
                    onAccept()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
    }

    private var inviteInfo: some View {
        let isRTL = layoutDirection == .rightToLeft
        return VStack(alignment: isRTL ? .trailing : .leading, spacing: 6) {
            Text(invite.listTitle.isEmpty ? invite.listId : invite.listTitle)
                .fontWeight(.semibold)
            Text(roleLabel(invite.role))
                .font(.caption)
                .foregroundColor(.secondary)

            if shouldShowCreatorInfo {
                HStack(spacing: 8) {
                    if isRTL {
                        creatorText(isRTL: true)
                        creatorAvatar
                    } else {
                        creatorAvatar
                        creatorText(isRTL: false)
                    }
                }
                .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
            }
        }
    }

    private var shouldShowCreatorInfo: Bool {
        !(invite.creatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && invite.creatorEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && invite.creatorAvatarIcon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var creatorAvatar: some View {
        Group {
            if !invite.creatorAvatarIcon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ItemIconView(icon: invite.creatorAvatarIcon, size: 18)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.system(size: 18))
            }
        }
        .frame(width: 22, height: 22)
    }

    private func creatorText(isRTL: Bool) -> some View {
        let name = invite.creatorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = invite.creatorEmail.trimmingCharacters(in: .whitespacesAndNewlines)

        return VStack(alignment: isRTL ? .trailing : .leading, spacing: 2) {
            if !name.isEmpty {
                Text(name)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if !email.isEmpty {
                Text(email)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
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
