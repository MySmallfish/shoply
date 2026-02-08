import SwiftUI
import UIKit

@main
struct ShoplyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var session = SessionViewModel()
    @AppStorage("appLanguage") private var appLanguage = "he"
    @AppStorage("fontSizeOption") private var fontSizeOption = "default"

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environment(\.locale, Locale(identifier: appLanguage))
                .environment(\.layoutDirection, isRTL(appLanguage) ? .rightToLeft : .leftToRight)
                .environment(\.dynamicTypeSize, dynamicTypeSize(for: fontSizeOption))
                .onAppear {
                    updateSemanticDirection()
                    session.start()
                }
                .onChange(of: appLanguage) { _ in
                    updateSemanticDirection()
                }
        }
    }

    private func isRTL(_ language: String) -> Bool {
        language.hasPrefix("he") || language.hasPrefix("ar")
    }

    private func updateSemanticDirection() {
        let attribute: UISemanticContentAttribute = isRTL(appLanguage) ? .forceRightToLeft : .forceLeftToRight
        UINavigationBar.appearance().semanticContentAttribute = attribute
        UIToolbar.appearance().semanticContentAttribute = attribute
    }

    private func dynamicTypeSize(for option: String) -> DynamicTypeSize {
        switch option {
        case "small":
            return .small
        case "large":
            return .xLarge
        default:
            return .medium
        }
    }
}
