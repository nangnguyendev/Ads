import AdKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var ads: AdManager
    @EnvironmentObject private var game: GameStore
    @State private var isPurchasing = false

    var body: some View {
        List {
            Section {
                if game.isAdFree {
                    Label("Ads removed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button {
                        isPurchasing = true
                        Task {
                            await ads.withFullScreenAdsSuppressed {
                                await game.purchaseRemoveAds()
                            }
                            isPurchasing = false
                        }
                    } label: {
                        HStack {
                            Label("Remove Ads – $2.99", systemImage: "nosign")
                            Spacer()
                            if isPurchasing { ProgressView() }
                        }
                    }
                    .disabled(isPurchasing)
                }
                #if DEBUG
                if game.isAdFree {
                    Button("Restore ads (debug)") { game.isAdFree = false }
                }
                #endif
            } header: {
                Text("Premium")
            } footer: {
                Text("Simulated purchase. In a real app, set ads.isAdFree from your IAP entitlement. Rewarded ads stay available as an opt-in bonus.")
            }

            Section("Privacy") {
                PrivacyOptionsButton(manager: ads) {
                    Label("Your Privacy Choices", systemImage: "hand.raised")
                }
                LabeledContent("Tracking (ATT)", value: ads.trackingStatus.rawValue)
                LabeledContent("Can request ads", value: ads.canRequestAds ? "Yes" : "No")
            }

            Section("Ad status") {
                LabeledContent("State", value: "\(ads.state)")
                LabeledContent("Ready", value: ads.readyFormats.map(\.rawValue).sorted().joined(separator: ", "))
                LabeledContent("Banners", value: ads.shouldShowBanners ? "On" : "Off")
            }

            #if DEBUG
            Section("Debug") {
                Button("Show app open ad now") {
                    Task { await ads.showAppOpenAdIfEligible() }
                }
                Button("Reset frequency history", role: .destructive) {
                    ads.resetHistory()
                }
            }
            #endif
        }
        .navigationTitle("Settings")
    }
}

struct EventLogView: View {
    @EnvironmentObject private var log: AdEventLog

    var body: some View {
        List {
            Section {
                LabeledContent("Estimated revenue", value: "\(log.totalRevenue) USD")
            }
            Section("Events") {
                ForEach(log.entries) { entry in
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.text)
                                .font(.callout)
                            Text(entry.date, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: entry.symbol)
                    }
                }
            }
        }
        .navigationTitle("Ad Log")
        .toolbar {
            Button("Clear") { log.clear() }
        }
    }
}
