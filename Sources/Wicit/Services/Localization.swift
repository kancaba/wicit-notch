import Foundation
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case turkish = "tr"

    var id: String { rawValue }
}

/// Lightweight two-language (EN/TR) localization. Views observe this object and
/// call `t(en, tr)`, so a language switch re-renders the whole UI instantly.
final class Localization: ObservableObject {
    static let shared = Localization()

    private static let defaultsKey = "wicit.language"

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.defaultsKey) }
    }

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.defaultsKey) ?? ""
        language = AppLanguage(rawValue: stored) ?? .system
    }

    /// Resolved language code: "en" or "tr".
    var effective: String {
        switch language {
        case .english: return "en"
        case .turkish: return "tr"
        case .system:
            return Locale.preferredLanguages.first?.hasPrefix("tr") == true ? "tr" : "en"
        }
    }

    var isTurkish: Bool { effective == "tr" }

    /// Locale for date formatting etc.
    var locale: Locale {
        Locale(identifier: isTurkish ? "tr_TR" : "en_US")
    }

    func t(_ en: String, _ tr: String) -> String {
        isTurkish ? tr : en
    }
}
