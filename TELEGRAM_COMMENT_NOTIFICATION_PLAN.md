# Creator Telegram Comment Notification System — Implementation Plan

This document outlines the complete architectural design and step-by-step implementation plan for routing video comments directly and securely to the respective creator's private Telegram inbox.

---

## 1. System Overview & Architecture

### Key Concept: 1-to-1 Private Direct Messaging via Centralized Bot
- A single official **Vayu Bot** (e.g., `@VayuAppBot`) acts as the delivery agent.
- Telegram uses unique **`chatId`** numbers to send 1-to-1 direct messages (DMs) to individual users.
- **100% Creator Isolation**:
  - Creator A’s comments only route to Creator A's private `chatId`.
  - Creator B’s comments only route to Creator B's private `chatId`.
  - No creator or user has access to anyone else's notification stream.

```
+──────────────────────────────────────────────────────────────────────────────────────────+
|                                1. CREATOR LINKING FLOW                                   |
|                                                                                          |
| [Flutter App]                  [Vayu Backend]                     [Telegram Platform]    |
|       │                              │                                      │            |
|       │ 1. Connect Telegram Request  │                                      │            |
|       ├─────────────────────────────►│                                      │            |
|       │                              │ 2. Generate secure temp linkToken    │            |
|       │◄─────────────────────────────┤    (e.g., token="tg_link_9a8b7c")    │            |
|       │                              │                                      │            |
|       │ 3. Deep link opens Telegram app:                                    │            |
|       │    https://t.me/VayuAppBot?start=tg_link_9a8b7c                     │            |
|       ├────────────────────────────────────────────────────────────────────►│            |
|       │                                                                     │            |
|       │                                4. Creator clicks "Start"            │            |
|       │                                   Bot sends /start payload          │            |
|       │                              │◄─────────────────────────────────────┤            |
|       │                              │                                      │            |
|       │                              │ 5. Webhook links chatId to Creator   │            |
|       │                              │    user.telegram.chatId = "12345678" │            |
|       │                              │    user.telegram.isConnected = true  │            |
|       │                              │                                      │            |
|       │                              │ 6. Confirmation DM sent to Creator   │            |
|       │                              ├─────────────────────────────────────►│            |
+──────────────────────────────────────────────────────────────────────────────────────────+

+──────────────────────────────────────────────────────────────────────────────────────────+
|                           2. ASYNC COMMENT NOTIFICATION FLOW                             |
|                                                                                          |
| [User (Viewer)]                [Vayu Backend]                   [Creator's Telegram DM]  |
|       │                              │                                      │            |
|       │ 1. POST /api/videos/:id/comments                                    │            |
|       ├─────────────────────────────►│                                      │            |
|       │                              │ 2. Save Comment in MongoDB           │            |
|       │                              │    Increment commentsCount           │            |
|       │                              │                                      │            |
|       │ 3. HTTP 200 OK (Instant)     │                                      │            |
|       │◄─────────────────────────────┤                                      │            |
|       │                              │                                      │            |
|       │                              │ 4. [Async / Non-Blocking]            │            |
|       │                              │    Lookup Video Uploader's Profile   │            |
|       │                              │    Check if telegram.isConnected     │            |
|       │                              │                                      │            |
|       │                              │ 5. If Connected, Send Private DM     │            |
|       │                              ├─────────────────────────────────────►│            |
|       │                              │    "💬 New Comment on Video X..."    │            |
+──────────────────────────────────────────────────────────────────────────────────────────+
```

---

## 2. Database Schema Design

### `User` Model (`backend/models/User.js`)
Add the `telegram` subdocument to the User schema:

```javascript
telegram: {
  chatId: {
    type: String,
    default: null,
    index: true,
    sparse: true
  },
  username: {
    type: String,
    default: null
  },
  isConnected: {
    type: Boolean,
    default: false
  },
  notifyOnComments: {
    type: Boolean,
    default: true
  },
  linkToken: {
    type: String,
    default: null,
    index: true,
    sparse: true
  },
  linkTokenExpires: {
    type: Date,
    default: null
  }
}
```

