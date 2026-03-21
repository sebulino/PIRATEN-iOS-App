# Push Notifications — Rails Server Implementation Guide

**For:** meine-piraten.de Rails server
**Requested by:** PIRATEN iOS App
**Status:** Ready for implementation
**Related open question:** Q-014 in `OPEN_QUESTIONS.md`

---

## Overview

The iOS app is fully wired for push notifications on the client side. It can:
- Request permission from the user
- Receive APNs device tokens from Apple
- Register/deregister tokens with the backend
- Handle notification taps and route to the correct screen via deep links

What is **missing** is the server side: storing device tokens, and sending APNs pushes when events occur.

---

## 1. Database Schema

### Table: `push_subscriptions`

```ruby
create_table :push_subscriptions do |t|
  t.string  :token,            null: false               # APNs device token (hex string)
  t.string  :platform,         null: false, default: "ios"
  t.integer :user_id,          null: false               # FK to users table
  t.boolean :messages_enabled, null: false, default: false
  t.boolean :todos_enabled,    null: false, default: false
  t.boolean :forum_enabled,    null: false, default: false
  t.boolean :news_enabled,     null: false, default: false
  t.timestamps
end

add_index :push_subscriptions, :token, unique: true
add_index :push_subscriptions, :user_id
```

**Notes:**
- One row per device token. A user may have multiple rows (multiple devices).
- `token` must be unique — upsert on registration (update preferences if token already exists).
- Delete the row on logout or when the user disables all categories.

---

## 2. API Endpoints

### 2.1 Register or update a device token

```
POST /api/push-subscriptions
Content-Type: application/json
Authorization: Bearer <access_token>
```

**Request body:**
```json
{
  "token": "a1b2c3d4e5f6...",
  "platform": "ios",
  "messages": true,
  "todos": false,
  "forum": true,
  "news": false
}
```

**Behaviour:**
- Identify the user from the `Authorization` header (existing session/token auth).
- Upsert: if a `push_subscriptions` row with this `token` already exists, update its preference columns. Otherwise insert a new row.
- Respond `200 OK` with `{}` on success.
- Respond `401 Unauthorized` if the token is invalid or missing.
- Respond `422 Unprocessable Entity` with error details if validation fails.

**Rails sketch:**
```ruby
# routes.rb
namespace :api do
  resources :push_subscriptions, only: [:create, :destroy]
end

# push_subscriptions_controller.rb
def create
  sub = PushSubscription.find_or_initialize_by(token: params[:token])
  sub.assign_attributes(
    user: current_user,
    platform: params[:platform] || "ios",
    messages_enabled: params[:messages] == true,
    todos_enabled:    params[:todos]    == true,
    forum_enabled:    params[:forum]    == true,
    news_enabled:     params[:news]     == true
  )
  sub.save!
  render json: {}, status: :ok
end
```

---

### 2.2 Deregister a device token

```
DELETE /api/push-subscriptions/:token
Authorization: Bearer <access_token>
```

**Behaviour:**
- Find the row by `token` and delete it.
- Respond `200 OK` with `{}` on success.
- Respond `404 Not Found` if the token is unknown (treat as success — idempotent).
- Respond `401 Unauthorized` if the auth header is invalid.

**Rails sketch:**
```ruby
def destroy
  sub = PushSubscription.find_by(token: params[:id])
  sub&.destroy
  render json: {}, status: :ok
end
```

---

## 3. APNs Integration

### 3.1 Credentials (from Apple Developer account)

You need the following from the Apple Developer Console:
- **APNs Auth Key** — a `.p8` file (token-based auth, recommended over certificates)
- **Key ID** — 10-character string shown alongside the key
- **Team ID** — your Apple Developer Team ID (10-character string)
- **Bundle ID** — `de.piratenpartei.PIRATEN`

Store these as environment variables, **never in the repository**:
```
APNS_KEY_ID=XXXXXXXXXX
APNS_TEAM_ID=XXXXXXXXXX
APNS_BUNDLE_ID=de.piratenpartei.PIRATEN
APNS_KEY_PATH=/path/to/AuthKey_XXXXXXXXXX.p8  # or inline content
APNS_ENVIRONMENT=production  # or sandbox for development builds
```

### 3.2 Recommended gem

Use **`apnotic`** or **`rpush`** for APNs HTTP/2 delivery.

`apnotic` is lighter for simple use cases:
```ruby
# Gemfile
gem "apnotic"
```

Alternatively, `rpush` provides a full background queue with retries and database-backed delivery tracking — recommended for production reliability.

### 3.3 APNs endpoints

| Environment | Endpoint |
|-------------|----------|
| Production  | `https://api.push.apple.com` |
| Sandbox (dev builds) | `https://api.sandbox.push.apple.com` |

The iOS app uses **sandbox** for debug builds and **production** for release builds. The server should select the endpoint based on a configurable environment variable.

---

## 4. Notification Payload Format

### 4.1 Privacy requirements (mandatory)

- **NEVER** include message content, sender names, usernames, or any PII in the payload.
- Payloads transit through Apple's servers and may appear on the device lock screen.
- Only include a generic alert text and the minimal routing data needed to open the right screen.

### 4.2 Payload templates

**New private message:**
```json
{
  "aps": {
    "alert": {
      "title": "PIRATEN App",
      "body": "Du hast eine neue Nachricht"
    },
    "badge": 1,
    "sound": "default"
  },
  "deepLink": "message",
  "topicId": 12345
}
```

