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
                .environment(\.appFontScale, appFontScale(for: fontSizeOption))
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

    private func appFontScale(for option: String) -> CGFloat {
        switch option {
        case "small":
            return 0.92
        case "large":
            return 1.12
        default:
            return 1.0
        }
    }
}

private struct AppFontScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    var appFontScale: CGFloat {
        get { self[AppFontScaleKey.self] }
        set { self[AppFontScaleKey.self] = newValue }
    }
}

private struct AppFontModifier: ViewModifier {
    @Environment(\.appFontScale) private var scale

    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    func body(content: Content) -> some View {
        content.font(.system(size: size * scale, weight: weight, design: design))
    }
}

extension View {
    func appFont(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> some View {
        modifier(AppFontModifier(size: size, weight: weight, design: design))
    }
}
