import AdKit
import Foundation

@MainActor
final class AdEventLog: ObservableObject {
    struct Entry: Identifiable {
        let id = UUID()
        let date = Date()
        let symbol: String
        let text: String
    }

    @Published private(set) var entries: [Entry] = []
    @Published private(set) var totalRevenue: Decimal = 0

    func record(_ event: AdEvent) {
        let entry: Entry
        switch event {
        case .consentGathered(let status):
            entry = Entry(symbol: "hand.raised", text: "Consent: \(status.rawValue)")
        case .trackingAuthorization(let status):
            entry = Entry(symbol: "location.viewfinder", text: "ATT: \(status.rawValue)")
        case .started:
            entry = Entry(symbol: "power", text: "Ad SDK started")
        case .loaded(let format):
            entry = Entry(symbol: "arrow.down.circle", text: "Loaded \(format.rawValue)")
        case .loadFailed(let format, let message):
            entry = Entry(symbol: "exclamationmark.triangle", text: "Load \(format.rawValue) failed: \(message)")
        case .shown(let format, let placement):
            entry = Entry(symbol: "eye", text: "Shown \(format.rawValue) @ \(placement)")
        case .dismissed:
            return
        case .clicked(let format, let placement):
            entry = Entry(symbol: "hand.tap", text: "Clicked \(format.rawValue) @ \(placement)")
        case .rewarded(let reward, let placement):
            entry = Entry(symbol: "gift", text: "Reward \(reward.amount) \(reward.type) @ \(placement)")
        case .blocked(let format, let placement, let reason):
            entry = Entry(symbol: "nosign", text: "Blocked \(format.rawValue) @ \(placement): \(reason)")
        case .revenue(let revenue):
            totalRevenue += revenue.value
            entry = Entry(symbol: "dollarsign.circle", text: "Revenue \(revenue.value) \(revenue.currencyCode) · \(revenue.format.rawValue) · \(revenue.adSourceName ?? "unknown")")
        }
        entries.insert(entry, at: 0)
        if entries.count > 200 { entries.removeLast() }
    }

    func clear() {
        entries.removeAll()
    }
}
