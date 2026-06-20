import SwiftUI

enum Theme {
    static let background = Color(hex: 0xD4D5D6)
    static let border = Color(hex: 0x808080)
    static let text = Color.black
    static let subtle = Color.black.opacity(0.68)
}

struct AppBackgroundView: View {
    var body: some View {
        Theme.background
            .ignoresSafeArea()
    }
}

struct MonochromeButtonStyle: ButtonStyle {
    enum Kind: Equatable {
        case filled
        case ghost
    }

    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(Theme.text)
            .background(kind == .filled ? Color.black.opacity(configuration.isPressed ? 0.08 : 0.04) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
