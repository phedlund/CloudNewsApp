import SwiftUI

public struct ItemCard: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    public enum Mode: CaseIterable, Hashable {
        case largeWithImage
        case compactWithImage
        case compactNoImage
        case largeNoImage

        var isCompact: Bool {
            switch self {
            case .largeWithImage, .largeNoImage: return false
            case .compactWithImage, .compactNoImage: return true
            }
        }

        var showsImage: Bool {
            switch self {
            case .largeWithImage, .compactWithImage: return true
            case .compactNoImage, .largeNoImage: return false
            }
        }
    }

    public enum Style: Equatable {
        case system
        case filled(background: Color, border: Color = .black, borderOpacity: Double = 0.15)
    }

    public struct Sizes: Equatable {
        public var largeHeight: CGFloat = 160
        public var compactHeight: CGFloat = 85
        public var largeImageWidth: CGFloat = 145
        public var compactImageWidth: CGFloat = 66
        public var cornerRadius: CGFloat = 12
        public var contentSpacing: CGFloat = 12
        public var faviconSize: CGFloat = 22

        public init(largeHeight: CGFloat = 160,
                    compactHeight: CGFloat = 85,
                    largeImageWidth: CGFloat = 145,
                    compactImageWidth: CGFloat = 66,
                    cornerRadius: CGFloat = 12,
                    contentSpacing: CGFloat = 12,
                    faviconSize: CGFloat = 22) {
            self.largeHeight = largeHeight
            self.compactHeight = compactHeight
            self.largeImageWidth = largeImageWidth
            self.compactImageWidth = compactImageWidth
            self.cornerRadius = cornerRadius
            self.contentSpacing = contentSpacing
            self.faviconSize = faviconSize
        }
    }

    // MARK: - Public API
    public var title: String
    public var subtitle: String?
    public var bodyText: String?
    public var imageUrl: URL?
    public var favicon: Image?
    public var showsFavicon: Bool
    public var mode: Mode
    public var isStarred: Bool
    public var sizes: Sizes
    public var style: Style = .system

    public init(title: String,
                subtitle: String? = nil,
                bodyText: String? = nil,
                imageUrl: URL? = nil,
                favicon: Image? = nil,
                showsFavicon: Bool = true,
                mode: Mode,
                isStarred: Bool = false,
                sizes: Sizes = Sizes(),
                style: Style = .system) {
        self.title = title
        self.subtitle = subtitle
        self.bodyText = bodyText
        self.imageUrl = imageUrl
        self.favicon = favicon
        self.showsFavicon = showsFavicon
        self.mode = mode
        self.isStarred = isStarred
        self.sizes = sizes
        self.style = style
    }

    private var borderShapeStyle: AnyShapeStyle {
        switch style {
        case .system:
            return AnyShapeStyle(.separator.opacity(0.4))
        case .filled(_, let border, let opacity):
            return AnyShapeStyle(border.opacity(opacity))
        }
    }

    // MARK: - Body
    public var body: some View {
        ZStack(alignment: .topTrailing) {
            card

            if isStarred {
                Image(systemName: "star.fill")
                    .foregroundStyle(.primary)
                    .padding(8)
            }
        }
        .frame(height: mode.isCompact ? sizes.compactHeight : sizes.largeHeight)
        .background {
#if os(macOS)
            Rectangle().fill(.clear)
#else
            Rectangle().fill(.background)
#endif
        }
        .clipShape(RoundedRectangle(cornerRadius: sizes.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: sizes.cornerRadius, style: .continuous)
                .stroke(borderShapeStyle, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: sizes.cornerRadius, style: .continuous))
    }

    private var card: some View {
        return HStack(alignment: .top, spacing: sizes.contentSpacing) {
            if mode.showsImage, let url = imageUrl {
                ThumbnailImage(url: url, mode: mode, sizes: sizes)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let subtitle, !subtitle.isEmpty {
                    HStack(spacing: 6) {
                        if showsFavicon, let favicon {
                            favicon
                                .resizable()
                                .scaledToFit()
                                .frame(width: sizes.faviconSize, height: sizes.faviconSize)
                                .clipShape(RoundedRectangle(cornerRadius: sizes.faviconSize * 0.2, style: .continuous))
                        }

                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if !mode.isCompact, let bodyText, !bodyText.isEmpty {
                    Text(bodyText)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(4)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .padding(.trailing, isStarred ? 36 : 8)
            .padding(.leading, mode.showsImage ? 0 : 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Optimized Thumbnail Image Component
private struct ThumbnailImage: View {
    let url: URL
    let mode: ItemCard.Mode
    let sizes: ItemCard.Sizes

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var effectiveWidth: CGFloat {
        if mode.isCompact {
            return sizes.compactImageWidth
        } else {
            return horizontalSizeClass == .compact ? sizes.largeImageWidth * 0.75 : sizes.largeImageWidth
        }
    }

    private var effectiveHeight: CGFloat {
        mode.isCompact ? sizes.compactHeight : sizes.largeHeight
    }

    var body: some View {
        PrefetchAsyncImage(url: url) { image in
            image
                .resizable()
                .scaledToFill()
                .frame(width: effectiveWidth, height: effectiveHeight)
                .clipped()
        } placeholder: {
            Color.gray.opacity(0.2)
                .frame(width: effectiveWidth, height: effectiveHeight)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
        }
    }
}

// MARK: - Preview
#Preview("AdaptiveItemCard — interactive") {
    struct Demo: View {
        @State private var mode: ItemCard.Mode = .largeWithImage
        @State private var showFavicon: Bool = true

        private let title = "iPhone Air and iPhone 17 Pro Top Last Year's Phones in Bend and Drop Tests"
        private let subtitle = "Sep 23 | Juli Clover"
        private let summary = "Apple's thin and light iPhone Air is built with a durable titanium frame, and as we've seen demonstrated, it is highly resistant to bending even though it's only 5.6mm thick. Less has been shared about its drop protection, but device insurance provider Allstate..."

        private var imageURL: URL {
            URL(string: "https://pbh.dev/images/apps/cloudnews/iphone1.png")!
        }

        var body: some View {
            VStack(spacing: 16) {
                ItemCard(
                    title: title,
                    subtitle: subtitle,
                    bodyText: summary,
                    imageUrl: imageURL,
                    favicon: Image(systemName: "globe"),
                    showsFavicon: showFavicon,
                    mode: mode,
                    isStarred: true
                )
                .padding(.horizontal)

                Picker("Mode", selection: $mode) {
                    Text("Large + Image").tag(ItemCard.Mode.largeWithImage)
                    Text("Compact + Image").tag(ItemCard.Mode.compactWithImage)
                    Text("Compact").tag(ItemCard.Mode.compactNoImage)
                    Text("Large").tag(ItemCard.Mode.largeNoImage)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Toggle("Show Favicon", isOn: $showFavicon)
                    .padding(.horizontal)
            }
            .frame(maxWidth: 900)
            .padding(.vertical)
            .background(Color(.secondarySystemFill))
        }
    }

    return Demo()
}
