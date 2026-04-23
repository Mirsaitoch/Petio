import XCTest
import Foundation
@testable import Petio

final class FeedViewModelTests: XCTestCase {

    // MARK: - Tests

    @MainActor
    func testLoadInitial_FetchesPostsAndSetsHasMore() async throws {
        let mockClient = MockAPIClient()
        mockClient.postsToReturn = [
            Post(id: "1", author: "User1", avatar: nil, content: "Post 1", image: nil, likes: 0, comments: [], club: "Собаки", timestamp: "2026-04-23T10:00:00Z", liked: false),
            Post(id: "2", author: "User2", avatar: nil, content: "Post 2", image: nil, likes: 5, comments: [], club: "Собаки", timestamp: "2026-04-23T09:00:00Z", liked: false)
        ]
        mockClient.hasMoreToReturn = true

        let viewModel = FeedViewModel(apiClient: mockClient)
        await viewModel.loadInitial()

        XCTAssertEqual(viewModel.posts.count, 2)
        XCTAssertEqual(viewModel.posts[0].id, "1")
        XCTAssertEqual(viewModel.posts[1].id, "2")
        XCTAssertEqual(viewModel.hasMore, true)
        XCTAssertEqual(viewModel.isLoading, false)
        XCTAssertNil(viewModel.error)
    }

    @MainActor
    func testLoadMore_AppendsPostsWithAfterId() async throws {
        let mockClient = MockAPIClient()

        // Initial load
        mockClient.postsToReturn = [
            Post(id: "1", author: "User1", avatar: nil, content: "Post 1", image: nil, likes: 0, comments: [], club: "Собаки", timestamp: "2026-04-23T10:00:00Z", liked: false)
        ]
        mockClient.hasMoreToReturn = true

        let viewModel = FeedViewModel(apiClient: mockClient)
        await viewModel.loadInitial()

        // Load more
        mockClient.postsToReturn = [
            Post(id: "2", author: "User2", avatar: nil, content: "Post 2", image: nil, likes: 5, comments: [], club: "Собаки", timestamp: "2026-04-23T09:00:00Z", liked: false),
            Post(id: "3", author: "User3", avatar: nil, content: "Post 3", image: nil, likes: 10, comments: [], club: "Кошки", timestamp: "2026-04-23T08:00:00Z", liked: false)
        ]
        mockClient.hasMoreToReturn = false

        await viewModel.loadMore()

        XCTAssertEqual(viewModel.posts.count, 3)
        XCTAssertEqual(viewModel.posts[0].id, "1")
        XCTAssertEqual(viewModel.posts[1].id, "2")
        XCTAssertEqual(viewModel.posts[2].id, "3")
        XCTAssertEqual(viewModel.hasMore, false)
        XCTAssertEqual(mockClient.lastAfterId, "1")
    }

    @MainActor
    func testRefresh_LoadsNewPostsWithBeforeId() async throws {
        let mockClient = MockAPIClient()

        // Initial load
        mockClient.postsToReturn = [
            Post(id: "2", author: "User2", avatar: nil, content: "Post 2", image: nil, likes: 5, comments: [], club: "Собаки", timestamp: "2026-04-23T09:00:00Z", liked: false)
        ]
        mockClient.hasMoreToReturn = false
        mockClient.hasNewToReturn = true

        let viewModel = FeedViewModel(apiClient: mockClient)
        await viewModel.loadInitial()

        // Refresh (pull-to-refresh)
        mockClient.postsToReturn = [
            Post(id: "0", author: "User0", avatar: nil, content: "Post 0", image: nil, likes: 100, comments: [], club: "Собаки", timestamp: "2026-04-23T11:00:00Z", liked: true)
        ]
        mockClient.hasNewToReturn = false

        await viewModel.refresh()

        XCTAssertEqual(viewModel.posts.count, 2)
        XCTAssertEqual(viewModel.posts[0].id, "0")
        XCTAssertEqual(viewModel.posts[1].id, "2")
        XCTAssertEqual(mockClient.lastBeforeId, "2")
    }

