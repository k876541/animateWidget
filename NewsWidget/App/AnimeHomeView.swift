import SwiftUI

// App 首頁。
// 這個檔案主要負責「畫面如何呈現」，不直接處理 API 細節。
// API 請求、目前選取的分類、動畫列表等狀態都由 AnimeHomeViewModel 管理。
//
// 畫面由上到下分成三塊：
// 1. header：首頁說明文字。
// 2. categorySection：可水平翻頁的動畫分類。
// 3. animeSection：使用者選取分類後顯示的動畫列表。
struct AnimeHomeView: View {
    // @State 讓 SwiftUI 觀察 ViewModel 的狀態。
    // ViewModel 內的資料更新時，依賴那些資料的畫面會重新繪製。
    @State private var viewModel = AnimeHomeViewModel()

    // 點擊列表中的動畫時，這裡會記住目前要放大的作品。
    // selectedPosterItem 有值就顯示滿版 overlay，設回 nil 就關閉。
    @State private var selectedPosterItem: AnimeSummary?

    // 記錄分類 ScrollView 目前停留的頁碼。
    // Optional 是因為 ScrollView 尚未完成 layout 時，可能暫時沒有選中的 page。
    @State private var selectedCategoryPageID: Int? = 0

    var body: some View {
        // 最外層使用 ZStack，才能把海報預覽疊在首頁上方。
        ZStack {
            // NavigationStack 提供 navigation title 與右上角 toolbar。
            NavigationStack {
                // 整個首頁可以垂直滑動，避免動畫摘要太長時超出畫面。
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
                        // 手動重新抓取目前分類的動畫資料。
                        Button {
                            // refresh() 是 async function。
                            // Button action 本身不是 async，所以用 Task 進入非同步流程。
                            Task { await viewModel.refresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel("重新整理")
                        .disabled(viewModel.isLoading)
                    }
                }
                // View 第一次出現在畫面時載入分類和動畫資料。
                // .task 會配合 SwiftUI View 的生命週期管理非同步工作。
                .task {
                    await viewModel.onAppear()
                }
            }

            // Optional binding 語法：selectedPosterItem 有值時才顯示 overlay。
            if let selectedPosterItem {
                PosterPreviewOverlay(item: selectedPosterItem) {
                    self.selectedPosterItem = nil
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }

    // MARK: - Header

    // 首頁頂部的說明區塊。
    // 如果不需要顯示說明文字，可以從 body 的 VStack 移除 header。
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("使用 Jikan API 顯示 MyAnimeList 動畫資料，方便先觀察真實內容長度與海報比例。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Category Section

    // 分類區塊：顯示標題、載入狀態，以及可水平翻頁的分類卡片。
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

            // GeometryReader 可以取得目前畫面可使用的寬度。
            // 每個 page 使用 proxy.size.width，讓水平滑動時一次切換一整頁。
            GeometryReader { proxy in
                // 外層 ScrollView 決定分類頁面可以左右滑動。
                ScrollView(.horizontal) {
                    // 每一個元素不是單張卡片，而是一整頁 AnimeCategoryPage。
                    // 每頁寬度已經等於 ScrollView 可視寬度。
                    // 頁面之間不能再加 spacing，否則每滑一頁都會多偏移一段距離。
                    LazyHStack(alignment: .top, spacing: 0) {
                        ForEach(categoryPages) { page in
                            // 頁面內使用垂直 Grid 排列卡片。
                            // 欄數由 categoryGridColumns 控制。
                            LazyVGrid(columns: categoryGridColumns, spacing: 12) {
                                ForEach(page.items) { item in
                                    AnimeCategoryCard(
                                        category: item.category,
                                        accentColor: categoryAccentColor(at: item.index),
                                        isSelected: viewModel.selectedCategory == item.category
                                    ) {
                                        // 點擊分類卡後，請 ViewModel 重新抓取該分類的動畫列表。
                                        Task { await viewModel.selectCategory(item.category) }
                                    }
                                }
                            }
                            // 每頁左右各留 6 點內距。
                            // 同頁卡片間距是 12；滑動時相鄰兩頁交界也會是 6 + 6 = 12，
                            // 因此不會看到頁面交界的卡片黏在一起。
                            .padding(.horizontal, 6)
                            // 一頁固定吃掉可視寬度，所以水平滑動時看起來會是 6 個一組。
                            .frame(width: proxy.size.width)
                            // scrollPosition 透過 id 判斷目前停在哪一頁。
                            .id(page.id)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.vertical, 0)
                }
                // paging 讓 ScrollView 停在完整頁面，而不是停在兩頁中間。
                .scrollTargetBehavior(.paging)
                .scrollIndicators(.hidden)
                // 避免滑動過程中相鄰頁的內容顯示在目前頁面的外側。
                .clipped()
                // 使用者滑動畫面時更新 page control；點擊圓點時也能反向切換頁面。
                .scrollPosition(id: $selectedCategoryPageID)
            }
            // 分類區的總高度。
            // 若要顯示更多排卡片或調整卡片高度，可以從這裡一起調整。
            .frame(height: 200)

            categoryPageControl
        }
    }

    // 顯示分類 ScrollView 的目前頁數。
    // 每個圓點也是 Button，使用者可以直接點擊切換頁面。
    private var categoryPageControl: some View {
        HStack(spacing: 8) {
            ForEach(categoryPages) { page in
                Button {
                    withAnimation {
                        selectedCategoryPageID = page.id
                    }
                } label: {
                    Circle()
                        .fill(selectedCategoryPageID == page.id ? Color.accentColor : Color.secondary.opacity(0.35))
                        .frame(width: 8, height: 8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("分類第 \(page.id + 1) 頁")
                .accessibilityAddTraits(selectedCategoryPageID == page.id ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Anime List

    // 動畫列表區塊：顯示目前分類、API path、載入時間，以及動畫摘要。
    private var animeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.brief.title)
                        .font(.headline)

                    // 顯示目前對應的 Jikan API path，方便開發時觀察資料來源。
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

            // API 尚未提供資料時顯示空狀態。
            if viewModel.brief.items.isEmpty {
                ContentUnavailableView("尚無動畫", systemImage: "tv", description: Text("請選擇一個動畫分類。"))
            } else {
                // 使用 LazyVStack，讓 row 接近畫面可視範圍時才建立。
                // 如果改用一般 VStack，所有 row 會一次建立，最後一列的 .task 也會立刻執行，
                // 導致畫面尚未往下滑就連續請求 page=2、page=3。
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.brief.items) { item in
                        AnimeSummaryRow(item: item, tint: viewModel.brief.mode.tint)
                            // 讓整列空白區域也能接收點擊，而不只文字和圖片可以點。
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedPosterItem = item
                            }
                            // 最後一列進入畫面時，自動載入下一頁 10 筆資料。
                            .task {
                                await viewModel.loadMoreIfNeeded(currentItem: item)
                            }
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else if !viewModel.hasMoreAnime {
                        // 下一頁沒有資料時，明確提示使用者已經滑到列表底部。
                        Text("沒有更多資料")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                }
            }
        }
    }

    // 分類卡片會依照 index 循環套用不同顏色。
    // 例如第 0 張是 blue，第 7 張又會從 blue 開始。
    private func categoryAccentColor(at index: Int) -> Color {
        let colors: [Color] = [.blue, .orange, .green, .purple, .teal, .pink, .indigo]
        return colors[index % colors.count]
    }

    // Grid 欄位設定。
    // count 代表每一排有幾張分類卡：
    // - count: 2 => 每排 2 張。
    // - count: 3 => 每排 3 張。
    // .flexible() 代表欄寬會平均分配可用空間。
    private var categoryGridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
    }

    // Jikan 回傳的分類是一整個 Array。
    // 這裡把資料切成多頁，每頁最多放 6 張分類卡。
    // 若要調整每頁數量，可以修改 stride 的 by: 6 與 startIndex + 6。
    private var categoryPages: [AnimeCategoryPage] {
        // 保留原始 index，讓每張卡可以依照位置取得對應顏色。
        let indexedCategories = viewModel.categories.enumerated().map { index, category in
            IndexedAnimeCategory(index: index, category: category)
        }

        // stride 會產生 0、6、12、18...，作為每一頁的起始 index。
        return stride(from: 0, to: indexedCategories.count, by: 6).map { startIndex in
            // 最後一頁可能不足 6 筆，所以用 min 避免 Array 越界。
            let endIndex = min(startIndex + 6, indexedCategories.count)
            return AnimeCategoryPage(
                id: startIndex / 6,
                items: Array(indexedCategories[startIndex..<endIndex])
            )
        }
    }
}

// 一頁分類資料。
// categoryPages 會把所有分類切成數個 AnimeCategoryPage，再交給 LazyHStack 顯示。
private struct AnimeCategoryPage: Identifiable {
    // ForEach 需要穩定的 id，這裡使用頁碼作為識別值。
    let id: Int
    let items: [IndexedAnimeCategory]
}

// 在 AnimeCategory 外包一層 index。
// category 負責資料內容，index 則用於決定卡片顏色。
private struct IndexedAnimeCategory: Identifiable {
    let index: Int
    let category: AnimeCategory

    // 直接沿用 AnimeCategory 的 id，讓 SwiftUI 能識別每張卡片。
    var id: Int {
        category.id
    }
}

// MARK: - Category Card

// 單張動畫分類卡片。
// 點擊時會呼叫 action，實際要做的事情由父層 AnimeHomeView 傳入。
private struct AnimeCategoryCard: View {
    let category: AnimeCategory
    let accentColor: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // HStack 讓 icon、文字資訊、空白區由左至右排列。
            HStack(spacing: 8) {
                Image(systemName: "sparkles.tv")
                    .font(.headline)
                    .foregroundStyle(isSelected ? .white : accentColor)
                    // 固定 icon 寬度，讓不同卡片的文字起點對齊。
                    .frame(width: 22)

                // 分類名稱與作品數量上下排列。
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : .primary)
                        // 最多兩行，文字過長時允許縮小到原字級的 72%。
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                        .fixedSize(horizontal: false, vertical: true)

                    // count 是 Optional。API 有提供數量時才顯示。
                    if let count = category.count {
                        Text("作品數量：\(count.formatted())部")
                            .font(.caption2)
                            .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            // 調整分類卡內容與邊框之間的留白。
            .padding(EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 0))
//            .frame(maxWidth: .infinity, minHeight: 92, maxHeight: 92, alignment: .leading)
            // 卡片尺寸。height 會影響分類區一頁可以容納幾排。
            // width 交給 Grid 決定；maxWidth 讓卡片填滿欄位，但不會超出欄位。
            .frame(maxWidth: .infinity, minHeight: 53, maxHeight: 53, alignment: .leading)
            // 選取狀態使用分類色，未選取時使用系統背景色。
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

// MARK: - Anime Summary Row

// 動畫列表中的單列內容。
// 左邊顯示海報，右邊顯示評分、放送日、集數、標題與簡介。
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

// 列表內的小尺寸海報。
private struct AnimePosterView: View {
    let item: AnimeSummary

    var body: some View {
        AnimePosterImage(item: item, contentMode: .fill)
        // 列表海報使用固定尺寸，避免不同原圖比例讓列表左右跳動。
        .frame(width: 76, height: 108)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Poster Preview

// 使用者點擊動畫列表後顯示的滿版海報預覽。
// 整個畫面是一個 Button，因此點擊任意位置都會執行 close。
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

// 同一個 AnimePosterImage 會在不同地方使用：
// - fill：列表縮圖填滿固定框，必要時裁切部分圖片。
// - fit：預覽圖完整顯示，必要時保留空白。
private enum AnimePosterContentMode {
    case fill
    case fit
}

// 統一處理海報圖片來源與縮放方式。
// 優先順序：Assets 本地圖片 -> 網路圖片 -> placeholder。
private struct AnimePosterImage: View {
    let item: AnimeSummary
    let contentMode: AnimePosterContentMode

    var body: some View {
        Group {
            // Mock data 可以指定 Assets.xcassets 內的圖片名稱。
            if let imageAssetName = item.imageAssetName {
                resizedImage(Image(imageAssetName))
                    .accessibilityLabel("\(item.title) 海報")
            // 正式 Jikan API 資料會提供網路圖片 URL。
            } else if let imageURL = item.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    // 圖片正在下載時顯示 loading。
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.tertiarySystemGroupedBackground))
                    // 下載完成後依照使用情境套用 fill 或 fit。
                    case .success(let image):
                        resizedImage(image)
                            .accessibilityLabel("\(item.title) 海報")
                    // 下載失敗時顯示預設 icon。
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

    // @ViewBuilder 允許 function 依照條件回傳不同 View。
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

    // 本地與網路圖片都不存在，或網路圖片下載失敗時顯示。
    private var placeholder: some View {
        Image(systemName: "photo")
            .font(.title2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.tertiarySystemGroupedBackground))
    }
}

// Xcode Canvas 的預覽入口。
// 在 Xcode 右側 Canvas 可以直接觀察 AnimeHomeView 畫面。
#Preview {
    AnimeHomeView()
}
