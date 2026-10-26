import SwiftUI
import AppKit

final class PanelHostingView: NSHostingView<AnyView> {
    var sizesToContent = true
    override var intrinsicContentSize: NSSize {
        sizesToContent ? super.intrinsicContentSize : NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }
}

private struct GridSpacing: EnvironmentKey {
    static let defaultValue: CGFloat = 8
}

private extension EnvironmentValues {
    var legacyGridSpacing: CGFloat {
        get { self[GridSpacing.self] }
        set { self[GridSpacing.self] = newValue }
    }
}

/// Small form grids used by the editor, laid out with Monterey stack primitives.
struct Grid<Content: View>: View {
    var alignment: Alignment
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat
    var content: Content

    init(alignment: Alignment = .center, horizontalSpacing: CGFloat = 8,
         verticalSpacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: alignment.horizontal, spacing: verticalSpacing) { content }
            .environment(\.legacyGridSpacing, horizontalSpacing)
    }
}

struct GridRow<Content: View>: View {
    @Environment(\.legacyGridSpacing) private var spacing
    var content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View { HStack(alignment: .firstTextBaseline, spacing: spacing) { content } }
}


enum LegacyScrollIndicators { case never, visible }

extension ScrollView {
    func scrollIndicators(_ visibility: LegacyScrollIndicators) -> some View {
        ScrollView(axes, showsIndicators: visibility == .visible) { content }
    }
}

extension View {
    // These overloads intentionally use the Monterey change observer. Capturing the
    // previous value in each view update preserves the old/new callback contract.
    func onChange<Value: Equatable>(of value: Value,
                                    perform action: @escaping (Value, Value) -> Void) -> some View {
        onChange(of: value) { [value] newValue in action(value, newValue) }
    }

    func onChange<Value: Equatable>(of value: Value,
                                    perform action: @escaping () -> Void) -> some View {
        onChange(of: value) { _ in action() }
    }

    func onGeometryChange<Value: Equatable>(for type: Value.Type,
                                            of transform: @escaping (GeometryProxy) -> Value,
                                            action: @escaping (Value) -> Void) -> some View {
        background(GeometryReader { proxy in
            let value = transform(proxy)
            Color.clear
                .onAppear { action(value) }
                .onChange(of: value, perform: action)
        })
    }
}
