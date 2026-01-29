import Foundation
import SwiftUI

// MARK: - String Extensions

extension String {
    var isValidEmail: Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return range(of: emailRegex, options: .regularExpression) != nil
    }
    
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func truncated(to length: Int, trailing: String = "...") -> String {
        if count <= length {
            return self
        }
        return String(prefix(length)) + trailing
    }
    
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
    
    func localized(with arguments: CVarArg...) -> String {
        String(format: localized, arguments: arguments)
    }
}

// MARK: - Date Extensions

extension Date {
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    var formattedShort: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    var formattedLong: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        return formatter.string(from: self)
    }
    
    var iso8601: String {
        ISO8601DateFormatter().string(from: self)
    }
}

// MARK: - View Extensions

extension View {
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
    
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    func onFirstAppear(perform action: @escaping () -> Void) -> some View {
        modifier(FirstAppearModifier(action: action))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = NSBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct RectCorner: OptionSet {
    let rawValue: Int
    
    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomLeft = RectCorner(rawValue: 1 << 2)
    static let bottomRight = RectCorner(rawValue: 1 << 3)
    
    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
    static let top: RectCorner = [.topLeft, .topRight]
    static let bottom: RectCorner = [.bottomLeft, .bottomRight]
    static let left: RectCorner = [.topLeft, .bottomLeft]
    static let right: RectCorner = [.topRight, .bottomRight]
}

extension NSBezierPath {
    convenience init(roundedRect rect: CGRect, byRoundingCorners corners: RectCorner, cornerRadii: CGSize) {
        self.init()
        
        let topLeft = corners.contains(.topLeft) ? cornerRadii : .zero
        let topRight = corners.contains(.topRight) ? cornerRadii : .zero
        let bottomLeft = corners.contains(.bottomLeft) ? cornerRadii : .zero
        let bottomRight = corners.contains(.bottomRight) ? cornerRadii : .zero
        
        move(to: CGPoint(x: rect.minX + topLeft.width, y: rect.minY))
        
        // Top edge
        line(to: CGPoint(x: rect.maxX - topRight.width, y: rect.minY))
        if corners.contains(.topRight) {
            curve(to: CGPoint(x: rect.maxX, y: rect.minY + topRight.height),
                  controlPoint1: CGPoint(x: rect.maxX, y: rect.minY),
                  controlPoint2: CGPoint(x: rect.maxX, y: rect.minY))
        }
        
        // Right edge
        line(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight.height))
        if corners.contains(.bottomRight) {
            curve(to: CGPoint(x: rect.maxX - bottomRight.width, y: rect.maxY),
                  controlPoint1: CGPoint(x: rect.maxX, y: rect.maxY),
                  controlPoint2: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        
        // Bottom edge
        line(to: CGPoint(x: rect.minX + bottomLeft.width, y: rect.maxY))
        if corners.contains(.bottomLeft) {
            curve(to: CGPoint(x: rect.minX, y: rect.maxY - bottomLeft.height),
                  controlPoint1: CGPoint(x: rect.minX, y: rect.maxY),
                  controlPoint2: CGPoint(x: rect.minX, y: rect.maxY))
        }
        
        // Left edge
        line(to: CGPoint(x: rect.minX, y: rect.minY + topLeft.height))
        if corners.contains(.topLeft) {
            curve(to: CGPoint(x: rect.minX + topLeft.width, y: rect.minY),
                  controlPoint1: CGPoint(x: rect.minX, y: rect.minY),
                  controlPoint2: CGPoint(x: rect.minX, y: rect.minY))
        }
        
        close()
    }
    
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        
        for i in 0..<elementCount {
            let type = element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }
        
        return path
    }
}

struct FirstAppearModifier: ViewModifier {
    let action: () -> Void
    @State private var hasAppeared = false
    
    func body(content: Content) -> some View {
        content.onAppear {
            if !hasAppeared {
                hasAppeared = true
                action()
            }
        }
    }
}

// MARK: - Collection Extensions

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Data Extensions

extension Data {
    var prettyPrintedJSON: String? {
        guard let object = try? JSONSerialization.jsonObject(with: self),
              let data = try? JSONSerialization.data(withJSONObject: object, options: .prettyPrinted),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
}

// MARK: - Decimal Extensions

extension Decimal {
    var currencyFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: self as NSDecimalNumber) ?? "$0.00"
    }
    
    func formatted(currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: self as NSDecimalNumber) ?? "\(currency) 0.00"
    }
}
