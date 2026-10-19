import AdKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var ads: AdManager

    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Play", systemImage: "gamecontroller") }
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
            NavigationStack { EventLogView() }
                .tabItem { Label("Ad Log", systemImage: "list.bullet.rectangle") }
        }
        .adBanner(ads)
    }
}

struct HomeView: View {
    @EnvironmentObject private var ads: AdManager
    @EnvironmentObject private var game: GameStore

    var body: some View {
        List {
            Section {
                LabeledContent("Level", value: "\(game.level)")
                LabeledContent("Coins", value: "\(game.coins)")
                LabeledContent("Hints", value: "\(game.hints)")
            }

            Section {
                NavigationLink {
                    LevelView()
                } label: {
                    Label("Play level \(game.level)", systemImage: "play.fill")
                        .font(.headline)
                }
            }

            Section {
                RewardedAdButton(manager: ads, placement: Placements.freeHint) { _ in
                    game.addHint()
                } label: {
                    Label("Watch an ad for a free hint", systemImage: "lightbulb")
                }
            } footer: {
                Text("Rewarded ads are always opt-in. The button only appears when an ad is ready.")
            }
        }
        .navigationTitle("Tap Quest")
    }
}
