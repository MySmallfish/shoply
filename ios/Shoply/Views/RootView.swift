import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: SessionViewModel

    var body: some View {
        Group {
            if session.user == nil {
                SignInView()
            } else {
                MainListView()
            }
        }
        .onOpenURL { url in
            session.handleInviteURL(url)
        }
    }
}
