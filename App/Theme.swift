import SwiftUI
import UIKit

enum Theme {
    static let navy = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.45, green: 0.62, blue: 0.98, alpha: 1)
            : UIColor(red: 0.10, green: 0.28, blue: 0.62, alpha: 1)
    })
    static let navyDeep = Color(red: 0.05, green: 0.12, blue: 0.28)
    static let navyFixed = Color(red: 0.10, green: 0.28, blue: 0.62)
    static let accent = Color(red: 0.20, green: 0.72, blue: 0.85)
    static let warn = Color(red: 0.95, green: 0.55, blue: 0.15)
    static let danger = Color(red: 0.90, green: 0.25, blue: 0.25)
    static let ok = Color(red: 0.18, green: 0.70, blue: 0.45)
    static var hero: LinearGradient {
        LinearGradient(colors: [navyDeep, navyFixed], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension Font {
    static func plex(_ size: CGFloat, _ w: Font.Weight = .regular, relativeTo s: Font.TextStyle = .body) -> Font {
        let name: String
        switch w {
        case .bold, .heavy, .black: name = "IBMPlexSansArabic-Bold"
        case .semibold: name = "IBMPlexSansArabic-SemiBold"
        case .medium: name = "IBMPlexSansArabic-Medium"
        default: name = "IBMPlexSansArabic-Regular"
        }
        return .custom(name, size: size, relativeTo: s)
    }
    static var hTitle: Font { plex(28, .bold, relativeTo: .largeTitle) }
    static var hHeadline: Font { plex(18, .semibold, relativeTo: .headline) }
    static var hBody: Font { plex(16, .regular, relativeTo: .body) }
    static var hCaption: Font { plex(13, .medium, relativeTo: .caption) }
    static var mono: Font { .system(.body, design: .monospaced) }
}

struct CardMod: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(uiColor: .secondarySystemGroupedBackground)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.primary.opacity(0.06), lineWidth: 1))
    }
}
extension View { func card() -> some View { modifier(CardMod()) } }

struct PrimaryButton: ButtonStyle {
    var color: Color = Theme.navy
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.hHeadline).foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(color))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct SharePayload: Identifiable { let id = UUID(); let items: [Any] }

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
