import AdKit
import SwiftUI

struct LevelView: View {
    @EnvironmentObject private var game: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var taps = 0
    @State private var finished = false

    private let target = 5

    var body: some View {
        VStack(spacing: 32) {
            if finished {
                LevelResultView { dismiss() }
            } else {
                Text("Tap \(target - taps) more times")
                    .font(.title2)
                Button {
                    taps += 1
                    if taps >= target {
                        game.completeLevel()
                        finished = true
                    }
                } label: {
                    Image(systemName: "star.fill")
                        .font(.system(size: 80))
                        .padding(40)
                        .background(Circle().fill(.yellow.opacity(0.3)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .navigationTitle("Level \(finished ? game.level - 1 : game.level)")
        .navigationBarBackButtonHidden(finished)
    }
}

struct LevelResultView: View {
    @EnvironmentObject private var ads: AdManager
    @EnvironmentObject private var game: GameStore
    @State private var didDouble = false
    @State private var isContinuing = false
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Level complete!")
                .font(.largeTitle.bold())
            Text("+\(didDouble ? GameStore.coinsPerLevel * 2 : GameStore.coinsPerLevel) coins")
                .font(.title3)

            if !didDouble {
                RewardedAdButton(manager: ads, placement: Placements.doubleCoins) { _ in
                    game.addCoins(GameStore.coinsPerLevel)
                    didDouble = true
                } label: {
                    Label("Watch an ad to double your coins", systemImage: "play.rectangle.fill")
                }
                .buttonStyle(.bordered)
            }

            Button {
                isContinuing = true
                Task {
                    await ads.showInterstitial(at: Placements.levelComplete)
                    onContinue()
                }
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isContinuing)
        }
    }
}
