# The Agent's server

The Agent's AI runs on WilList's own server, so no Anthropic key ships in the app.
The server doesn't exist yet: until `WLAgentServer` in `ios/WilList/Info.plist` holds its address, a release build shows Coming soon on the Agent tab.
This file is the contract between the app and that server; the app's side is `Agent.request` and `Agent.reply` in `ios/WilListCore/Sources/WilListCore/Agent.swift`, and `AgentPass` in `ios/WilList/AgentView.swift`.

## Where it runs

A Firebase Cloud Function (2nd generation), in the same Firebase project as sign-in, once the owner has created it.
Its secrets live in Secret Manager: the Anthropic API key, and the App Store Server API key (the `.p8` file, its key ID and the issuer ID from App Store Connect).
It needs a timeout of at least 300 seconds, as the app waits that long; the default 60 is too short.

## The request

The app sends `POST` to the `WLAgentServer` address, with:

- `authorization: Bearer <JWS>`: the App Store's signed transaction for the student's subscription (`jwsRepresentation` of the verified entitlement for `com.lull.willist.agent.monthly`, from StoreKit 2).
- `anthropic-version` and `anthropic-beta` headers, which the server passes on.
- `content-type: application/json`, and a Messages API body: `model`, `max_tokens`, `fallbacks`, `output_config`, `system`, `cache_control`, `tools` and `messages`.

Files and photos are inside `messages` as document and image blocks, so a body can be several megabytes.

## What the server does

1. **Checks the subscription.**
   It verifies the JWS: its certificate chain up to Apple Root CA - G3, its ES256 signature, `bundleId` `com.lull.willist` and `productId` `com.lull.willist.agent.monthly`.
   Then it asks the App Store Server API for the subscription's status by its `originalTransactionId` (Get All Subscription Statuses), because a refunded or lapsed subscription still carries a well-signed JWS.
   It may keep that answer for a few minutes per `originalTransactionId`.
   Apple's `app-store-server-library` does both steps.
2. **Limits each subscriber.**
   Per `originalTransactionId`: a few requests a minute and a daily ceiling, with headroom for a turn that calls tools several times (up to 6 rounds).
3. **Keeps the body to what the app sends.**
   It refuses any other top-level field, sets `model` to the one the app uses (`claude-opus-5-5`), and caps `max_tokens` at 16000, so the endpoint can't be used as a general Claude API.
   A later step can pin `system` and `tools` to the versions the app ships.
4. **Forwards it.**
   It adds `x-api-key` from its secret and posts the body to `https://api.anthropic.com/v1/messages` with the same `anthropic-version` and `anthropic-beta` headers.
5. **Returns Anthropic's answer as it is:** the same status and body.

It never stores or logs what the student sent or what came back: only the hashed `originalTransactionId`, the status, the time and the token counts, for limits and costs.

## Statuses the app understands

| Status | When | What the student sees |
|---|---|---|
| 200 | Anthropic answered | The answer |
| 401 | The JWS is missing, malformed or doesn't verify | "Your subscription isn’t active." and the paywall's Subscribe |
| 403 | The subscription has lapsed, been refunded or revoked | The same |
| 429 | The subscriber's limit, or Anthropic's | "Too many requests right now." (the app retries twice first) |
| 400, 413 | The body was refused; `error.message` says why | "That couldn’t be sent:" and that message, so write it in plain words for a student |
| 5xx | Anything else on the server's side | The app retries twice, then "The Agent ran into a problem" |

Errors use Anthropic's shape, so the app reads both the same way: `{"type": "error", "error": {"type": "...", "message": "..."}}`.

## Before it goes live

- The owner creates the Firebase project, the subscription and its group in App Store Connect, and the App Store Server API key.
- A privacy policy URL, listing Anthropic as the processor of what the student shares; App Store review needs it.
- `WLAgentServer` set in `Info.plist` for release builds.
- Tried end to end with a sandbox subscription: subscribe, ask, cancel, and see the paywall come back.
