import Foundation

final class SettingsStore {
    private enum Keys {
        static let isReadOnlyMode = "OverlayNotes.isReadOnlyMode"
        static let overlayMode = "OverlayNotes.overlayMode"
        static let fontSize = "OverlayNotes.fontSize"
        static let textColorChoice = "OverlayNotes.textColorChoice"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var overlayMode: String {
        get {
            if let mode = defaults.string(forKey: Keys.overlayMode) {
                return mode
            }

            return defaults.bool(forKey: Keys.isReadOnlyMode) ? "readOnly" : "normalEdit"
        }
        set { defaults.set(newValue, forKey: Keys.overlayMode) }
    }

    var fontSize: CGFloat {
        get {
            let storedValue = defaults.double(forKey: Keys.fontSize)
            return storedValue > 0 ? CGFloat(storedValue) : 12
        }
        set {
            defaults.set(Double(newValue), forKey: Keys.fontSize)
        }
    }

    var textColorChoice: String {
        get { defaults.string(forKey: Keys.textColorChoice) ?? "white" }
        set { defaults.set(newValue, forKey: Keys.textColorChoice) }
    }
}
