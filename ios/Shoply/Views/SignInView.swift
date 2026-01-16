import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var session: SessionViewModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 8) {
                Text("Shoply")
                    .font(.system(size: 36, weight: .bold))
                Text("Shared lists that update in real time")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.secondary)
            }

            SignInWithAppleButton(.signIn) { request in
                session.prepareAppleRequest(request)
            } onCompletion: { result in
                session.handleAppleResult(result)
            }
            .frame(height: 48)
            .signInWithAppleButtonStyle(.black)

            Button(action: signInWithGoogle) {
                HStack {
                    Image(systemName: "g.circle.fill")
                    Text("Continue with Google")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.black.opacity(0.05))
                .foregroundColor(.primary)
                .cornerRadius(10)
            }

            Spacer()
        }
        .padding(24)
    }

    private func signInWithGoogle() {
        guard let root = rootViewController() else { return }
        session.signInWithGoogle(presenting: root)
    }

    private func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.rootViewController
    }
}
