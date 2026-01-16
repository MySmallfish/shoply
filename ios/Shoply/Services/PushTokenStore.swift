import FirebaseAuth
import FirebaseFirestore
import Foundation

final class PushTokenStore {
    static let shared = PushTokenStore()
    private let db = Firestore.firestore()
    private let tokenKey = "fcmToken"

    private init() {}

    func updateToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: tokenKey)
        saveIfPossible()
    }

    func syncIfNeeded() {
        saveIfPossible()
    }

    private func saveIfPossible() {
        guard let token = UserDefaults.standard.string(forKey: tokenKey),
              let userId = Auth.auth().currentUser?.uid else { return }
        let data: [String: Any] = [
            "token": token,
            "platform": "ios",
            "updatedAt": FieldValue.serverTimestamp()
        ]
        db.collection("users").document(userId).collection("tokens").document(token).setData(data, merge: true)
    }
}