---

## 3. Backend Implementation Plan

### A. Telegram Service (`backend/services/telegramService.js`)
Create a dedicated service to interact with the Telegram Bot API:
- `generateLinkToken(userId)`: Generates a cryptographically random token with a 10-minute TTL.
- `handleWebhookUpdate(update)`: Parses `/start <token>` command from incoming Telegram updates.
- `sendCommentNotification({ uploaderChatId, videoTitle, videoId, commenterName, commentContent })`: Sends formatted HTML/Markdown DM.
- `disconnectTelegram(userId)`: Clears Telegram credentials for user.

### B. Telegram Controller & Routes (`backend/routes/telegramRoutes.js`)
1. `POST /api/creator/telegram/link-token` *(Protected — Creator Auth)*
   - Returns `{ linkUrl: "https://t.me/VayuAppBot?start=tg_link_..." }`
2. `DELETE /api/creator/telegram/disconnect` *(Protected — Creator Auth)*
   - Sets `telegram.isConnected = false` and clears `telegram.chatId`.
3. `POST /api/creator/telegram/settings` *(Protected — Creator Auth)*
   - Toggles `notifyOnComments: true/false`.
4. `POST /api/telegram/webhook` *(Public / Secured with Telegram Webhook Secret Token)*
   - Handles incoming Telegram bot webhook callbacks.

### C. Integrating with Video Comment Service (`backend/services/videoCommentService.js`)
After saving the comment successfully, trigger non-blocking notification:

```javascript
// Fire-and-forget notification (does not block user response)
setImmediate(async () => {
  try {
    const videoWithUploader = await Video.findById(videoId).populate('uploader');
    const uploader = videoWithUploader?.uploader;

    if (
      uploader &&
      uploader.telegram?.isConnected &&
      uploader.telegram?.notifyOnComments &&
      uploader.telegram?.chatId &&
      uploader._id.toString() !== userObj._id.toString() // Don't notify if creator commented on their own video
    ) {
      await telegramService.sendCommentNotification({
        uploaderChatId: uploader.telegram.chatId,
        videoTitle: videoWithUploader.videoName || 'Untitled Video',
        videoId: videoWithUploader._id,
        commenterName: userObj.name,
        commentContent: trimmedContent,
      });
    }
  } catch (err) {
    logger.error('Failed to dispatch Telegram comment notification:', err);
  }
});
```

---

## 4. Telegram Notification Message Template

```markdown
💬 *New Comment on your video!*

📹 *Video:* {videoTitle}
👤 *User:* {commenterName}
📝 *Comment:*
> "{commentContent}"

🔗 [Open in Vayu App](https://vayu.app/video/{videoId})
```

---

## 5. Frontend Implementation Plan (Flutter)

### A. Creator Studio / Settings UI
Add a **"Telegram Notifications"** card in Creator Studio / Profile Settings:
- Status indicator: **Connected** (with username) / **Not Connected**.
- Action Button: **"Connect Telegram"** (launches deep link) / **"Disconnect"**.
- Notification Toggle: Switch for *"Send me comment alerts on Telegram"*.

### B. Deep Link Execution (`url_launcher`)
```dart
Future<void> connectTelegram() async {
  final result = await _telegramService.getLinkUrl();
  final uri = Uri.parse(result.linkUrl);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
```

---

## 6. Security & Best Practices Checklist

1. **Expiring Link Tokens**: Deep link tokens must expire after 10 minutes and be single-use.
2. **Webhook Secret Token**: Verify `X-Telegram-Bot-Api-Secret-Token` header in the webhook endpoint to avoid spoofed payloads.
3. **Rate Limiting**: Throttling on Telegram notifications to prevent hitting Telegram API limits (max 30 messages/sec global, max 1 message/sec per chat).
4. **Creator Self-Comment Filter**: Never send a notification if the creator is replying to their own video.
5. **Data Privacy**: Only share commenter display name and content; do not leak sensitive user metadata.
