import SwiftUI

// App 首頁。
// 第一版聚焦：選 Widget 顯示模式、看 Jikan 動漫列表、把資料同步給 Widget。
struct AnimeHomeView: View {
    @State private var viewModel = AnimeHomeViewModel()
    // 點擊列表中的動畫時，這裡會記住目前要放大的作品。
    // selectedPosterItem 有值就顯示滿版 overlay，設回 nil 就關閉。
    @State private var selectedPosterItem: AnimeSummary?

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        categorySection
                        animeSection
                    }
                    .padding(20)
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Anime Widget")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await viewModel.refresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel("重新整理")
                        .disabled(viewModel.isLoading)
                    }
                }
                .task {
                    await viewModel.onAppear()
                }
            }

            if let selectedPosterItem {
                PosterPreviewOverlay(item: selectedPosterItem) {
                    self.selectedPosterItem = nil
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("使用 Jikan API 顯示 MyAnimeList 動畫資料，方便先觀察真實內容長度與海報比例。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("動畫分類")
                    .font(.headline)

                Spacer()

                if viewModel.isLoadingCategories {
                    ProgressView()
                }
            }

            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(viewModel.categories.enumerated()), id: \.element.id) { index, category in
                        AnimeCategoryCard(
                            category: category,
                            accentColor: categoryAccentColor(at: index),
                            isSelected: viewModel.selectedCategory == category
                        ) {
                            Task { await viewModel.selectCategory(category) }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var animeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.brief.title)
                        .font(.headline)

                    Text(viewModel.selectedCategory.map { "/anime?genres=\($0.id)&order_by=popularity&limit=10" } ?? "/genres/anime")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Text(viewModel.brief.updatedAt, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if viewModel.brief.items.isEmpty {
                ContentUnavailableView("尚無動畫", systemImage: "tv", description: Text("請選擇一個動畫分類。"))
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.brief.items) { item in
                        AnimeSummaryRow(item: item, tint: viewModel.brief.mode.tint)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedPosterItem = item
                            }
                    }
                }
            }
        }
    }

    private func categoryAccentColor(at index: Int) -> Color {
        let colors: [Color] = [.blue, .orange, .green, .purple, .teal, .pink, .indigo]
        return colors[index % colors.count]
    }
}

private struct AnimeCategoryCard: View {
    let category: AnimeCategory
    let accentColor: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "sparkles.tv")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : accentColor)

                Spacer()

                Text(category.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let count = category.count {
                    Text(count.formatted())
                        .font(.caption2)
                        .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                }
            }
            .padding(12)
            .frame(width: 100, height: 200, alignment: .leading)
            .background(isSelected ? accentColor : Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.clear : accentColor.opacity(0.25), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.name)
    }
}

private struct AnimeSummaryRow: View {
    let item: AnimeSummary
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AnimePosterView(item: item)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if let score = item.score {
                        Label(score.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.yellow)
                    }

                    if let airingDay = item.airingDay {
                        Label(airingDay, systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(tint)
                    }

                    Spacer()

                    if let episodes = item.episodes {
                        Text("\(episodes) 話")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(item.title)
                    .font(.body.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                if let synopsis = item.synopsis {
                    Text(synopsis)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let source = item.source {
                    Text(source)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityIdentifier("anime-row-\(item.id)")
    }
}

private struct AnimePosterView: View {
    let item: AnimeSummary

    var body: some View {
        AnimePosterImage(item: item, contentMode: .fill)
        .frame(width: 76, height: 108)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct PosterPreviewOverlay: View {
    let item: AnimeSummary
    let close: () -> Void

    var body: some View {
        Button(action: close) {
            GeometryReader { proxy in
                ZStack {
                    // 黑色 60% 透明度的滿版背景。
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()

                    // 中間圖片區塊使用整個 view 的 70%。
                    // scaledToFit 讓海報完整顯示，不會被裁切。
                    AnimePosterImage(item: item, contentMode: .fit)
                        .frame(
                            width: proxy.size.width * 0.7,
                            height: proxy.size.height * 0.7
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("關閉海報預覽")
        .accessibilityIdentifier("poster-preview-overlay")
    }
}

private enum AnimePosterContentMode {
    case fill
    case fit
}

private struct AnimePosterImage: View {
    let item: AnimeSummary
    let contentMode: AnimePosterContentMode

    var body: some View {
        Group {
            if let imageAssetName = item.imageAssetName {
                resizedImage(Image(imageAssetName))
                    .accessibilityLabel("\(item.title) 海報")
            } else if let imageURL = item.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.tertiarySystemGroupedBackground))
                    case .success(let image):
                        resizedImage(image)
                            .accessibilityLabel("\(item.title) 海報")
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
    }

    @ViewBuilder
    private func resizedImage(_ image: Image) -> some View {
        switch contentMode {
        case .fill:
            image
                .resizable()
                .scaledToFill()
        case .fit:
            image
                .resizable()
                .scaledToFit()
        }
    }

    private var placeholder: some View {
        Image(systemName: "photo")
            .font(.title2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.tertiarySystemGroupedBackground))
    }
}

#Preview {
    AnimeHomeView()
}
