import SwiftUI

@main
struct ShoplyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var session = SessionViewModel()
    @AppStorage("appLanguage") private var appLanguage = "he"

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environment(\.locale, Locale(identifier: appLanguage))
                .environment(\.layoutDirection, isRTL(appLanguage) ? .rightToLeft : .leftToRight)
                .onAppear {
                    session.start()
                }
        }
    }

    private func isRTL(_ language: String) -> Bool {
        language.hasPrefix("he") || language.hasPrefix("ar")
    }
}
