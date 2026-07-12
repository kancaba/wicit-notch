import SwiftUI
import UniformTypeIdentifiers

struct ClipboardView: View {
    @ObservedObject private var manager = ClipboardManager.shared
    @ObservedObject private var loc = Localization.shared
    @State private var filter: Filter = .recent

    enum Filter: String, CaseIterable, Identifiable {
        case recent = "Recent"
        case images = "Images"
        case colors = "Colors"
        case text = "Text"
        case files = "Files"
        case favorites = "Favorites"

        var id: String { rawValue }

        func title(_ loc: Localization) -> String {
            switch self {
            case .recent: return loc.t("Recent", "Son")
            case .images: return loc.t("Images", "Görseller")
            case .colors: return loc.t("Colors", "Renkler")
            case .text: return loc.t("Text", "Metin")
            case .files: return loc.t("Files", "Dosyalar")
            case .favorites: return loc.t("Favorites", "Favoriler")
            }
        }

        func matches(_ item: ClipItem) -> Bool {
            switch self {
            case .recent: return true
            case .images: return item.kind == .image
            case .colors: return item.kind == .color
            case .text: return item.kind == .text || item.kind == .link
            case .files: return item.kind == .file
            case .favorites: return item.isFavorite
            }
        }
    }

    private var filtered: [ClipItem] {
        manager.items.filter(filter.matches)
    }

    var body: some View {
        VStack(spacing: 10) {
            header
            content
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            ForEach(Filter.allCases) { option in
                Button {
                    filter = option
                } label: {
                    Text(option.title(loc))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(filter == option ? Color.black : Color.white.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(filter == option ? Color.white : Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button {
                manager.clearAll()
            } label: {
                Label(loc.t("Clear all", "Tümünü sil"), systemImage: "trash")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(red: 0.95, green: 0.4, blue: 0.4))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var content: some View {
        if filtered.isEmpty {
            emptyState
        } else {
            TimelineView(.periodic(from: .now, by: 5)) { context in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(filtered) { item in
                            ClipCard(item: item, now: context.date, manager: manager)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 30))
                .foregroundStyle(.white.opacity(0.4))
            Text(loc.t("Copy something to get started", "Bir şey kopyaladığında burada görünür"))
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ClipCard: View {
    let item: ClipItem
    let now: Date
    let manager: ClipboardManager
    @State private var hovering = false

    private let width: CGFloat = 132

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            preview
                .frame(width: width, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            footer
        }
        .frame(width: width)
        .overlay(alignment: .top) { if hovering { actions } }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { manager.copyToPasteboard(item) }
        .onDrag { dragProvider() }
    }

    /// Lets any clip be dragged straight into other apps.
    private func dragProvider() -> NSItemProvider {
        switch item.kind {
        case .text, .link, .color:
            return NSItemProvider(object: (item.text ?? "") as NSString)
        case .image:
            guard let tiff = item.image?.tiffRepresentation else { return NSItemProvider() }
            let provider = NSItemProvider()
            provider.registerDataRepresentation(
                forTypeIdentifier: UTType.tiff.identifier,
                visibility: .all
            ) { completion in
                completion(tiff, nil)
                return nil
            }
            return provider
        case .file:
            guard let url = item.fileURLs.first else { return NSItemProvider() }
            return NSItemProvider(contentsOf: url) ?? NSItemProvider()
        }
    }

    // MARK: - Preview by kind

    @ViewBuilder
    private var preview: some View {
        switch item.kind {
        case .image:
            if let image = item.image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else { placeholder }
        case .color:
            ZStack(alignment: .bottomLeading) {
                Color(nsColor: item.color ?? .gray)
                Text(item.text ?? "")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(textColor(on: item.color))
                    .padding(8)
            }
        case .text, .link:
            ZStack(alignment: .topLeading) {
                Color.white.opacity(0.05)
                VStack(alignment: .leading, spacing: 4) {
                    if item.kind == .link {
                        Image(systemName: "link").font(.system(size: 11)).foregroundStyle(.blue)
                    }
                    Text(item.text ?? "")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(7)
                }
                .padding(8)
            }
        case .file:
            ZStack {
                Color.white.opacity(0.05)
                VStack(spacing: 6) {
                    Image(systemName: "doc.fill").font(.system(size: 28)).foregroundStyle(.white.opacity(0.7))
                    Text(item.previewText)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .padding(.horizontal, 6)
                }
            }
        }
    }

    private var placeholder: some View {
        Color.white.opacity(0.05)
    }

    private var footer: some View {
        HStack(spacing: 5) {
            if let icon = item.sourceIcon {
                Image(nsImage: icon).resizable().frame(width: 13, height: 13)
            }
            Text(item.date.shortRelativeAgo(to: now))
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
        }
        .padding(.top, 5)
        .padding(.horizontal, 2)
    }

    // MARK: - Hover actions

    private var actions: some View {
        HStack {
            iconButton(item.isFavorite ? "star.fill" : "star",
                       tint: item.isFavorite ? .yellow : .white) {
                manager.toggleFavorite(item)
            }
            Spacer()
            iconButton("doc.on.doc") { manager.copyToPasteboard(item) }
            iconButton("trash") { manager.remove(item) }
        }
        .padding(6)
    }

    private func iconButton(_ symbol: String, tint: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.black.opacity(0.55)))
        }
        .buttonStyle(.plain)
    }

    private func textColor(on color: NSColor?) -> Color {
        guard let color = color?.usingColorSpace(.sRGB) else { return .white }
        let luminance = 0.299 * color.redComponent + 0.587 * color.greenComponent + 0.114 * color.blueComponent
        return luminance > 0.6 ? .black : .white
    }
}
