import SwiftUI

struct AppTheme {
    let background: Color
    let foreground: Color
    let accent: Color

    static let standard = AppTheme(background: Color(.systemBackground),
                                   foreground: .primary,
                                   accent: .green)
    static let night = AppTheme(background: .black,
                                foreground: Color(red: 0.85, green: 0.1, blue: 0.1),
                                accent: Color(red: 1, green: 0.2, blue: 0.2))
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme.standard
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
