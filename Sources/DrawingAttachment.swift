import UIKit
import PencilKit

/// 嵌在備忘錄文字裡的手繪圖；保留 PKDrawing，之後可以再編輯
@objc(MemoDrawingAttachment)
final class DrawingAttachment: NSTextAttachment {

    private(set) var drawing = PKDrawing()
    private var canvasWidth: CGFloat = 320

    init(drawing: PKDrawing, canvasWidth: CGFloat) {
        self.drawing = drawing
        self.canvasWidth = canvasWidth
        super.init(data: nil, ofType: nil)
        image = Self.render(drawing, width: canvasWidth)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        if let data = coder.decodeObject(of: NSData.self, forKey: "drawing") as Data?,
           let saved = try? PKDrawing(data: data) {
            drawing = saved
        }
        let width = coder.decodeDouble(forKey: "canvasWidth")
        if width > 0 { canvasWidth = width }
        image = Self.render(drawing, width: canvasWidth)
    }

    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(drawing.dataRepresentation() as NSData, forKey: "drawing")
        coder.encode(Double(canvasWidth), forKey: "canvasWidth")
    }

    override class var supportsSecureCoding: Bool { true }

    // 圖片縮到符合文字寬度
    override func attachmentBounds(for attributes: [NSAttributedString.Key: Any], location: any NSTextLocation,
                                   textContainer: NSTextContainer?, proposedLineFragment: CGRect,
                                   position: CGPoint) -> CGRect {
        fittedBounds(width: proposedLineFragment.width)
    }

    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect,
                                   glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        fittedBounds(width: lineFrag.width)
    }

    private func fittedBounds(width: CGFloat) -> CGRect {
        guard let size = image?.size, size.width > 0 else { return .zero }
        let scale = min(1, (width - 10) / size.width)
        return CGRect(x: 0, y: 0, width: size.width * scale, height: size.height * scale)
    }

    /// 畫成白底圓角的圖，深色模式下也看得清楚
    private static func render(_ drawing: PKDrawing, width: CGFloat) -> UIImage {
        let top = max(0, drawing.bounds.minY - 16)
        let rect = CGRect(x: 0, y: top, width: width, height: max(drawing.bounds.maxY + 16 - top, 60))
        var ink = UIImage()
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            ink = drawing.image(from: rect, scale: 2)
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        return UIGraphicsImageRenderer(size: rect.size, format: format).image { _ in
            UIColor.white.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: rect.size), cornerRadius: 12).fill()
            ink.draw(at: .zero)
        }
    }
}
