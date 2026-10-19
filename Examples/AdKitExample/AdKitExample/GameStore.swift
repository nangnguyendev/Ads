import Foundation

@MainActor
final class GameStore: ObservableObject {
    @Published private(set) var coins: Int { didSet { defaults.set(coins, forKey: "coins") } }
    @Published private(set) var level: Int { didSet { defaults.set(level, forKey: "level") } }
    @Published private(set) var hints: Int { didSet { defaults.set(hints, forKey: "hints") } }
    @Published var isAdFree: Bool { didSet { defaults.set(isAdFree, forKey: "isAdFree") } }

    static let coinsPerLevel = 10

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        coins = defaults.integer(forKey: "coins")
        level = max(1, defaults.integer(forKey: "level"))
        hints = defaults.integer(forKey: "hints")
        isAdFree = defaults.bool(forKey: "isAdFree")
    }

    func completeLevel() {
        coins += Self.coinsPerLevel
        level += 1
    }

    func addCoins(_ amount: Int) {
        coins += amount
    }

    func addHint() {
        hints += 1
    }

    func purchaseRemoveAds() async {
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        isAdFree = true
    }
}