    @MainActor
    func testSelectClub_ResetsStateAndLoadsInitial() async throws {
        let mockClient = MockAPIClient()

        // Initial load with "Все"
        mockClient.postsToReturn = [
            Post(id: "1", author: "User1", avatar: nil, content: "Post 1", image: nil, likes: 0, comments: [], club: "Собаки", timestamp: "2026-04-23T10:00:00Z", liked: false)
        ]
        mockClient.hasMoreToReturn = true

        let viewModel = FeedViewModel(apiClient: mockClient)
        await viewModel.loadInitial()
        XCTAssertEqual(viewModel.posts.count, 1)
        XCTAssertEqual(viewModel.selectedClub, "Все")

        // Select different club
        mockClient.postsToReturn = [
            Post(id: "10", author: "CatUser", avatar: nil, content: "Cat Post", image: nil, likes: 20, comments: [], club: "Кошки", timestamp: "2026-04-23T10:00:00Z", liked: false)
        ]
        mockClient.hasMoreToReturn = false

        await viewModel.selectClub("Кошки")

        XCTAssertEqual(viewModel.selectedClub, "Кошки")
        XCTAssertEqual(viewModel.posts.count, 1)
        XCTAssertEqual(viewModel.posts[0].club, "Кошки")
        XCTAssertEqual(mockClient.lastClub, "Кошки")
    }

    @MainActor
    func testLoadInitial_HandlesError() async throws {
        let mockClient = MockAPIClient()
        mockClient.shouldThrowError = true
        mockClient.errorToThrow = APIError.network(NSError(domain: "test", code: -1))

        let viewModel = FeedViewModel(apiClient: mockClient)
        await viewModel.loadInitial()

        XCTAssertEqual(viewModel.posts.count, 0)
        XCTAssertEqual(viewModel.isLoading, false)
        XCTAssertNotNil(viewModel.error)
    }
}

// MARK: - MockAPIClient

final class MockAPIClient: APIClientProtocol {
    var postsToReturn: [Post] = []
    var hasMoreToReturn = false
    var hasNewToReturn = false
    var shouldThrowError = false
    var errorToThrow: Error?

    // Track parameters passed to fetchPosts
    var lastClub: String?
    var lastLimit: Int?
    var lastAfterId: String?
    var lastBeforeId: String?

    func fetchPosts(
        club: String?,
        limit: Int,
        afterID: String?,
        beforeID: String?
    ) async throws -> PostsResponse {
        // Record parameters
        lastClub = club
        lastLimit = limit
        lastAfterId = afterID
        lastBeforeId = beforeID

        if shouldThrowError, let error = errorToThrow {
            throw error
        }

        return PostsResponse(posts: postsToReturn, hasMore: hasMoreToReturn, hasNew: hasNewToReturn)
    }

    // MARK: - Stub implementations for other protocol methods

    func fetchPets() async throws -> [Pet] {
        []
    }

    func fetchPet(id: String) async throws -> Pet? {
        nil
    }

    func addPet(_ pet: Pet) async throws -> Pet {
        pet
    }

    func updatePet(_ pet: Pet) async throws -> Pet {
        pet
    }

    func deletePet(id: String) async throws {}

    func fetchReminders(petId: String?) async throws -> [Reminder] {
        []
    }

    func addReminder(_ reminder: Reminder) async throws -> Reminder {
        reminder
    }

    func updateReminder(_ reminder: Reminder) async throws -> Reminder {
        reminder
    }

    func deleteReminder(id: String) async throws {}

    func fetchWeightHistory(petId: String) async throws -> [WeightRecord] {
        []
    }

    func addWeightRecord(petId: String, _ record: WeightRecord) async throws {}

    func fetchDiary(petId: String) async throws -> [HealthDiaryEntry] {
        []
    }

    func addDiaryEntry(_ entry: HealthDiaryEntry) async throws -> HealthDiaryEntry {
        entry
    }

    func updateDiaryEntry(_ entry: HealthDiaryEntry) async throws {}

    func deleteDiaryEntry(id: String) async throws {}

    func fetchArticles() async throws -> [Article] {
        []
    }

    func addPost(_ post: Post) async throws -> Post {
        post
    }

    func addPostWithImage(_ post: Post, imageData: Data) async throws -> Post {
        post
    }

    func likePost(id: String, liked: Bool) async throws {}

    func addComment(postId: String, _ comment: Petio.Comment) async throws {}

    func sendChatMessage(_ text: String) async throws -> String {
        ""
    }

    func fetchProfile() async throws -> UserProfile {
        UserProfile(username: "", email: nil, avatar: nil, bio: "", petsCount: 0, postsCount: 0, joinDate: "")
    }

    func updateProfile(_ profile: UserProfile) async throws -> UserProfile {
        profile
    }
}
