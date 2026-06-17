//
//  CachedAvatarView.swift
//  PIRATEN
//

import SwiftUI

/// Environment key carrying the shared `AvatarImageCache`. Avatars appear in
/// many scattered views, so an environment value is far less invasive than
/// threading the cache through every view-model factory. A shared default
/// keeps the view usable even if a host forgets to inject one.
private struct AvatarImageCacheKey: EnvironmentKey {
    static let defaultValue = AvatarImageCache()
}

extension EnvironmentValues {
    /// The shared avatar image cache.
    var avatarImageCache: AvatarImageCache {
        get { self[AvatarImageCacheKey.self] }
        set { self[AvatarImageCacheKey.self] = newValue }
    }
}

extension View {
    /// Injects the avatar image cache into the environment for descendants.
    func avatarImageCache(_ cache: AvatarImageCache) -> some View {
        environment(\.avatarImageCache, cache)
    }
}

/// A circular avatar that shows a cached image instantly when available and
/// otherwise renders a placeholder while it loads. Drop-in replacement for the
/// repeated `AsyncImage(url:)` avatar blocks; the placeholder is customisable so
/// callers with a distinctive empty state (e.g. initials) keep it.
struct CachedAvatarView<Placeholder: View>: View {
    let url: URL?
    var size: CGFloat
    @ViewBuilder var placeholder: () -> Placeholder

    @Environment(\.avatarImageCache) private var cache
    @State private var image: UIImage?

    init(url: URL?, size: CGFloat = 28, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.size = size
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                placeholder()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            }
        }
        // `.task(id:)` re-runs when the URL changes (cell reuse), seeding from
        // the synchronous memory peek first so a cached avatar paints on the
        // first frame without a placeholder flash.
        .task(id: url) {
            guard let url else {
                image = nil
                return
            }
            if let cached = cache.cachedImage(for: url) {
                image = cached
                return
            }
            image = await cache.image(for: url)
        }
    }
}

extension CachedAvatarView where Placeholder == AnyView {
    /// Convenience initialiser using the standard system person placeholder —
    /// the common case across list rows.
    init(url: URL?, size: CGFloat = 28) {
        self.init(url: url, size: size) {
            AnyView(
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.secondary)
            )
        }
    }
}
