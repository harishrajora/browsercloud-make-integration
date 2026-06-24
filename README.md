# TestMu AI Browser Cloud — Make App

A Make custom app that gives any **Make AI Agent** (powered by OpenAI, Claude, or Gemini) a real
cloud browser on **[TestMu AI Browser Cloud](https://www.testmuai.com/browser-cloud/)**. The agent
navigates, clicks, types, extracts text, and screenshots — all running on TestMu's W3C WebDriver
cloud, visible on the dashboard with video, console, and network capture.

> Sibling reference project: the verified n8n node `n8n-nodes-testmuai`. This app delivers the same
> capability for Make. The mechanics differ (see Architecture).

## Status

🟢 **Core implemented.** Connection, base, all 8 module request/response mappings, and the four
injected browser scripts are written and validated as well-formed JSON. Remaining before publishing:
add the app icon, link to a Make app and test live with an AI Agent, then submit for verification.

## Architecture (decided)

- **Vehicle:** one publishable Make custom app (declarative JSON + IML, HTTPS only — no SDK, no
  WebSocket, no Node). Backend is the same LambdaTest/TestMu WebDriver hub used by the n8n node.
- **Consumers:** Make AI Agents only; the LLM provider is swappable (OpenAI / Claude / Gemini all
  work, automatically — the app is model-agnostic). External LangChain/custom agents are out of
  scope (they use the `@testmuai/browser-cloud` SDK directly).
- **Session model:** stiff & deterministic. `sessionId` is a **required** input on every module
  except Open Session. Missing `sessionId` fails loudly (no silent session creation). The agent
  threads `sessionId` from Open Session into every later call; every module also returns it.
- **Element model:** `Snapshot` tags interactive elements with `data-ref="N"` and returns a numbered
  list; `Click`/`Type` target `[data-ref="N"]`. No stored state — the selector is a pure function of
  the ref number.
- **Action transport:** interactive actions run through a single `POST /execute/sync` whose injected
  JS does the work and returns a fresh snapshot in the same round-trip (one HTTP call per tool).

```
Make AI Agent (brain: OpenAI | Claude | Gemini)
   └─ tools ─► [Open Session][Navigate][Snapshot][Click][Type][Get Text][Screenshot][Release]
                              │ HTTPS (W3C WebDriver REST)
                              ▼
                  hub.lambdatest.com/wd/hub  (eu-hub for EU)
                              ▼
                  real cloud browser ─► TestMu dashboard (video/console/network)
```

## Repo layout

```
makecomapp.json                 # Make local-dev manifest (lists all components)
general/base.imljson            # shared base: hub-by-region URL, auth header, error handling
connections/browsercloud/       # Basic connection: username, accessKey, region (+ verify call)
modules/<name>/                 # 8 action modules, each: api / parameters / interface .imljson
scripts/*.js                    # browser-side scripts injected into execute/sync bodies
assets/                         # app icon (add icon.png)
```

## Modules (tool surface)

| Module | sessionId | Endpoint(s) | AI-filled inputs |
|---|---|---|---|
| Open Browser Session | — (creates) | `POST /session` | (browser/platform/version are user-set) |
| Navigate | required | `POST /url` → snapshot | sessionId, url |
| Snapshot Page | required | `execute/sync` | sessionId |
| Click Element | required | `execute/sync` | sessionId, ref |
| Type Text | required | `execute/sync` | sessionId, ref, text, pressEnter |
| Get Text | required | `execute/sync` | sessionId, ref?, (maxLength user-set) |
| Screenshot | required | `GET /screenshot` | sessionId |
| Release Session | required | `DELETE /session` | sessionId |

## Recommended Make AI Agent system prompt

```
You drive a real cloud browser via the TestMu AI Browser Cloud tools.
1. Call "Open Browser Session" first; keep the returned sessionId and pass it to every other tool.
2. click/type refer to elements by the ref number from the LATEST snapshot
   (every tool response includes a fresh snapshot — always use the newest).
3. Roles marked "(readonly)" — click them instead of typing.
4. Use "Get Text" to extract content.
5. When the goal is achieved, ALWAYS call "Release" as your final tool call.
Never reuse refs from earlier turns — refs are only valid against the latest snapshot.
```

## Build checklist

- [x] Implement `connections/browsercloud/api.imljson` verify call
- [x] Implement `general/base.imljson` error handling
- [x] Port `scripts/snapshot.js` from the n8n `SNAPSHOT_SCRIPT` (return `{elements, text}`)
- [x] Implement `scripts/click.js`, `scripts/type.js`, `scripts/getText.js`
- [x] Implement each `modules/*/api.imljson` (request + response mapping)
- [x] Fill `select` options (browser, platform, browserVersion)
- [x] Add `assets/icon.png`
- [x] Deploy to Make app (via `bash scripts/deploy.sh` — Make API, reproducible)
- [x] Treat `Release` of an already-gone session (404) as success
- [x] Validate modules in a manual scenario (Open → Navigate → Get Text → Release)
- [x] Hi-res 512×512 icon
- [x] Enriched tool + field descriptions for agent reliability
- [x] Screenshot also returns a binary file (`data`/`fileName`) alongside base64
- [x] Unique session names (Session Name input + timestamp)
- [x] Module samples for all 8 modules
- [x] Broaden `countries` (no restriction)
- [ ] Exact brand theme hex (currently #000000)
- [ ] v1.1: native-WebDriver action path for sites needing real input events
- [ ] Agent usage: submit for verification (module-tools) or build scenario-tools (interim)

## Deploying

```bash
bash scripts/deploy.sh        # pushes base + connection + all 8 modules + icon to Make
```
Reads the API token/zone from the Make Apps Editor's VS Code settings, or override with
`MAKE_API_KEY=… MAKE_ZONE=eu1 MAKE_APP=… bash scripts/deploy.sh`.

## Connecting this repo to Make

Authored for the **Make Apps VS Code extension** ("Local development for Apps"). After creating the
app in Make, link it from the extension to populate `origins` in `makecomapp.json`, then push/pull
components. Credentials and machine-local origin files are git-ignored.
