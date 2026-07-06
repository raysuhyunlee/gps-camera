import Combine
import SwiftUI

/// The gallery screen: grid of captured media, newest first (gallery.md).
/// Tap opens the full-screen viewer.
struct GalleryView: View {
    @ObservedObject var model: GalleryModel
    @Environment(\.dismiss) private var dismiss
    @State private var selected: GalleryItem?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        NavigationStack {
            Group {
                if model.items.isEmpty {
                    ContentUnavailableView("No captures yet",
                                           systemImage: "photo.on.rectangle")
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(model.items) { item in
                                Button { selected = item } label: {
                                    GalleryCell(model: model, item: item)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
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
    }
}

/// Square thumbnail cell; videos carry a corner badge.
private struct GalleryCell: View {
    let model: GalleryModel
    let item: GalleryItem
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
