import AppKit
import SwiftUI

/// The tool rail scrolls when it overflows without showing or reserving space
/// for a macOS scroller, even when the system setting always shows scroll bars.
struct IndicatorlessScrollView<Content: View>: NSViewRepresentable {
    @ViewBuilder let content: () -> Content

    func makeNSView(context: Context) -> IndicatorlessScrollContainer {
        IndicatorlessScrollContainer(rootView: AnyView(content()))
    }

    func updateNSView(_ view: IndicatorlessScrollContainer, context: Context) {
        view.host.rootView = AnyView(content())
        view.host.invalidateIntrinsicContentSize()
        view.updateDocumentSize()
    }
}

/// Top-level rather than nested: macOS 14's SwiftUI gained a `Container` type,
/// and the nested name made the representable ambiguous when built with a newer SDK.
final class IndicatorlessScrollContainer: NSScrollView {
    let host: NSHostingView<AnyView>

    init(rootView: AnyView) {
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
