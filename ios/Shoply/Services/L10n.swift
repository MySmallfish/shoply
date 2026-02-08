import Foundation

enum L10n {
    static func string(_ key: String, language: String) -> String {
        // We use the app-selected language (`appLanguage` in AppStorage) rather than the
        // device preferred languages, because the app forces Hebrew by default even if the
        // device language is English.
        let code = language.split(separator: "-").first.map(String.init) ?? language
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: nil, table: nil)
        }
        return Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }
}

