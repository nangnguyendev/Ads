#if canImport(UIKit)
import SwiftUI

public struct RewardedAdButton<Label: View>: View {
    @ObservedObject private var manager: AdManager
    private let placement: AdPlacement
    private let onReward: (AdReward) -> Void
    private let label: () -> Label
    @State private var isPresenting = false

    public init(manager: AdManager, placement: AdPlacement, onReward: @escaping (AdReward) -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.manager = manager
        self.placement = placement
        self.onReward = onReward
        self.label = label
    }

    public var body: some View {
        if manager.isRewardedAdAvailable {
            Button {
                guard !isPresenting else { return }
                isPresenting = true
                Task {
                    if let reward = await manager.showRewarded(at: placement) { onReward(reward) }
                    isPresenting = false
                }
            } label: {
                label()
            }
            .disabled(isPresenting)
        }
    }
}

public struct PrivacyOptionsButton<Label: View>: View {
    @ObservedObject private var manager: AdManager
    private let label: () -> Label

    public init(manager: AdManager, @ViewBuilder label: @escaping () -> Label) {
        self.manager = manager
        self.label = label
    }

    public var body: some View {
        if manager.isPrivacyOptionsRequired {
            Button {
                Task { await manager.presentPrivacyOptions() }
            } label: {
                label()
            }
        }
    }
}

public extension PrivacyOptionsButton where Label == Text {
    init(manager: AdManager) {
        self.init(manager: manager) { Text("Privacy Choices") }
    }
}
#endif
