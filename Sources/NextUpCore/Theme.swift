public enum Theme: String, CaseIterable, Identifiable, Sendable {
    case classic
    case retro

    public static let storageKey = "theme"

    public var id: String { rawValue }

    public init(storedValue: String?) {
        self = storedValue.flatMap(Theme.init(rawValue:)) ?? .classic
    }
}
