# The Agent's server

The Agent's AI runs through WilList's own server, so no provider's key ships in the app.
The server doesn't exist yet: until `WLAgentServer` in `ios/WilList/Info.plist` holds its address, a release build shows Coming soon on the Agent tab.
This file is the contract between the app and that server; the app's side is `Agent.request` and `Agent.reply` in `ios/WilListCore/Sources/WilListCore/Agent.swift`, and `AgentPass` in `ios/WilList/AgentView.swift`.

## Any provider, the same Agent

The app speaks the chat completions format (OpenAI's), which nearly every provider takes: DeepSeek, OpenRouter, OpenCode Zen, Groq, Together, Mistral, Moonshot, Qwen, Gemini's compatible endpoint, OpenAI and Anthropic's compatible endpoint among them.
The key decides whose model answers; the prompt, the tools, the loop and the cards stay the same (the owner, 2026-10-25: "the api key just provides the model, but the agent framework should be the same").
The app sends only text: photos and scanned pages are read on the phone (Apple's text recognition), PDFs give their text, Office files are unzipped, so a model that can't see pictures works too.
The model needs tool calling (functions); that is all it needs.

To change provider, change the server's three settings (below); the app doesn't change.

## The provider

The owner picked OpenCode on 2026-10-25.
Its pay-as-you-go service (the OpenCode Console, once Zen) serves chat completions at `https://opencode.ai/inference/openai/v1` with a key from the console, for models such as DeepSeek V4.1 Flash (`deepseek-v4.1-flash`, $0.30 / $1.20 per million tokens in and out), GLM 5.3 Flash (`glm-5.3-flash`, $0.15 / $0.50), MiniMax M3, Kimi K2.6 and Mistral Large 4; its own other models answer only in other formats (Responses, Messages, Gemini), and its free models only inside OpenCode itself.
It says those paid models keep nothing and don't train on what is sent.
**But its terms don't let it serve students:** "You will only use the Services for your own internal use, and not on behalf of or for the benefit of any third party" (opencode.ai/legal/terms-of-service, read 2026-10-25); OpenCode Go, the subscription, is also "designed for OpenCode and other coding agents" and for a single person.
So OpenCode is for the owner's own testing (debug builds default to it, with `deepseek-v4.1-flash`), and the shipped Agent needs either OpenCode's written OK (help@anoma.ly) or a provider whose terms allow serving an app's users, perhaps DeepSeek's own API (`https://api.deepseek.com`) for the same model; its terms haven't been read yet.

## Where it runs

A Firebase Cloud Function (2nd generation), in the same Firebase project as sign-in, once the owner has created it.
Its settings live in Secret Manager: the provider's chat completions address (such as `https://api.deepseek.com`), its API key and the model's name; and the App Store Server API key (the `.p8` file, its key ID and the issuer ID from App Store Connect).
It needs a timeout of at least 300 seconds, as the app waits that long; the default 60 is too short.

## The request

The app sends `POST` to the `WLAgentServer` address followed by `/chat/completions`, so the server is itself a chat completions address, with:

- `authorization: Bearer <JWS>`: the App Store's signed transaction for the student's subscription (`jwsRepresentation` of the verified entitlement for `com.lull.willist.agent.monthly`, from StoreKit 2).
- `content-type: application/json`, and a body with only `messages` (the system prompt first) and `tools`, and no `model`.

Files arrive as text inside `messages`, so a body is rarely more than a few hundred kilobytes.

## What the server does

1. **Checks the subscription.**
   It verifies the JWS: its certificate chain up to Apple Root CA - G3, its ES256 signature, `bundleId` `com.lull.willist` and `productId` `com.lull.willist.agent.monthly`.
   Then it asks the App Store Server API for the subscription's status by its `originalTransactionId` (Get All Subscription Statuses), because a refunded or lapsed subscription still carries a well-signed JWS.
   It may keep that answer for a few minutes per `originalTransactionId`.
   Apple's `app-store-server-library` does both steps.
2. **Limits each subscriber.**
   Per `originalTransactionId`: a few requests a minute and a daily ceiling, with headroom for a turn that calls tools several times (up to 6 rounds).
3. **Keeps the body to what the app sends.**
   It refuses any other top-level field and any message content that isn't text, sets `model` to its own, and may add a cap on the answer's length that its provider takes (`max_tokens` for most, `max_completion_tokens` for OpenAI's reasoning models), so the endpoint can't be used as a general AI API.
   A later step can pin the system prompt and `tools` to the versions the app ships.
4. **Forwards it.**
   It sends `authorization: Bearer <the provider's key>` and posts the body to the provider's address followed by `/chat/completions`.
5. **Returns the provider's answer as it is:** the same status and body.

It never stores or logs what the student sent or what came back: only the hashed `originalTransactionId`, the status, the time and the token counts, for limits and costs.

## Statuses the app understands

| Status | When | What the student sees |
|---|---|---|
| 200 | The provider answered | The answer |
| 401, 402 | The JWS is missing, malformed or doesn't verify | "Your subscription isn’t active." and the paywall's Subscribe |
| 403 | The subscription has lapsed, been refunded or revoked | The same |
| 429 | The subscriber's limit, or the provider's | "Too many requests right now." (the app retries twice first) |
| 400, 413, 422 | The body was refused; `error.message` says why | "That couldn’t be sent:" and that message, so write it in plain words for a student |
| 5xx | Anything else on the server's side | The app retries twice, then "The Agent ran into a problem" |

Errors use the chat completions shape, which is what providers send too, so the app reads both the same way: `{"error": {"message": "...", "type": "..."}}`.
A provider's own 401 or 402 (a wrong key, an empty balance) must not reach the app as such, or the student is told to subscribe: the server answers 502 instead and alerts the owner.

## Before it goes live

- The owner picks the provider and model, and creates the Firebase project, the subscription and its group in App Store Connect, and the App Store Server API key.
- A privacy policy URL, naming the provider as the processor of what the student shares; App Store review needs it (guideline 5.1.2(i) asks apps to say which AI service gets personal data). The Agent's ask before the first message says "an AI model" until the provider is chosen; name it there too then.
- `WLAgentServer` set in `Info.plist` for release builds.
- Tried end to end with a sandbox subscription: subscribe, ask, cancel, and see the paywall come back.

## Trying a provider from a debug build

Debug builds can skip the server: put `AGENT_KEY` in the scheme's environment (Product, Scheme, Edit Scheme, Run, Arguments), an OpenCode key by default, with `deepseek-v4.1-flash`.
For another provider or model, add `AGENT_URL` (its chat completions address, such as `https://api.deepseek.com`) and `AGENT_MODEL`.
Environment variables only reach the app when Xcode launches it, not from the Home Screen.
