import CoreGraphics

/// Monterey has no vector path Boolean operations. Trace a document-pixel mask there;
/// keep the vector implementation on newer systems. Empty masks are explicit empty paths.
nonisolated enum SelectionPathBoolean {
    enum Operation { case union, intersection, subtract }

    static func combine(_ lhs: CGPath, _ rhs: CGPath, operation: Operation) -> CGPath? {
        if #available(macOS 13, *) {
            switch operation {
            case .union: return lhs.union(rhs, using: .winding)
            case .intersection: return lhs.intersection(rhs, using: .winding)
            case .subtract: return lhs.subtracting(rhs, using: .winding)
            }
        }
        var bounds: CGRect
        switch operation {
        case .union: bounds = lhs.boundingBoxOfPath.union(rhs.boundingBoxOfPath)
        case .intersection: bounds = lhs.boundingBoxOfPath.intersection(rhs.boundingBoxOfPath)
        case .subtract: bounds = lhs.boundingBoxOfPath
        }
        if bounds.isNull || bounds.isEmpty { return CGMutablePath() }
        bounds = bounds.integral
        // Refuse unbounded allocations without changing the existing selection.
        guard bounds.width.isFinite, bounds.height.isFinite,
              bounds.width <= 131072, bounds.height <= 131072,
              bounds.width * bounds.height <= 134217728 else { return nil }
        let width = Int(bounds.width), height = Int(bounds.height)
        guard let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0) else { return nil }
        context.translateBy(x: -bounds.minX, y: bounds.maxY)
        context.scaleBy(x: 1, y: -1)
        context.setShouldAntialias(false)
        context.setFillColor(gray: 1, alpha: 1)
        switch operation {
        case .union:
            context.addPath(lhs); context.fillPath()
            context.addPath(rhs); context.fillPath()
        case .intersection:
            context.addPath(lhs); context.clip()
            context.addPath(rhs); context.fillPath()
        case .subtract:
            context.addPath(lhs); context.fillPath()
            context.setFillColor(gray: 0, alpha: 1)
            context.addPath(rhs); context.fillPath()
        }
        guard let image = context.makeImage() else { return nil }
        guard let outline = MaskTracing.whitePixels(in: image) else { return CGMutablePath() }
        var translation = CGAffineTransform(translationX: bounds.minX, y: bounds.minY)
        return outline.copy(using: &translation)
    }
}
