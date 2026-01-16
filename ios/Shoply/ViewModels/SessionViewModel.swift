import AuthenticationServices
import FirebaseAuth
import FirebaseFirestore
import Foundation
import UIKit

@MainActor
final class SessionViewModel: ObservableObject {
    @Published var user: User?
    @Published var lists: [ShoppingList] = []
    @Published var selectedListId: String?
    @Published var pendingInvites: [PendingInvite] = []
    @Published var inviteActionError: String?

    private let authService = AuthService()
    private let repository = ListRepository()
    private let inviteService = InviteService()
    private var listListener: ListenerRegistration?
    private var pendingInvitesListener: ListenerRegistration?
    private var isCreatingDefault = false
    private var pendingInviteToken: String?
    private var pendingInviteListId: String?

    func start() {
        authService.onUserChanged = { [weak self] user in
            Task { @MainActor in
                self?.handleUserChanged(user)
            }
        }
        authService.start()
    }

    func signInWithGoogle(presenting: UIViewController) {
        authService.signInWithGoogle(presenting: presenting)
    }

    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        authService.prepareAppleRequest(request)
    }

    func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        authService.handleAppleResult(result)
    }

    func signOut() {
        authService.signOut()
    }

    func createList(title: String) {
        guard let userId = user?.uid else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return }
        repository.createList(title: trimmed, ownerId: userId) { [weak self] result in
            if case let .success(listId) = result {
                Task { @MainActor in
                    self?.selectList(listId)
                }
            }
        }
    }

    func selectList(_ listId: String) {
        guard let userId = user?.uid else { return }
        selectedListId = listId
        storeLastListId(listId, userId: userId)
        repository.updateLastList(userId: userId, listId: listId)
    }

    func sendInvite(email: String, role: String, completion: ((Result<String, Error>) -> Void)? = nil) {
        guard let listId = selectedListId else {
            completion?(.failure(InviteError.noListSelected))
            return
        }
        guard let userId = user?.uid else {
            completion?(.failure(InviteError.noListSelected))
            return
        }
        let creatorName = user?.displayName ?? ""
        let creatorEmail = user?.email ?? ""
        let listTitle = lists.first(where: { $0.id == listId })?.title ?? "Shoply list"
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            completion?(.failure(InviteError.invalidEmail))
            return
        }
        inviteService.sendInvite(
            listId: listId,
            listTitle: listTitle,
            createdBy: userId,
            creatorName: creatorName,
            creatorEmail: creatorEmail,
            email: trimmed,
            role: role
        ) { result in
            completion?(result)
        }
    }

    func handleInviteURL(_ url: URL) {
        guard let token = extractInviteToken(from: url) else { return }
        handleInviteToken(token)
    }

    func handleInviteToken(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return }
        if user == nil {
            pendingInviteToken = trimmed
        } else {
            if let listId = pendingInvites.first(where: { $0.token == trimmed })?.listId {
                pendingInviteListId = listId
            }
            acceptInvite(token: trimmed, documentId: pendingInvites.first(where: { $0.token == trimmed })?.id)
        }
    }

    private func handleUserChanged(_ user: User?) {
        self.user = user
        listListener?.remove()
        pendingInvitesListener?.remove()
        lists = []
        selectedListId = nil
        pendingInvites = []
        inviteActionError = nil
        pendingInviteListId = nil

        guard let user = user else { return }
        repository.ensureUserProfile(user: user)
        PushTokenStore.shared.syncIfNeeded()
        listListener = repository.listenToLists(userId: user.uid) { [weak self] lists in
            Task { @MainActor in
                self?.lists = lists
                self?.selectListIfNeeded()
                if lists.isEmpty {
                    self?.createDefaultListIfNeeded()
                }
            }
        }
        pendingInvitesListener = repository.listenToPendingInvites(
            emailLower: user.email?.lowercased()
        ) { [weak self] invites in
            Task { @MainActor in
                self?.pendingInvites = invites.sorted {
                    ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
                }
            }
        }

        consumePendingInviteIfNeeded()
    }

    private func selectListIfNeeded() {
        guard let userId = user?.uid else { return }
        let stored = storedLastListId(userId: userId)
        if let selected = selectedListId, lists.contains(where: { $0.id == selected }) {
            return
        }

        if let pending = pendingInviteListId, lists.contains(where: { $0.id == pending }) {
            pendingInviteListId = nil
            selectedListId = pending
            return
        }

        if let stored = stored, lists.contains(where: { $0.id == stored }) {
            selectedListId = stored
        } else {
            selectedListId = lists.first?.id
        }
    }

    private func createDefaultListIfNeeded() {
        guard !isCreatingDefault, let userId = user?.uid else { return }
        if lists.contains(where: { $0.title.caseInsensitiveCompare("Grocery") == .orderedSame }) {
            return
        }
        isCreatingDefault = true
        repository.createList(title: "Grocery", ownerId: userId) { [weak self] result in
            Task { @MainActor in
                if case let .success(listId) = result {
                    self?.selectList(listId)
                }
                self?.isCreatingDefault = false
            }
        }
    }

    private func storedLastListId(userId: String) -> String? {
        UserDefaults.standard.string(forKey: "lastListId_\(userId)")
    }

    private func storeLastListId(_ listId: String, userId: String) {
        UserDefaults.standard.set(listId, forKey: "lastListId_\(userId)")
    }

    private func consumePendingInviteIfNeeded() {
        guard let token = pendingInviteToken, user != nil else { return }
        pendingInviteToken = nil
        acceptInvite(token: token)
    }

    private func acceptInvite(token: String, documentId: String? = nil) {
        inviteActionError = nil
        inviteService.acceptInvite(token: token, documentId: documentId) { [weak self] result in
            switch result {
            case .success:
                Task { @MainActor in
                    self?.selectListIfNeeded()
                }
            case .failure(let error):
                Task { @MainActor in
                    let nsError = error as NSError
                    let uid = self?.user?.uid ?? ""
                    let path = documentId != nil ? "invitesInbox/\(documentId!)" : "invitesInbox where token=='\(token)'"
                    let attempt = "\(path) update {status:'accepted', acceptedAt:serverTimestamp, acceptedBy:'\(uid)'}"
                    self?.inviteActionError = "Accept failed (\(nsError.domain):\(nsError.code)). \(error.localizedDescription). Attempt: \(attempt)"
                }
            }
        }
    }

    func acceptPendingInvite(_ invite: PendingInvite) {
        pendingInviteListId = invite.listId
        acceptInvite(token: invite.token, documentId: invite.id)
    }

    private func extractInviteToken(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        if let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
           !token.isEmpty {
            return token
        }
        let pathParts = url.pathComponents.filter { $0 != "/" }
        if let inviteIndex = pathParts.firstIndex(of: "invite"),
           pathParts.count > inviteIndex + 1 {
            return pathParts[inviteIndex + 1]
        }
        return nil
    }
}

enum InviteError: LocalizedError {
    case noListSelected
    case invalidEmail

    var errorDescription: String? {
        switch self {
        case .noListSelected:
            return "Select a list before sending an invite."
        case .invalidEmail:
            return "Please enter a valid email address."
        }
    }
}
