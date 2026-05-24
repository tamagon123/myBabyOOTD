import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import Combine

enum TimelineTab: String, CaseIterable, Identifiable {
    case latest   = "新着"
    case recommend = "おすすめ"
    case following = "フォロー中"
    var id: String { rawValue }
}

@MainActor
class PostsViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentTab: TimelineTab = .latest
    @Published var likedPostIds: Set<String> = []

    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    // MARK: - Fetch

    func fetchPosts(user: AppUser?) async {
        isLoading = true
        do {
            var query: Query = db.collection("posts")
                .whereField("is_hidden", isEqualTo: false)
                .order(by: "created_at", descending: true)
                .limit(to: 30)

            switch currentTab {
            case .latest:
                break
            case .recommend:
                if let user = user {
                    let ageMonths = Calendar.current.dateComponents([.month], from: user.child_birthday, to: Date()).month ?? 0
                    let lower = max(0, ageMonths - 3)
                    let upper = ageMonths + 3
                    query = db.collection("posts")
                        .whereField("is_hidden", isEqualTo: false)
                        .whereField("region_code", isEqualTo: user.region_code)
                        .whereField("child_age_months", isGreaterThanOrEqualTo: lower)
                        .whereField("child_age_months", isLessThanOrEqualTo: upper)
                        .order(by: "child_age_months")
                        .order(by: "created_at", descending: true)
                        .limit(to: 30)
                }
            case .following:
                guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else { break }
                let followSnaps = try await db.collection("follows")
                    .whereField("follower_id", isEqualTo: uid)
                    .getDocuments()
                let followingIds = followSnaps.documents.compactMap { $0.data()["following_id"] as? String }
                guard !followingIds.isEmpty else {
                    posts = []
                    isLoading = false
                    return
                }
                query = db.collection("posts")
                    .whereField("is_hidden", isEqualTo: false)
                    .whereField("user_id", in: Array(followingIds.prefix(10)))
                    .order(by: "created_at", descending: true)
                    .limit(to: 30)
            }

            let snapshot = try await query.getDocuments()
            var fetched = try snapshot.documents.map { try $0.data(as: Post.self) }
            fetched = await enrichWithPosterInfo(fetched)
            posts = fetched
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func enrichWithPosterInfo(_ posts: [Post]) async -> [Post] {
        let userIds = Array(Set(posts.map { $0.user_id }))
        var userMap: [String: (avatarId: String, displayName: String?)] = [:]
        await withTaskGroup(of: (String, String, String?)?.self) { group in
            for uid in userIds {
                group.addTask {
                    guard let snap = try? await Firestore.firestore().collection("users").document(uid).getDocument(),
                          let data = snap.data() else { return nil }
                    let avatarId = data["avatar_id"] as? String ?? "🐶"
                    let displayName = data["display_name"] as? String
                    return (uid, avatarId, displayName)
                }
            }
            for await result in group {
                if let (uid, avatarId, displayName) = result {
                    userMap[uid] = (avatarId, displayName)
                }
            }
        }
        return posts.map { post in
            var p = post
            if let info = userMap[post.user_id] {
                p.posterAvatarId = info.avatarId
                p.posterDisplayName = info.displayName
            }
            return p
        }
    }

    func fetchLikedPosts() async {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        do {
            let snap = try await db.collection("likes")
                .whereField("user_id", isEqualTo: uid)
                .getDocuments()
            likedPostIds = Set(snap.documents.compactMap { $0.data()["post_id"] as? String })
        } catch {}
    }

    // MARK: - Like

    func toggleLike(post: Post) async {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid,
              let postId = post.id else { return }

        let likeRef = db.collection("likes").document("\(uid)_\(postId)")
        let postRef = db.collection("posts").document(postId)

        if likedPostIds.contains(postId) {
            likedPostIds.remove(postId)
            try? await likeRef.delete()
            try? await postRef.updateData(["likes_count": FieldValue.increment(Int64(-1))])
            if let idx = posts.firstIndex(where: { $0.id == postId }) {
                posts[idx].likes_count = max(0, posts[idx].likes_count - 1)
            }
        } else {
            likedPostIds.insert(postId)
            try? await likeRef.setData(["user_id": uid, "post_id": postId])
            try? await postRef.updateData(["likes_count": FieldValue.increment(Int64(1))])
            if let idx = posts.firstIndex(where: { $0.id == postId }) {
                posts[idx].likes_count += 1
            }
        }
    }

    // MARK: - Report

    func report(post: Post) async {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid,
              let postId = post.id else { return }

        let reportRef = db.collection("reports").document("\(uid)_\(postId)")
        let snapshot = try? await reportRef.getDocument()
        guard snapshot?.exists != true else { return }

        let postRef = db.collection("posts").document(postId)
        try? await reportRef.setData(["user_id": uid, "post_id": postId])
        try? await postRef.updateData(["reports_count": FieldValue.increment(Int64(1))])

        let postSnap = try? await postRef.getDocument()
        if let count = postSnap?.data()?["reports_count"] as? Int, count >= 5 {
            try? await postRef.updateData(["is_hidden": true])
            posts.removeAll { $0.id == postId }
        }
    }

    // MARK: - Upload Post

    func uploadPost(
        frontImage: UIImage?,
        backImage: UIImage?,
        description: String,
        regionCode: String,
        genderId: Int,
        weatherType: String,
        tempMax: Double,
        tempMin: Double,
        items: [PostItem],
        user: AppUser
    ) async -> Bool {
        guard frontImage != nil || backImage != nil else {
            errorMessage = "フロントまたはバックの写真を1枚以上選択してください。"
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let postId = UUID().uuidString
            let ageMonths = Calendar.current.dateComponents([.month], from: user.child_birthday, to: Date()).month ?? 0
            let tempCat = tempCategoryKey(max: tempMax, min: tempMin)
            let uid = FirebaseAuth.Auth.auth().currentUser?.uid ?? user.user_id

            var frontURL: String? = nil
            var backURL: String? = nil

            if let front = frontImage, let data = stripEXIF(from: front) {
                let ref = storage.reference().child("posts/\(postId)/front.jpg")
                _ = try await ref.putDataAsync(data)
                frontURL = try await ref.downloadURL().absoluteString
            }

            if let back = backImage, let data = stripEXIF(from: back) {
                let ref = storage.reference().child("posts/\(postId)/back.jpg")
                _ = try await ref.putDataAsync(data)
                backURL = try await ref.downloadURL().absoluteString
            }

            let post = Post(
                post_id: postId,
                user_id: uid,
                image_url_front: frontURL,
                image_url_back: backURL,
                child_age_months: ageMonths,
                region_code: regionCode,
                gender_id: genderId,
                description: description,
                weather_type: weatherType,
                temp_max: tempMax,
                temp_min: tempMin,
                temp_category: tempCat,
                likes_count: 0,
                reports_count: 0,
                is_hidden: false,
                created_at: Timestamp(date: Date())
            )

            let postRef = db.collection("posts").document(postId)
            try postRef.setData(from: post)

            for item in items {
                let itemRef = postRef.collection("items").document(item.item_id)
                try itemRef.setData(from: item)
            }

            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Helpers

    private func tempCategoryKey(max: Double, min: Double) -> String {
        let avg = (max + min) / 2
        switch avg {
        case ..<10:  return "0-9"
        case 10..<15: return "10-14"
        case 15..<20: return "15-19"
        case 20..<25: return "20-24"
        default:     return "25-"
        }
    }

    private func stripEXIF(from image: UIImage) -> Data? {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) else { return data }
        let mutableData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(mutableData, type, 1, nil) else { return data }
        let removeMetadata: [String: Any] = [kCGImageDestinationMetadata as String: [:]]
        CGImageDestinationAddImageFromSource(dest, source, 0, removeMetadata as CFDictionary)
        CGImageDestinationFinalize(dest)
        return mutableData as Data
    }
}
