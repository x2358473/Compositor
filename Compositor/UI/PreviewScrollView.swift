import SwiftUI
import AppKit

struct PreviewScrollView<Content: View>: NSViewRepresentable {
    let size: CGSize
    let content: Content

    init(size: CGSize, @ViewBuilder content: () -> Content) {
        self.size = size
        self.content = content()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasHorizontalScroller = true
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.documentView = PannableHostingView(rootView: AnyView(content))
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let host = scroll.documentView as? PannableHostingView else { return }
        let viewport = scroll.contentView.bounds
        let old = host.frame.size
        let next = CGSize(width: max(size.width, viewport.width), height: max(size.height, viewport.height))
        host.rootView = AnyView(content)
        if old != next {
            let fraction = CGPoint(x: old.width > 0 ? viewport.midX / old.width : 0.5,
                                   y: old.height > 0 ? viewport.midY / old.height : 0.5)
            host.setFrameSize(next)
            let origin = CGPoint(x: min(max(0, fraction.x * next.width - viewport.width / 2), max(0, next.width - viewport.width)),
                                 y: min(max(0, fraction.y * next.height - viewport.height / 2), max(0, next.height - viewport.height)))
            scroll.contentView.scroll(to: origin)
            scroll.reflectScrolledClipView(scroll.contentView)
        }
    }
}

private final class PannableHostingView: NSHostingView<AnyView> {
    private var start: CGPoint?
    private var origin = CGPoint.zero

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 { super.mouseDown(with: event); return }
        start = event.locationInWindow
        origin = enclosingScrollView?.contentView.bounds.origin ?? .zero
        NSCursor.closedHand.push()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start, let scroll = enclosingScrollView else { return }
        let location = event.locationInWindow
        let proposed = CGPoint(x: origin.x - location.x + start.x,
                               y: origin.y + (isFlipped ? 1 : -1) * (location.y - start.y))
        let clip = scroll.contentView
        clip.scroll(to: clip.constrainBoundsRect(CGRect(origin: proposed, size: clip.bounds.size)).origin)
        scroll.reflectScrolledClipView(clip)
    }

    override func mouseUp(with event: NSEvent) {
        if start != nil { start = nil; NSCursor.pop() }
        else { super.mouseUp(with: event) }
    }
}
