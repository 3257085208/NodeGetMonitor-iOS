import SwiftUI

extension Color {
    static let ngBackground = Color(uiColor: UIColor(red: 246/255, green: 247/255, blue: 251/255, alpha: 1))
    static let ngCard = Color.white
    static let ngPrimary = Color(red: 73/255, green: 191/255, blue: 121/255)
    static let ngPrimarySoft = Color(red: 73/255, green: 191/255, blue: 121/255).opacity(0.16)
    static let ngText = Color(uiColor: UIColor(red: 56/255, green: 67/255, blue: 89/255, alpha: 1))
    static let ngMuted = Color(uiColor: UIColor(red: 133/255, green: 142/255, blue: 160/255, alpha: 1))
    static let ngBorder = Color(uiColor: UIColor(red: 226/255, green: 232/255, blue: 241/255, alpha: 1))
}

struct SoftCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.ngCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.9), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.04), radius: 18, x: 0, y: 10)
                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
            )
    }
}

extension View {
    func ngSoftCard() -> some View {
        modifier(SoftCardModifier())
    }
}

struct AppBackgroundView: View {
    var body: some View {
        ZStack {
            Color.ngBackground.ignoresSafeArea()
            GridPattern()
                .stroke(Color.ngBorder.opacity(0.35), lineWidth: 0.5)
                .ignoresSafeArea()
                .opacity(0.5)
        }
    }
}

struct GridPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 24
        var x: CGFloat = 0
        while x <= rect.maxX {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += spacing
        }
        var y: CGFloat = 0
        while y <= rect.maxY {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += spacing
        }
        return path
    }
}

struct SectionCaption: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(Color.ngMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DashboardPill: View {
    let title: String
    let value: String
    var active: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            Text(value)
                .fontWeight(.black)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(active ? Color.ngPrimary : Color.ngMuted)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(active ? Color.ngPrimarySoft : Color.white.opacity(0.6))
                .overlay(Capsule().stroke(active ? Color.clear : Color.ngBorder, lineWidth: 1))
        )
    }
}
