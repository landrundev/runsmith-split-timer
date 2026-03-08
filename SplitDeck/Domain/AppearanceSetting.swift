import SwiftUI

// MARK: – Appearance Setting

/// Three-way appearance toggle: Light, Dark, or follow System.
/// Stored in UserDefaults so it persists across launches.
enum AppearanceSetting: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    // MARK: – UserDefaults persistence

    private static let key = "runsmith_appearance"

    static var current: AppearanceSetting {
        get {
            guard let raw = UserDefaults.standard.string(forKey: key),
                  let setting = AppearanceSetting(rawValue: raw)
            else { return .system }
            return setting
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }
}

// MARK: – SwiftUI Environment Key

private struct AppearanceSettingKey: EnvironmentKey {
    static let defaultValue: AppearanceSetting = .system
}

extension EnvironmentValues {
    var appearanceSetting: AppearanceSetting {
        get { self[AppearanceSettingKey.self] }
        set { self[AppearanceSettingKey.self] = newValue }
    }
}
