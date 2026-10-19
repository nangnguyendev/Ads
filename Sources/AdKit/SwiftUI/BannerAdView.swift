#if canImport(UIKit)
import SwiftUI
import UIKit

public struct BannerAdView: View {
    @ObservedObject private var manager: AdManager
    private let placement: AdPlacement
    @State private var height: CGFloat = 0

    public init(manager: AdManager, placement: AdPlacement = .banner) {
        self.manager = manager
        self.placement = placement
    }

    public var body: some View {
        if manager.shouldShowBanners {
            BannerContainer(manager: manager, placement: placement, height: $height)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .accessibilityLabel(Text("Advertisement"))
        }
    }
}

public extension View {
    func adBanner(_ manager: AdManager, placement: AdPlacement = .banner, edge: VerticalEdge = .bottom) -> some View {
        safeAreaInset(edge: edge, spacing: 0) {
            BannerAdView(manager: manager, placement: placement)
        }
    }
}

private struct BannerContainer: UIViewRepresentable {
    let manager: AdManager
    let placement: AdPlacement
    @Binding var height: CGFloat

    func makeUIView(context: Context) -> BannerHostView {
        let host = BannerHostView()
        host.onHeightChange = { newHeight in
            if height != newHeight { height = newHeight }
        }
        host.makeBanner = { [weak manager] in manager?.makeBannerAd(placement: placement) }
        return host
    }

    func updateUIView(_ uiView: BannerHostView, context: Context) {}
}

final class BannerHostView: UIView {
    var makeBanner: (() -> BannerAd?)?
    var onHeightChange: ((CGFloat) -> Void)?

    private var banner: BannerAd?
    private var loadedWidth: CGFloat = 0
    private var loadTask: Task<Void, Never>?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        banner?.rootViewController = window?.rootViewController
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        guard window != nil, width > 0, abs(width - loadedWidth) > 1 else { return }
        loadedWidth = width
        loadBanner(width: width)
    }

    private func loadBanner(width: CGFloat) {
        loadTask?.cancel()
        if banner == nil, let created = makeBanner?() {
            banner = created
            let view = created.view
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
            NSLayoutConstraint.activate([
                view.centerXAnchor.constraint(equalTo: centerXAnchor),
                view.topAnchor.constraint(equalTo: topAnchor)
            ])
        }
        guard let banner else { return }
        banner.rootViewController = window?.rootViewController
        loadTask = Task { @MainActor [weak self] in
            do {
                let size = try await banner.load(width: width)
                guard !Task.isCancelled else { return }
                self?.onHeightChange?(size.height)
            } catch {
                guard !Task.isCancelled else { return }
                self?.onHeightChange?(0)
            }
        }
    }
}
#endif
