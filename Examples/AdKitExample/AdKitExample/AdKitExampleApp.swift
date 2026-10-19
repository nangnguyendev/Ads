import AdKit
import SwiftUI

@main
struct AdKitExampleApp: App {
    @StateObject private var ads: AdManager
    @StateObject private var game: GameStore
    @StateObject private var log: AdEventLog

    init() {
        let ads = AdsSetup.makeManager()
        let game = GameStore()
        let log = AdEventLog()
        ads.isAdFree = game.isAdFree
        ads.eventHandler = { log.record($0) }
        ads.revenueHandler = { revenue in
            print("[Analytics] ad_impression value=\(revenue.value) \(revenue.currencyCode) format=\(revenue.format.rawValue) placement=\(revenue.placement)")
        }
        _ads = StateObject(wrappedValue: ads)
        _game = StateObject(wrappedValue: game)
        _log = StateObject(wrappedValue: log)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ads)
                .environmentObject(game)
                .environmentObject(log)
                .task { await ads.start() }
                .onChange(of: game.isAdFree) { ads.isAdFree = $0 }
        }
    }
}
