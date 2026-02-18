import SwiftUI

struct AppScreenScaffold<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let horizontalInset = max(16, max(proxy.safeAreaInsets.leading, proxy.safeAreaInsets.trailing) + 8)
            let topInset = max(12, proxy.safeAreaInsets.top + 8)
            let bottomInset = max(96, proxy.safeAreaInsets.bottom + 72)

            ZStack(alignment: .topLeading) {
                NightBackdrop()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        content
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, horizontalInset)
                    .padding(.top, topInset)
                    .padding(.bottom, bottomInset)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
    }
}

struct ScreenIntroCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(NightTheme.sectionFont)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(NightTheme.bodyFont)
                .foregroundStyle(NightTheme.label)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(NightTheme.captionFont)
                .foregroundStyle(NightTheme.labelSoft)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}
