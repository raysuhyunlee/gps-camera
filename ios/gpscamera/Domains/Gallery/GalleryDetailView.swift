import AVKit
import SwiftUI

/// Full-screen pager over the gallery with per-item share + delete (gallery.md).
/// Paging ScrollView, not TabView(.page): the toolbar title re-render mid-swipe
/// left TabView transitions stuck between pages.
struct GalleryDetailView: View {
    @ObservedObject var model: GalleryModel
    @Environment(\.dismiss) private var dismiss
    @State private var currentID: URL?
    @State private var confirmDelete = false
    @State private var showFullTitle = false
    @State private var pagerWidth: CGFloat = 0

    init(model: GalleryModel, current: GalleryItem) {
        self.model = model
        _currentID = State(initialValue: current.url)
    }

    private var current: GalleryItem? {
        model.items.first { $0.url == currentID } ?? model.items.first
    }

    var body: some View {
        NavigationStack {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(model.items) { item in
                        page(for: item)
                            .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentID)
            .scrollIndicators(.hidden)
            .background(.black)
            // Screen width, so the title cap below scales with the device.
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: {
                pagerWidth = $0
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                // Explicit principal item: a plain navigationTitle renders
                // black-on-black over the transparent bar in light mode.
                // Tap shows the untruncated name.
                ToolbarItem(placement: .principal) {
                    Button { showFullTitle = true } label: {
                        Text(current?.url.lastPathComponent ?? "")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            // Cap the width so long names truncate instead of
                            // overlapping the bar buttons: 45% of the screen
                            // leaves room for the 3 buttons on any device.
                            // Middle keeps the distinct tail visible; the full
                            // name is in the popover.
                            .truncationMode(.middle)
                            .frame(maxWidth: max(120, pagerWidth * 0.45))
                    }
                    .popover(isPresented: $showFullTitle) {
                        Text(current?.url.lastPathComponent ?? "")
                            .font(.caption)
                            .padding(8)
                            .presentationCompactAdaptation(.popover)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let current {
                        ShareLink(item: current.url) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .confirmationDialog("Delete this item?", isPresented: $confirmDelete,
                                titleVisibility: .visible) {
                Button("Delete", role: .destructive) { deleteCurrent() }
            }
        }
    }

    @ViewBuilder private func page(for item: GalleryItem) -> some View {
        switch item.kind {
        case .photo: PhotoPage(url: item.url)
        case .video: VideoPage(url: item.url)
        }
    }

    private func deleteCurrent() {
        guard let current else { return }
        let next = model.items.nextSelection(afterDeleting: current)
        model.delete(current)
        if let next { currentID = next.url } else { dismiss() }
    }
}

/// Full-resolution photo, decoded off the main actor.
private struct PhotoPage: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                ProgressView().tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            image = await Task.detached { UIImage(contentsOfFile: url.path) }.value
        }
    }
}

/// Video playback; paused when paged away.
private struct VideoPage: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear { player = AVPlayer(url: url) }
            .onDisappear { player?.pause() }
    }
}
