import SwiftUI

/// The default panel content: an AirDrop drop target on the left and the Pocket
/// file shelf on the right.
///
/// Incoming drops are handled in AppKit (`NotchDragHostingView`) so they work
/// during a drag session. Dragging items back *out* of the shelf is handled
/// here with SwiftUI `.onDrag`.
struct HomeView: View {
    @ObservedObject var state: NotchState
    @StateObject private var shelf = FileShelf.shared
    @ObservedObject private var loc = Localization.shared

    var body: some View {
        HStack(spacing: NotchLayout.tileSpacing) {
            AirDropTile(isTargeted: state.hoveredTarget == .airdrop)
            PocketTile(shelf: shelf, isTargeted: state.hoveredTarget == .files)
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - AirDrop tile

private struct AirDropTile: View {
    let isTargeted: Bool
    private let accent = Color(red: 0.29, green: 0.56, blue: 0.90)

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "dot.radiowaves.up.forward")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(accent)
            Text("AirDrop")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TileBackground(isTargeted: isTargeted, accent: accent))
    }
}

// MARK: - Pocket (Files) tile

private struct PocketTile: View {
    @ObservedObject var shelf: FileShelf
    let isTargeted: Bool
    @ObservedObject private var loc = Localization.shared
    private let accent = Color.white.opacity(0.75)

    var body: some View {
        Group {
            if shelf.items.isEmpty {
                emptyState
            } else {
                filledState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TileBackground(isTargeted: isTargeted, accent: accent))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(accent)
            Text(loc.t("Files", "Dosyalar"))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
            Text(loc.t("Drop to pocket", "Cebe bırak"))
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private var filledState: some View {
        VStack(spacing: 8) {
            HStack {
                Text(loc.t("Files", "Dosyalar") + " (\(shelf.items.count))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    shelf.clear()
                } label: {
                    Text(loc.t("Clear", "Temizle"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(shelf.items) { item in
                        ShelfChip(item: item) { shelf.remove(item) }
                    }
                }
            }
        }
        .padding(10)
    }
}

/// A single shelf item — draggable out to Finder / other apps, with a hover
/// delete affordance.
private struct ShelfChip: View {
    let item: ShelfItem
    let onDelete: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: item.icon)
                .resizable()
                .frame(width: 34, height: 34)
            Text(item.displayName)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(hovering ? 0.12 : 0.06))
        )
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white, Color.black.opacity(0.6))
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
            }
        }
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) {
            NSWorkspace.shared.open(item.url)
        }
        .onDrag {
            NSItemProvider(contentsOf: item.url) ?? NSItemProvider()
        }
    }
}

// MARK: - Shared tile chrome

private struct TileBackground: View {
    let isTargeted: Bool
    let accent: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(isTargeted ? 0.12 : 0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isTargeted ? accent.opacity(0.9) : Color.white.opacity(0.08),
                        style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: isTargeted ? [6] : [])
                    )
            )
            .animation(.easeOut(duration: 0.15), value: isTargeted)
    }
}
