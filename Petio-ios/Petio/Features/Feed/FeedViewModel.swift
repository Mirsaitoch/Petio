import Foundation

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var selectedClub = "Все"

    // Состояние пагинации
    @Published var hasMore = false
    @Published var hasNew = false

    private var lastPostID: String?
    private var firstPostID: String?

    private let apiClient: APIClientProtocol
    private let limit = 20

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    // MARK: - Public Methods

    func loadInitial() async {
        isLoading = true
        error = nil
        posts = []
        lastPostID = nil
        firstPostID = nil

        do {
            let response = try await apiClient.fetchPosts(
                club: selectedClub == "Все" ? nil : selectedClub,
                limit: limit,
                afterID: nil,
                beforeID: nil
            )

            posts = response.posts
            hasMore = response.hasMore
            hasNew = response.hasNew

            if let firstPost = posts.first {
                firstPostID = firstPost.id
            }
            if let lastPost = posts.last {
                lastPostID = lastPost.id
            }
        } catch {
            self.error = error.localizedDescription
            print("[FeedViewModel] loadInitial error: \(error)")
        }

        isLoading = false
    }

    func loadMore() async {
        guard !isLoading && hasMore && lastPostID != nil else { return }

        isLoading = true
        error = nil

        do {
            let response = try await apiClient.fetchPosts(
                club: selectedClub == "Все" ? nil : selectedClub,
                limit: limit,
                afterID: lastPostID,
                beforeID: nil
            )

            posts.append(contentsOf: response.posts)
            hasMore = response.hasMore
            hasNew = response.hasNew

            if let lastPost = posts.last {
                lastPostID = lastPost.id
            }
        } catch {
            self.error = error.localizedDescription
            print("[FeedViewModel] loadMore error: \(error)")
        }

        isLoading = false
    }

    func refresh() async {
        isLoading = true
        error = nil

        do {
            let response = try await apiClient.fetchPosts(
                club: selectedClub == "Все" ? nil : selectedClub,
                limit: limit,
                afterID: nil,
                beforeID: firstPostID
            )

            posts.insert(contentsOf: response.posts, at: 0)
            hasNew = response.hasNew

            if let firstPost = posts.first {
                firstPostID = firstPost.id
            }
        } catch {
            self.error = error.localizedDescription
            print("[FeedViewModel] refresh error: \(error)")
        }

        isLoading = false
    }

    func selectClub(_ club: String) async {
        selectedClub = club
        await loadInitial()
    }
}
