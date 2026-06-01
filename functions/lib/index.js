"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.diaryReminderJob = exports.onFollowCreated = exports.onLikeCreated = exports.onPostCreated = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();
// ─────────────────────────────────────────────
// ヘルパー: FCMトークンにプッシュ通知を送る
// ─────────────────────────────────────────────
async function sendPush(token, title, body, data) {
    try {
        await messaging.send({
            token,
            notification: { title, body },
            apns: {
                payload: {
                    aps: { sound: "default", badge: 1 },
                },
            },
            data: data !== null && data !== void 0 ? data : {},
        });
    }
    catch (e) {
        functions.logger.warn(`sendPush failed for token ${token.substring(0, 20)}...: ${e.message || e}`);
    }
}
// ─────────────────────────────────────────────
// ヘルパー: ユーザーのFCMトークンを取得する
// ─────────────────────────────────────────────
async function getFcmToken(uid) {
    var _a, _b;
    const doc = await db.collection("users").doc(uid).get();
    return (_b = (_a = doc.data()) === null || _a === void 0 ? void 0 : _a.fcm_token) !== null && _b !== void 0 ? _b : null;
}
// ─────────────────────────────────────────────
// ヘルパー: 通知をFirestoreに保存する
// ─────────────────────────────────────────────
async function saveNotification(userId, type, title, body, relatedId) {
    const docRef = await db.collection("notifications").add({
        user_id: userId,
        type,
        title,
        body,
        related_id: relatedId !== null && relatedId !== void 0 ? relatedId : null,
        is_read: false,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    return docRef.id;
}
// =============================================================================
// 【Function】onPostCreated
// トリガー: posts コレクションにドキュメントが作成されたとき
// 処理:
//   投稿者をフォローしているユーザー全員にプッシュ通知を送る
// =============================================================================
exports.onPostCreated = functions
    .region("asia-northeast1")
    .firestore.document("posts/{postId}")
    .onCreate(async (snap) => {
    var _a, _b;
    const post = snap.data();
    const authorId = post.user_id;
    if (!authorId)
        return;
    // 投稿者の表示名を取得
    const authorDoc = await db.collection("users").doc(authorId).get();
    const authorName = (_b = (_a = authorDoc.data()) === null || _a === void 0 ? void 0 : _a.display_name) !== null && _b !== void 0 ? _b : "ユーザー";
    // 投稿者をフォローしている全ユーザーを取得
    const followsSnap = await db
        .collection("follows")
        .where("following_id", "==", authorId)
        .get();
    const sendTasks = followsSnap.docs.map(async (doc) => {
        const followerId = doc.data().follower_id;
        if (!followerId || followerId === authorId)
            return;
        const token = await getFcmToken(followerId);
        if (!token)
            return;
        await saveNotification(followerId, "new_post", "新しい投稿", `${authorName}さんが投稿しました`, authorId);
        await sendPush(token, "新しい投稿", `${authorName}さんが投稿しました`, { type: "new_post", post_id: snap.id, author_id: authorId });
    });
    await Promise.all(sendTasks);
});
// =============================================================================
// 【Function】onLikeCreated
// トリガー: likes コレクションにドキュメントが作成されたとき
// 処理:
//   いいねされた投稿の作成者にプッシュ通知を送る
// =============================================================================
exports.onLikeCreated = functions
    .region("asia-northeast1")
    .firestore.document("likes/{likeId}")
    .onCreate(async (snap) => {
    var _a, _b, _c;
    const like = snap.data();
    const likerId = like.user_id;
    const postId = like.post_id;
    if (!likerId || !postId)
        return;
    // 投稿を取得して作成者のUIDを特定
    const postDoc = await db.collection("posts").doc(postId).get();
    const postOwnerId = (_a = postDoc.data()) === null || _a === void 0 ? void 0 : _a.user_id;
    if (!postOwnerId || postOwnerId === likerId)
        return;
    // いいねしたユーザーの名前を取得
    const likerDoc = await db.collection("users").doc(likerId).get();
    const likerName = (_c = (_b = likerDoc.data()) === null || _b === void 0 ? void 0 : _b.display_name) !== null && _c !== void 0 ? _c : "ユーザー";
    const token = await getFcmToken(postOwnerId);
    if (!token)
        return;
    await saveNotification(postOwnerId, "like", "いいね！", `${likerName}さんがあなたの投稿にいいねしました`, likerId);
    await sendPush(token, "いいね！", `${likerName}さんがあなたの投稿にいいねしました`, { type: "like", post_id: postId, liker_id: likerId });
});
// =============================================================================
// 【Function】onFollowCreated
// トリガー: follows コレクションにドキュメントが作成されたとき
// 処理:
//   フォローされたユーザーにプッシュ通知を送る
// =============================================================================
exports.onFollowCreated = functions
    .region("asia-northeast1")
    .firestore.document("follows/{followId}")
    .onCreate(async (snap) => {
    var _a, _b;
    const follow = snap.data();
    const followerId = follow.follower_id;
    const followingId = follow.following_id;
    if (!followerId || !followingId)
        return;
    // フォローしたユーザーの名前を取得
    const followerDoc = await db.collection("users").doc(followerId).get();
    const followerName = (_b = (_a = followerDoc.data()) === null || _a === void 0 ? void 0 : _a.display_name) !== null && _b !== void 0 ? _b : "ユーザー";
    const token = await getFcmToken(followingId);
    if (!token)
        return;
    await saveNotification(followingId, "follow", "フォローされました", `${followerName}さんにフォローされました`, followerId);
    await sendPush(token, "フォローされました", `${followerName}さんにフォローされました`, { type: "follow", follower_id: followerId });
});
// =============================================================================
// 【Function】diaryReminderJob
// トリガー: Cloud Scheduler（毎分実行）
// 処理:
//   各ユーザーの diary_reminder_hour/minute に一致する時間帯のユーザーに
//   その日の日記がまだない場合だけプッシュ通知を送る
// 備考:
//   Cloud Schedulerは毎分（"* * * * *"）に実行。
//   各ユーザーの diary_reminder_hour/minute と照合し、
//   一致する時刻のユーザーにのみ通知を送る。
// =============================================================================
exports.diaryReminderJob = functions
    .region("asia-northeast1")
    .pubsub.schedule("* * * * *")
    .timeZone("Asia/Tokyo")
    .onRun(async () => {
    const now = new Date();
    // Cloud FunctionsはUTCで動作するため、JST（UTC+9）に変換
    const jstHour = (now.getUTCHours() + 9) % 24;
    const jstMinute = now.getUTCMinutes();
    functions.logger.info(`diaryReminderJob running: UTC=${now.getUTCHours()}:${now.getUTCMinutes()} -> JST=${jstHour}:${jstMinute}`);
    // リマインダーが有効な全ユーザーを取得し、時刻はコード内で照合
    const usersSnap = await db
        .collection("users")
        .where("diary_reminder_enabled", "==", true)
        .get();
    functions.logger.info(`Found ${usersSnap.size} users with reminder enabled`);
    if (usersSnap.empty)
        return;
    // 現在時刻に一致するユーザーのみ抽出
    const matchedUsers = usersSnap.docs.filter((doc) => {
        const data = doc.data();
        const match = data.diary_reminder_hour === jstHour && data.diary_reminder_minute === jstMinute;
        if (match) {
            functions.logger.info(`Matched user ${doc.id} at ${jstHour}:${jstMinute}`);
        }
        return match;
    });
    functions.logger.info(`Matched ${matchedUsers.length} users for reminder at ${jstHour}:${jstMinute}`);
    if (matchedUsers.length === 0)
        return;
    // 今日の日付キー (Asia/Tokyo)
    const todayKey = tokyoDateKey(now);
    const sendTasks = matchedUsers.map(async (doc) => {
        const uid = doc.id;
        const token = doc.data().fcm_token;
        if (!token) {
            functions.logger.warn(`No FCM token for user ${uid}`);
            return;
        }
        // その日の日記エントリーが存在するか確認
        const entryDoc = await db
            .collection("calendar_entries")
            .doc(uid)
            .collection("entries")
            .doc(todayKey)
            .get();
        // 日記が存在すれば通知しない
        if (entryDoc.exists) {
            functions.logger.info(`User ${uid} already wrote diary for ${todayKey}, skipping`);
            return;
        }
        functions.logger.info(`Sending diary reminder to user ${uid} for ${todayKey}`);
        await saveNotification(uid, "diary_reminder", "今日の日記を書きましょう", "今日のコーディネートや出来事を記録してみませんか？", todayKey);
        await sendPush(token, "今日の日記を書きましょう", "今日のコーディネートや出来事を記録してみませんか？", { type: "diary_reminder", date_key: todayKey });
    });
    await Promise.all(sendTasks);
    functions.logger.info(`diaryReminderJob finished for ${jstHour}:${jstMinute}`);
});
// ─────────────────────────────────────────────
// ヘルパー: DateをAsia/TokyoのyYYY-MM-dd文字列に変換
// ─────────────────────────────────────────────
function tokyoDateKey(date) {
    return date.toLocaleDateString("ja-JP", {
        timeZone: "Asia/Tokyo",
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
    }).replace(/\//g, "-");
}
//# sourceMappingURL=index.js.map