#if canImport(UIKit)
import SwiftUI
import UIKit

/// A native ad card for a feed or a stack of cards. It takes no space until an ad loads,
/// and loads one ad for the life of the view rather than refreshing.
public struct NativeAdCardView: View {
    @ObservedObject private var manager: AdManager
    private let placement: AdPlacement
    private let style: NativeAdStyle
    @State private var height: CGFloat = 0

    public init(manager: AdManager, placement: AdPlacement = .native, style: NativeAdStyle = NativeAdStyle()) {
        self.manager = manager
        self.placement = placement
        self.style = style
    }

    public var body: some View {
        if manager.shouldShowNativeAds {
            NativeContainer(manager: manager, placement: placement, style: style, height: $height)
                .frame(maxWidth: .infinity)
                .frame(height: height)
        }
    }
}

private struct NativeContainer: UIViewRepresentable {
    let manager: AdManager
    let placement: AdPlacement
    let style: NativeAdStyle
    @Binding var height: CGFloat

    func makeUIView(context: Context) -> NativeHostView {
        let host = NativeHostView()
        host.onHeightChange = { newHeight in
            if height != newHeight { height = newHeight }
        }
        host.makeAd = { [weak manager] in manager?.makeNativeAd(placement: placement, style: style) }
        return host
    }

    func updateUIView(_ uiView: NativeHostView, context: Context) {}
}

final class NativeHostView: UIView {
    var makeAd: (() -> NativeCardAd?)?
    var onHeightChange: ((CGFloat) -> Void)?

    private var ad: NativeCardAd?
    private var isLoaded = false
    private var measuredWidth: CGFloat = 0
    private var loadTask: Task<Void, Never>?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        ad?.rootViewController = window?.rootViewController
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        guard window != nil, width > 0 else { return }
        if ad == nil { startLoading() }
        if isLoaded, abs(width - measuredWidth) > 1 { measure(width: width) }
    }

    private func startLoading() {
        guard let created = makeAd?() else { return }
        ad = created
        let view = created.view
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor),
            view.topAnchor.constraint(equalTo: topAnchor),
        ])
        created.rootViewController = window?.rootViewController
        loadTask = Task { @MainActor [weak self] in
            do {
                try await created.load()
                guard let self, !Task.isCancelled else { return }
                self.isLoaded = true
                self.measure(width: self.bounds.width)
            } catch {
                self?.onHeightChange?(0)
            }
        }
    }

    private func measure(width: CGFloat) {
        guard let ad, width > 0 else { return }
        measuredWidth = width
        onHeightChange?(ceil(ad.fittingHeight(for: width)))
    }
}
#endif
