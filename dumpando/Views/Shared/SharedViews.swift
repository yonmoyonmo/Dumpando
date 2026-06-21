import SwiftUI

struct SectionCard<Content: View>: View {
    let title: String
    let count: Int
    let showsCount: Bool
    let content: Content

    init(title: String, count: Int, showsCount: Bool = true, @ViewBuilder content: () -> Content) {
        self.title = title
        self.count = count
        self.showsCount = showsCount
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.subtle)

                Spacer()
                if showsCount {
                    Text("\(count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Theme.subtle)
                }
            }

            content
        }
        .padding(8)
        .background(Color.black.opacity(0.03))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct SessionHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    let trailing: Trailing
    let compact: Bool
    let maxWidth: CGFloat?

    init(
        title: String,
        subtitle: String,
        compact: Bool = false,
        maxWidth: CGFloat? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
        self.compact = compact
        self.maxWidth = maxWidth
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title.uppercased())
                    .font(compact ? .caption2.weight(.semibold) : .caption2.weight(.semibold))
                    .tracking(compact ? 1.0 : 1.4)
                    .foregroundStyle(Theme.subtle)

                Text(subtitle)
                    .font(compact ? .callout.weight(.semibold) : .title3.weight(.semibold))
                    .foregroundStyle(Theme.text)
            }

            Spacer()

            trailing
        }
        .frame(maxWidth: maxWidth, alignment: .leading)
        .padding(.bottom, compact ? 0 : 2)
    }
}

struct EmptyInlineRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Theme.subtle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }
}
