import Combine
import SwiftUI

/// The gallery screen: grid of captured media, newest first (gallery.md).
/// Tap opens the full-screen viewer; "Select" enters multi-select, where the
/// same tap toggles the item and the bottom bar shares or deletes the set.
struct GalleryView: View {
    @ObservedObject var model: GalleryModel
    @Environment(\.dismiss) private var dismiss
    @State private var selected: GalleryItem?
    @State private var isSelecting = false
    @State private var selection: Set<URL> = []
    @State private var confirmDelete = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    private var selectedItems: [GalleryItem] { model.items.selected(selection) }

    var body: some View {
        NavigationStack {
            Group {
                if model.items.isEmpty {
                    ContentUnavailableView(L("No captures yet"),
                                           systemImage: "photo.on.rectangle")
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(model.items) { item in
                                GalleryCell(model: model, item: item,
                                            isSelected: isSelecting
                                                ? selection.contains(item.url) : nil)
                                    // Gestures, not a Button: a Button fires its
                                    // action on release, so the long press would
                                    // select the item and the release toggle it
                                    // straight back off.
                                    .onTapGesture { tap(item) }
                                    .onLongPressGesture { longPress(item) }
                                    .accessibilityAddTraits(.isButton)
                            }
                        }
                    }
                }
            }
            // A long press has no visual cue until the mode flips; the tick
            // confirms it landed.
            .sensoryFeedback(.selection, trigger: isSelecting)
            .navigationTitle(isSelecting ? selectionTitle : L("Gallery"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .toolbar(isSelecting ? .visible : .hidden, for: .bottomBar)
            .confirmationDialog(L("Delete selected items?"), isPresented: $confirmDelete,
                                titleVisibility: .visible) {
                Button(L("Delete"), role: .destructive) { deleteSelection() }
            }
        }
        .fullScreenCover(item: $selected) { item in
            GalleryDetailView(model: model, current: item)
        }
        .onAppear {
            model.refresh()
            model.events.track(.galleryOpened)
        }
        .onReceive(NotificationCenter.default
            .publisher(for: .captureStoreDidChange)
            .receive(on: DispatchQueue.main)) { _ in model.refresh() }
        // Items deleted elsewhere must not linger in the selection.
        .onChange(of: model.items) { _, items in
            selection.formIntersection(items.map(\.url))
        }
    }

    private var selectionTitle: String {
        selection.isEmpty ? L("Select Items")
            : String(format: L("%d Selected"), selection.count)
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if !isSelecting {
                Button(L("Select")) { isSelecting = true }
                    .disabled(model.items.isEmpty)
                    .accessibilityIdentifier("selectButton")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if isSelecting {
                Button(L("Cancel")) { endSelecting() }
            } else {
                Button(L("Done")) { dismiss() }
            }
        }
        ToolbarItem(placement: .bottomBar) {
            ShareLink(items: selectedItems.map(\.url)) {
                Image(systemName: "square.and.arrow.up")
            }
            // ShareLink has no action hook; the tap that opens the share sheet
            // is the tracked moment.
            .simultaneousGesture(TapGesture().onEnded { model.events.track(.shared) })
            .disabled(selection.isEmpty)
        }
        ToolbarItem(placement: .bottomBar) {
            Button(role: .destructive) { confirmDelete = true } label: {
                Image(systemName: "trash")
            }
            .disabled(selection.isEmpty)
        }
    }

    private func tap(_ item: GalleryItem) {
        guard isSelecting else { return selected = item }
        if selection.contains(item.url) {
            selection.remove(item.url)
        } else {
            selection.insert(item.url)
        }
    }

    /// Long press enters multi-select on the pressed item; inside the mode it
    /// is just another toggle.
    private func longPress(_ item: GalleryItem) {
        guard !isSelecting else { return tap(item) }
        isSelecting = true
        selection = [item.url]
    }

    private func deleteSelection() {
        model.delete(selectedItems)
        endSelecting()
    }

    private func endSelecting() {
        isSelecting = false
        selection = []
    }
}

/// Square thumbnail cell; videos carry a corner badge. `isSelected` is nil
/// outside multi-select, which hides the checkmark entirely.
private struct GalleryCell: View {
    let model: GalleryModel
    let item: GalleryItem
    let isSelected: Bool?
    @State private var image: UIImage?

    var body: some View {
        Color(.secondarySystemBackground)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            }
            .clipped()
            .overlay(alignment: .bottomLeading) {
                if item.kind == .video {
                    Image(systemName: "video.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                        .padding(6)
                }
            }
            .overlay {
                if isSelected == true { Color.black.opacity(0.3) }
            }
            .overlay(alignment: .bottomTrailing) {
                if let isSelected {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, isSelected ? .blue : .clear)
                        .shadow(radius: 2)
                        .padding(6)
                }
            }
            .contentShape(Rectangle())
            .task(id: item.url) { image = await model.thumbnail(for: item) }
    }
}

/// Recent-capture thumbnail control hosted on Main (camera.md "Controls");
/// opens the gallery full screen. Returned to camera via `GalleryProviding`.
struct GalleryThumbnailButton: View {
    @ObservedObject var model: GalleryModel
    @State private var showGallery = false
    @State private var image: UIImage?

    var body: some View {
        Button { showGallery = true } label: {
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay {
                    if let image {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        Image(systemName: "photo.on.rectangle")
                            .foregroundStyle(.white)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .fullScreenCover(isPresented: $showGallery) { GalleryView(model: model) }
        .onAppear { model.refresh() }
        .onReceive(NotificationCenter.default
            .publisher(for: .captureStoreDidChange)
            .receive(on: DispatchQueue.main)) { _ in model.refresh() }
        .task(id: model.latest?.url) {
            guard let latest = model.latest else { return image = nil }
            image = await model.thumbnail(for: latest)
        }
    }
}
