import AppKit
import SwiftUI

/// The tool rail scrolls when it overflows without showing or reserving space
/// for a macOS scroller, even when the system setting always shows scroll bars.
struct IndicatorlessScrollView<Content: View>: NSViewRepresentable {
    @ViewBuilder let content: () -> Content

    func makeNSView(context: Context) -> Container {
        Container(rootView: content())
    }

    func updateNSView(_ view: Container, context: Context) {
        view.host.rootView = content()
        view.host.invalidateIntrinsicContentSize()
        view.updateDocumentSize()
    }

    /// Left unoptimized on purpose: with the deployment target at 15, the early inliner of the Swift 6.3
    /// compiler crashes while optimizing this class's synthesized `deinit` (the EarlyPerfInliner pass).
    @_optimize(none)
    final class Container: NSScrollView {
        let host: NSHostingView<Content>

        init(rootView: Content) {
            host = NSHostingView(rootView: rootView)
            super.init(frame: .zero)
            drawsBackground = false
            borderType = .noBorder
            hasVerticalScroller = false
            hasHorizontalScroller = false
            horizontalScrollElasticity = .none
            documentView = host
            updateDocumentSize()
        }

        required init?(coder: NSCoder) { nil }

        override func layout() {
            super.layout()
            updateDocumentSize()
        }

        func updateDocumentSize() {
            let height = host.fittingSize.height
            // As wide as the scroll view, so contents of any width (one column of tools or two) fit it.
            let size = NSSize(width: contentView.bounds.width, height: height)
            if host.frame.size != size { host.setFrameSize(size) }
            verticalScrollElasticity = height > contentView.bounds.height + 1 ? .allowed : .none
        }
    }
}
