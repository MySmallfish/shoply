import FirebaseFirestore
import Foundation

struct MemberRow: Identifiable {
    let id: String
    let name: String
    let email: String
    let role: String
    let isCurrentUser: Bool
}

struct InviteRow: Identifiable {
    let id: String
    let email: String
    let role: String
    let status: String
}

@MainActor
final class MembersViewModel: ObservableObject {
    @Published var members: [MemberRow] = []
    @Published var invites: [InviteRow] = []
    @Published var currentRole: String = "viewer"

    private let repository = ListRepository()
    private let db = Firestore.firestore()
    private var membersListener: ListenerRegistration?
    private var invitesListener: ListenerRegistration?
    private var listId: String?
    private var userId: String?
    private var rawMembers: [ListMember] = []
    private var profileCache: [String: MemberProfile] = [:]

    var isOwner: Bool {
        currentRole == "owner"
    }

    func bind(listId: String, userId: String) {
        if self.listId == listId && self.userId == userId {
            return
        }

        membersListener?.remove()
        invitesListener?.remove()
        membersListener = nil
        invitesListener = nil
        members = []
        invites = []
        currentRole = "viewer"
        profileCache = [:]
        rawMembers = []
        self.listId = listId
        self.userId = userId

        membersListener = repository.listenToMembers(listId: listId) { [weak self] members in
            Task { @MainActor in
                self?.handleMembers(members)
            }
        }
    }

    func updateRole(memberId: String, role: String) {
        guard let listId = listId, isOwner else { return }
        repository.updateMemberRole(listId: listId, memberId: memberId, role: role)
    }

    func removeMember(memberId: String) {
        guard let listId = listId, isOwner else { return }
        repository.removeMember(listId: listId, memberId: memberId)
    }

    func revokeInvite(inviteId: String) {
        guard let listId = listId, isOwner else { return }
        repository.revokeInvite(listId: listId, inviteId: inviteId)
    }

    private func handleMembers(_ members: [ListMember]) {
        rawMembers = members
        if let userId = userId {
            currentRole = members.first(where: { $0.id == userId })?.role ?? "viewer"
        }
        updateMemberRows()
        fetchProfilesIfNeeded(for: members)
        updateInviteListenerIfNeeded()
    }

    private func fetchProfilesIfNeeded(for members: [ListMember]) {
        for member in members {
            if profileCache[member.id] != nil { continue }
            db.collection("users").document(member.id).getDocument { [weak self] snapshot, _ in
                guard let self = self else { return }
                let data = snapshot?.data() ?? [:]
                let profile = MemberProfile(
                    name: data["displayName"] as? String ?? "",
                    email: data["email"] as? String ?? ""
                )
                Task { @MainActor in
                    self.profileCache[member.id] = profile
                    self.updateMemberRows()
                }
            }
        }
    }

    private func updateInviteListenerIfNeeded() {
        guard let listId = listId else { return }
        if isOwner {
            if invitesListener == nil {
                invitesListener = repository.listenToInvites(listId: listId) { [weak self] invites in
                    Task { @MainActor in
                        self?.invites = invites.map {
                            InviteRow(id: $0.id, email: $0.email, role: $0.role, status: $0.status)
                        }
                    }
                }
            }
        } else {
            invitesListener?.remove()
            invitesListener = nil
            invites = []
        }
    }

    private func updateMemberRows() {
        guard let userId = userId else { return }
        let rows = rawMembers.map { member -> MemberRow in
            let profile = profileCache[member.id]
            let displayName = profile?.name ?? ""
            let email = profile?.email ?? ""
            let name = !displayName.isEmpty ? displayName : (!email.isEmpty ? email : member.id)
            return MemberRow(
                id: member.id,
                name: name,
                email: email,
                role: member.role,
                isCurrentUser: member.id == userId
            )
        }

        members = rows.sorted { lhs, rhs in
            rolePriority(lhs.role) < rolePriority(rhs.role)
        }
    }

    private func rolePriority(_ role: String) -> Int {
        switch role {
        case "owner": return 0
        case "editor": return 1
        default: return 2
        }
    }
}

private struct MemberProfile {
    let name: String
    let email: String
}
