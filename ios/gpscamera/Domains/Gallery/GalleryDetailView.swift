import AVKit
import SwiftUI

/// Full-screen pager over the gallery with per-item share + delete (gallery.md).
struct GalleryDetailView: View {
    @ObservedObject var model: GalleryModel
    @State var current: GalleryItem
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            TabView(selection: $current) {
                ForEach(model.items) { item in
                    page(for: item).tag(item)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                // Explicit principal item: a plain navigationTitle renders
                // black-on-black over the transparent bar in light mode.
                ToolbarItem(placement: .principal) {
                    Text(current.url.lastPathComponent)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: current.url) {
                        Image(systemName: "square.and.arrow.up")
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
        let next = model.items.nextSelection(afterDeleting: current)
        model.delete(current)
        if let next { current = next } else { dismiss() }
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
