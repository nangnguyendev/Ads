import Foundation

public struct AdHistory: Codable, Equatable, Sendable {
    public struct Impression: Codable, Equatable, Sendable {
        public let format: AdFormat
        public let placement: String
        public let date: Date

        public init(format: AdFormat, placement: String, date: Date) {
            self.format = format
            self.placement = placement
            self.date = date
        }
    }

    public var firstLaunch: Date?
    public var sessionCount: Int
    public var impressions: [Impression]
    public var pendingTriggers: [String: Int]

    public init(firstLaunch: Date? = nil, sessionCount: Int = 0, impressions: [Impression] = [], pendingTriggers: [String: Int] = [:]) {
        self.firstLaunch = firstLaunch
        self.sessionCount = sessionCount
        self.impressions = impressions
        self.pendingTriggers = pendingTriggers
    }

    public func lastImpression(of formats: Set<AdFormat>) -> Date? {
        impressions.last { formats.contains($0.format) }?.date
    }

    public func count(of format: AdFormat, since date: Date) -> Int {
        impressions.reduce(0) { $1.format == format && $1.date >= date ? $0 + 1 : $0 }
    }

    public mutating func record(_ format: AdFormat, placement: String, at date: Date) {
        impressions.append(Impression(format: format, placement: placement, date: date))
        pendingTriggers[placement] = 0
        prune(now: date)
    }

    public mutating func prune(now: Date) {
        let cutoff = now.addingTimeInterval(-24 * 3600)
        impressions.removeAll { $0.date < cutoff }
    }
}

public protocol AdHistoryStore: AnyObject {
    func load() -> AdHistory
    func save(_ history: AdHistory)
}

public final class UserDefaultsAdHistoryStore: AdHistoryStore {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "com.adkit.history") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> AdHistory {
        guard let data = defaults.data(forKey: key),
              let history = try? JSONDecoder().decode(AdHistory.self, from: data) else { return AdHistory() }
        return history
    }

    public func save(_ history: AdHistory) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: key)
    }
}

public final class InMemoryAdHistoryStore: AdHistoryStore {
    public var history: AdHistory

    public init(history: AdHistory = AdHistory()) {
        self.history = history
    }

    public func load() -> AdHistory { history }
    public func save(_ history: AdHistory) { self.history = history }
}