**New or updated todo:**
```json
{
  "aps": {
    "alert": {
      "title": "PIRATEN App",
      "body": "Ein ToDo wurde aktualisiert"
    },
    "badge": 1,
    "sound": "default"
  },
  "deepLink": "todo",
  "todoId": "abc-123"
}
```

**New forum post:**
```json
{
  "aps": {
    "alert": {
      "title": "PIRATEN App",
      "body": "Es gibt neue Beiträge im Forum"
    },
    "sound": "default"
  },
  "deepLink": "forum"
}
```

**New news item:**
```json
{
  "aps": {
    "alert": {
      "title": "PIRATEN App",
      "body": "Es gibt neue Neuigkeiten"
    },
    "sound": "default"
  },
  "deepLink": "forum"
}
```

> The `deepLink` values (`"message"`, `"todo"`, `"forum"`) are parsed by the iOS app's `DeepLinkRouter`. Do not change these strings.

---

## 5. Notification Triggers

Send a push notification to all matching `push_subscriptions` rows when:

| Event | Condition on subscription row | Notes |
|-------|-------------------------------|-------|
| New private message received by user X | `user_id = X` AND `messages_enabled = true` | Fire after the message is persisted |
| Todo created or updated, assignee is user X | `user_id = X` AND `todos_enabled = true` | Fire after the todo is saved |
| New forum topic or post (Discourse webhook) | `forum_enabled = true` (all users) | Send to all opted-in users |
| New news item published | `news_enabled = true` (all users) | Send to all opted-in users |

### Recommended implementation pattern

Use an ActiveJob background job to avoid blocking the request cycle:

```ruby
# After saving a message:
PushNotificationJob.perform_later(
  user_id: recipient.id,
  category: :message,
  payload: { deepLink: "message", topicId: message.topic_id }
)

# app/jobs/push_notification_job.rb
class PushNotificationJob < ApplicationJob
  queue_as :notifications

  def perform(user_id:, category:, payload:)
    subscriptions = PushSubscription.where(
      user_id: user_id,
      :"#{category}_enabled" => true
    )
    subscriptions.each do |sub|
      ApnsDeliveryService.send(token: sub.token, payload: payload)
    end
  end
end
```

---

## 6. Error Handling and Token Hygiene

Apple returns specific error codes that require action:

| APNs error | Meaning | Action |
|------------|---------|--------|
| `BadDeviceToken` | Token is malformed | Delete the subscription row |
| `Unregistered` | App uninstalled or token rotated | Delete the subscription row |
| `DeviceTokenNotForTopic` | Wrong bundle ID | Check `APNS_BUNDLE_ID` config |
| `ExpiredToken` | Token has expired | Delete the subscription row |
| `TooManyRequests` | Rate limited | Retry with exponential backoff |

Stale tokens must be removed promptly. Accumulating dead tokens wastes resources and may cause Apple to throttle your APNs certificate.

---

## 7. Discourse Webhook (for forum notifications)

The meine-piraten.de server does not host Discourse — it runs separately at `diskussion.piratenpartei.de`. To detect new forum posts, configure a Discourse webhook:

1. In Discourse admin → Plugins → Webhooks, create a new webhook pointing to:
   ```
   POST https://meine-piraten.de/api/webhooks/discourse
   ```
2. Subscribe to the `post_created` event.
3. On receipt, fan out push notifications to all subscriptions with `forum_enabled = true`.
4. Validate the webhook signature using Discourse's `Secret` field.

If a Discourse webhook is not feasible, the iOS app already polls for new forum content every 3 minutes and updates its badge in-app. Push notifications for forum posts are therefore a nice-to-have, not a blocker.

---

## 8. Security Checklist

- [ ] Auth header validated on all endpoints (401 if missing/invalid)
- [ ] Users can only register/delete their own tokens (enforce `user_id = current_user.id`)
- [ ] APNs key stored in environment variable, not in source code
- [ ] Notification payload contains no PII (see §4.1)
- [ ] Stale/invalid tokens cleaned up on APNs error response (see §6)
- [ ] Webhook endpoint validates Discourse signature before processing

---

## 9. What the iOS App Already Does (no server changes needed)

- Requests notification permission from the user
- Receives the APNs device token from Apple
- Calls `POST /api/push-subscriptions` when any toggle is enabled
- Calls `DELETE /api/push-subscriptions/:token` on logout or when all toggles are disabled
- Handles notification taps and routes to the correct screen
- Polls for new forum content every 3 minutes (in-app badge, independent of push)

The iOS app is ready. Once the server implements §2 and §3, push notifications will work end-to-end.

---

## 10. Handover Checklist

- [ ] `push_subscriptions` table created and migrated
- [ ] `POST /api/push-subscriptions` endpoint implemented and tested
- [ ] `DELETE /api/push-subscriptions/:token` endpoint implemented and tested
- [ ] APNs credentials configured in production environment variables
- [ ] APNs delivery service integrated (apnotic or rpush)
- [ ] Notification triggers hooked into message/todo save callbacks
- [ ] Stale token cleanup implemented
- [ ] (Optional) Discourse webhook configured for forum post events
- [x] iOS app's `AppContainer.swift` updated: replaced `FakePushNotificationRegistrationService` with `BackendPushNotificationRegistrationService` and confirmed endpoint path (`api/push_subscriptions`)
