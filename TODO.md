# TIAGA Mobile — Build Plan

Working checklist for building the MVP. See `AGENTS.md` for domain context and
architecture rules — this file is the ordered task list, that file is the why.

## Process (read before starting any section)

- [ ] One feature section = one branch, named `feature/<slug>` as given under each heading.
- [ ] Never commit directly to `main` — not app code, not docs. Every change lands on its own branch.
- [ ] Build a section fully (including its tests), then push the branch and open a PR for review before starting the next section. Do not start the next branch off an unmerged one.
- [ ] Never push `main`, and never merge a PR yourself — pushing a feature/docs branch to open a PR is fine; landing it on `main` is the user's call.
- [ ] Commit messages follow Conventional Commits (`feat:`, `fix:`, `test:`, `docs:`).
- [ ] Every domain model gets a DocC comment: what real-world entity/event it is, and the business rule(s) that govern it.
- [ ] Every Use Case gets a typed domain error enum whose messages are written for the operator, not a developer — no "something went wrong".
- [ ] Order below is dependency order (each section only needs what already landed) — do not reorder without checking what a later section assumes exists.
- [ ] Before opening any PR touching UI: boot a simulator, build, install, launch, and screenshot each new/changed screen (`xcrun simctl io booted screenshot`) and actually look at it — see AGENTS.md's Testing section for the exact commands. Then still include a manual visual-confirmation checklist in the test plan for whatever that static screenshot pass can't cover (interactive multi-step flows, final polish) — the user runs those, Claude doesn't.
- [ ] Every repository defaults to `Fake*Repository` in Xcode Previews and `Remote*Repository` everywhere else (Simulator, device) — see AGENTS.md's live-backend policy before building any repository implementation. TIAGA can dispatch real agents onto real machines, so once a feature area is wired live, manually exploring it on Simulator/device sends real chat messages, real approvals, real kills against a real account — be deliberate. (See the "Live Backend Wiring" section below for which `Remote*Repository` implementations actually exist.)
- [ ] Screenshot every screen a PR adds or changes (not just the launch screen — use a DEBUG route override per screen), commit them to `docs/screenshots/`, and embed them in the PR body as a grid (HTML table, width-capped `<img>`s) — see AGENTS.md's Testing section for the exact URL form (this repo is private) and the before/after pattern for a PR that changes an existing screen's UI.
- [ ] The moment the user says something merged: `git checkout main && git pull`, delete that branch locally (`git branch -d`), `git fetch --prune` — without being asked.

---

## 1. Design System — `feature/design-system` ✅

Foundation every later screen consumes. Built from scratch on the bare
project scaffold: `TIAGAColor`, `TIAGASpacing`, `TIAGARadius`, `TIAGATypography`,
the `Colors.xcassets` set, and the `AgentState`/`PermissionRequestUrgency`
domain models the color mappings need.

**Revision:** the first pass wrongly grounded colors in `web-v2/`'s flat
canvas/ink/accent palette. Corrected to `web/` (v1) — the actual shipping
"glass" aesthetic (dark-only, translucent blurred panels, Tailwind's default
palette, blue-500 accent). See CLAUDE.md's Design System section.

- [x] `TIAGAIcon` — SF Symbol tokens for: device types (macOS/Windows/Linux),
      agent state, tool-usage kinds, side menu entries (chat/devices/settings).
- [x] `TIAGAColor.forContextUsage(percentage:)` — green → amber → red, amber at
      75% (mirrors the real product's compaction threshold), red at 100%.
      This is the color source for the Chat context bar.
- [x] Reusable component primitives (`Presentation/Components/`):
  - [x] `TIAGACard` — surface container (background, radius, padding from tokens)
  - [x] `StatusPill` — label + dot, color driven by an `AgentState` or presence bool, never a raw color
  - [x] `MessageBubble` — user / orchestrator-or-agent / tool-usage row styles
  - [x] `ContextUsageBar` — horizontal bar bound to a 0–1 fraction, colored via `forContextUsage`
  - [x] `ChatComposerBar` — the shared text-input-and-send control used by both Chat and Agent Chat (no mic button — voice is explicitly out of scope)
- [x] Unit tests (`TIAGATests/DesignSystemTests.swift`):
  - [x] `test_forContextUsage_returnsSuccessColor_belowSeventyFivePercent`
  - [x] `test_forContextUsage_returnsWarningColor_atSeventyFivePercentBoundary`
  - [x] `test_forContextUsage_returnsDangerColor_atOneHundredPercent`
  - [x] `test_forAgentState_mapsCompactingToCompactingColor` (extend existing mapping tests if not already covered)

---

## 2. API Layer — `feature/api-layer` ✅

Shared networking/transport only — **no feature-specific endpoints or DTOs
here**; those are added inside each feature's own `Data/Repositories`
implementation so this branch stays generic and every later branch has
something concrete to build on.

Grounded directly in `tiaga-nexus/web/src/lib/api.ts` and `backend/`:
production origin `https://tiaga.tech/api` (same-origin behind a reverse
proxy), JSON bodies are camelCase (ASP.NET Core default — no snake_case
conversion needed), error responses are `{ "error": "..." }`, and the live
stream is Server-Sent Events at `GET /api/events` (not WebSocket — that's
harness-only).

**Status note (added after this section landed):** every section through
Section 6 built only a `Fake*Repository`, never a `Remote*Repository` — a
deliberate decision at the time (see CLAUDE.md's testing-safety policy as it
stood then). **That policy has since changed** (after Section 6): `Fake*Repository`
is now Xcode-Previews-only, and the running app (Simulator/device) should
use `Remote*Repository` — see CLAUDE.md's current live-backend policy.
`TIAGAAPIClient`/`TIAGAEventStream`/`SessionCookieStore` built here are
exactly the transport layer every `Remote*Repository` needs; building the
actual `Remote*Repository` per feature area is separate, not-yet-started
work — check each section below for whether its `Remote*Repository` has
landed before assuming a screen is live (none has, as of this writing).

- [x] `Data/API/TIAGAAPIClient.swift` — base HTTP client (base URL, request
      building, JSON decoding, response/status handling). Built against an
      injectable `URLDataSession` protocol (not concrete `URLSession`) so it's
      testable without touching the network.
- [x] `Data/API/TIAGAEventStream.swift` — SSE wrapper for live updates
      (device presence, agent state, streaming chat tokens) using
      `URLSession.bytes(for:)` to parse `event:`/`data:` frames.
- [x] `Data/API/SessionCookieStore.swift` — the real backend authenticates
      with a long, sliding **session cookie** (not a bearer token the client
      manages) — `URLSession`'s shared `HTTPCookieStorage` handles attaching
      it automatically; this type just checks presence and clears it on
      logout. No login screen lives in this branch; the actual login/waitlist
      flow is Section 3.
- [x] `Domain/Errors/APITransportError.swift` — infra-level failure states
      (`unreachable`, `unauthorized`, `decodingFailed`, `serverError(status:message:)`)
      that feature repositories translate into their own domain error cases —
      Views and ViewModels never see this type directly.
- [x] Unit tests (`TIAGATests/APIClientTests.swift`), using a mock `URLDataSession`:
  - [x] `test_apiClient_decodesSuccessfulResponse`
  - [x] `test_apiClient_mapsUnauthorizedStatusToTransportError`
  - [x] `test_apiClient_mapsUnreachableHostToTransportError`

---

## 3. Auth (Login + Waitlist Gate) — `feature/auth` ✅

Gates every other screen. TIAGA is in private beta — signing in successfully
doesn't mean access; a `waitlisted` account must be shown the waitlist gate
instead of the fleet console until it's activated. Mirrors the web client's
`useAuth`/`authMe`/`authLogin`/`WaitlistScreen` behavior — see
`AuthService.cs` and `web/src/hooks/useAuth.ts` / `web/src/components/WaitlistScreen.tsx`
in the parent repo before naming anything here.

- [x] `Domain/Models/Account.swift` — email, `AccountStatus`, roles. DocC:
      real-world entity = a signed-in TIAGA user; rule = authentication
      succeeding does not imply product access. Also adds `AccountRole`
      (`.admin`/`.developer`, additive set) — not surfaced anywhere yet.
- [x] `Domain/Models/AccountStatus.swift` — `.waitlisted`, `.active` (exact
      values the real backend uses — do not add states it doesn't have).
- [x] `Domain/Repositories/AuthSessionRepository.swift` (protocol) —
      `restoreSession()`, `login(email:password:)`, `redeemInviteCode(_:)`, `logout()`.
- [x] `Data/Repositories/FakeAuthSessionRepository.swift` — fixture-backed,
      no network calls. Fixture accounts covering both routing branches and
      the error paths below: one `.active`, one `.waitlisted`, plus a
      wrong-password case and a rate-limited case. Built under the original
      fake-everywhere policy — see CLAUDE.md's current live-backend policy;
      `RemoteAuthSessionRepository` (for Simulator/device) doesn't exist yet.
- [x] `UseCases/RestoreSessionUseCase.swift` — checks for a valid existing
      session on launch so a returning active user skips straight to the app.
  - [x] Typed error: `SessionRestoreError.connectionUnavailable`
- [x] `UseCases/LoginUseCase.swift`
  - [x] Business rule: email must be a plausible address, password non-empty
  - [x] Typed error: `LoginError` (`.invalidCredentials`, `.tooManyAttempts`, `.connectionUnavailable`)
- [x] `UseCases/RedeemInviteCodeUseCase.swift`
  - [x] Business rule: only meaningful for a `.waitlisted` account — redeeming
        against an already-`.active` account is rejected rather than silently ignored
  - [x] Typed error: `InviteCodeError` (`.codeInvalid`, `.accountAlreadyActive`)
- [x] `UseCases/LogoutUseCase.swift` — business rule: always clears the local
      session even if the remote invalidation call fails; a user must never
      be stuck "logged in" locally by a network error. No typed error — it
      cannot meaningfully fail from the operator's side. (UI trigger for this
      lives in Settings, Section 9 — defined here because it's session logic.)
- [x] `Presentation/ViewModels/AuthViewModel.swift` — drives launch routing
      (`Route`: `.checkingSession`/`.login`/`.waitlistGate`/`.authenticated`).
- [x] `Presentation/Views/Auth/LoginView.swift` — email + password, submit,
      inline error text. **Login only — no sign-up screen** (accounts are
      created on the web today; confirm if that should change).
- [x] `LoginView` DEBUG-only "fill fixture credentials" affordance (one tap
      each for the `.active` and `.waitlisted` fixture accounts) so exercising
      both routing branches is convenient without typing anything.
- [x] `Presentation/Views/Auth/WaitlistGateView.swift` — "you're on the
      waiting list" message + invite code field. **Assumption resolved as
      planned:** message + code redemption only, no beta-application form —
      flag if that should change.
- [x] `ContentView.swift` repurposed as the routing root (switches on
      `AuthViewModel.route`), plus a temporary `AuthenticatedPlaceholderView`
      (welcome text + Log Out) so the auth loop is fully closeable for manual
      testing until Section 4 replaces it with the real fleet-console shell.
- [x] Unit tests (`TIAGATests/LoginUseCaseTests.swift`,
      `RestoreSessionUseCaseTests.swift`, `RedeemInviteCodeUseCaseTests.swift`,
      `LogoutUseCaseTests.swift`) — 11 total, 3 beyond the listed minimum
      (malformed-email, restore-session-connectivity-failure, and the
      logout-resilience rule each got their own test):
  - [x] `test_login_succeeds_withValidCredentials`
  - [x] `test_login_fails_withInvalidCredentials`
  - [x] `test_login_fails_whenRateLimited`
  - [x] `test_restoreSession_returnsActiveAccount_whenSessionIsValid`
  - [x] `test_restoreSession_returnsUnauthenticated_whenNoSessionExists`
  - [x] `test_redeemInviteCode_activatesWaitlistedAccount_whenCodeIsValid`
  - [x] `test_redeemInviteCode_fails_whenCodeIsInvalid`
  - [x] `test_redeemInviteCode_fails_whenAccountIsAlreadyActive`

---

## 4. Side Menu — `feature/side-menu` ✅

Navigation shell for an authenticated, `.active` account (reached only after
Section 3 routes here). Introduces the `Agent` domain model (previously only
`AgentState` existed).

- [x] `Domain/Models/Agent.swift` — `AgentIdentifier`, display name, `AgentState`,
      pinned `DeviceIdentifier`, last-activity summary, context-usage fraction.
      DocC: real-world entity = a persistent named agent; rule = it is always
      pinned to exactly one device from spawn. Also adds `Domain/Models/DeviceIdentifier.swift`
      (ahead of the full `Device` model, Section 7 — `Agent` needs to reference
      its pinned device now).
- [x] `Domain/Models/AppRoute.swift` — navigation destinations: `.chat`,
      `.agentChat(AgentIdentifier)`, `.devices`, `.settings`.
- [x] `Domain/Repositories/AgentRosterRepository.swift` (protocol) — list/observe
      the operator's agents.
- [x] `Data/Repositories/FakeAgentRosterRepository.swift` — fixture-backed
      roster (a few agents spanning every `AgentState`), no network calls.
- [x] `UseCases/ListAgentRosterUseCase.swift` — business rule: running/compacting
      agents sort before idle, idle before error, ties broken by most-recent
      activity — an operator scanning the menu should see what needs attention first.
  - [x] Typed error: `AgentRosterError` (`.fleetUnreachable`)
- [x] `Presentation/ViewModels/SideMenuViewModel.swift`
- [x] `Presentation/Views/SideMenuView.swift` — replaces the current stub.
      Rows: "Chat" (fixed, always first), agent list (name + `StatusPill`),
      "Devices", "Settings".
- [x] `Presentation/Views/FleetConsoleRootView.swift` — a hamburger-triggered
      slide-out drawer (not `NavigationSplitView` — that read as a column
      nav with a back-arrow, no explicit close, no swipe-to-dismiss, none of
      which is what "side menu" means here) wiring the menu to a detail
      pane, routing to placeholder screens for Chat/Devices/Settings/Agent
      Chat until their branches land. Settings' placeholder carries Log Out
      (its real future home). `ContentView`'s `.authenticated` case now
      routes here instead of the old temporary placeholder from Section 3.
      The drawer is a native Liquid Glass overlay (see CLAUDE.md's Design
      System section for the lessons from getting this wrong on the first
      few passes): hamburger toggle, tap-scrim-to-close, drag-to-dismiss,
      an explicit glass close button, `.buttonStyle(.glassProminent)` for
      the selected row, a shared `SideMenuRow` component so agents and
      Chat/Devices/Settings look identical, and a plain (not glass)
      panel background so the individual glass buttons render correctly
      instead of merging into one flat surface.
- [x] DEBUG route-override pattern extended to this ViewModel too
      (`TIAGA_DEBUG_SELECTED_ROUTE`, plus a `"sideMenu"` value to land on the
      drawer itself), per CLAUDE.md's screenshot-tooling policy.
- [x] Unit tests (`TIAGATests/ListAgentRosterUseCaseTests.swift`):
  - [x] `test_listAgentRoster_ordersRunningAgentsBeforeIdle`
  - [x] `test_listAgentRoster_ordersErrorAgentsAfterIdle`
  - [x] `test_listAgentRoster_breaksTiesByMostRecentActivity`
  - [x] `test_listAgentRoster_fails_whenFleetIsUnreachable`

**Post-merge fix (`fix/side-menu-swipe-gestures`, PR #12):** the swipe-to-open
drag being a `.simultaneousGesture` meant Chat's own `ScrollView` scrolled on
whatever small vertical component a real swipe has, alongside opening the
drawer — fixed with an `isSideMenuOpenGestureActive` environment value that
disables scrolling in the active route for the drag's duration. Reversing
direction fast mid-swipe could also leave the drawer stuck at a partial
offset — `onEnded` was re-checking the same horizontal-dominance ratio used
to *start* the drag against the gesture's *final* translation, which a fast
reversal could fail; fixed by tracking "did this drag ever commit to
opening" instead, so release always resolves to fully open or fully closed.

---

## 5. Chat (main orchestrator chat) — `feature/chat` ✅

The "Chat" entry from the side menu — conversation with the orchestrator.
Voice is explicitly out of scope: no mic input, no spoken output, text only.

**Revision:** `DynamicUICardKind` shipped as `.text`/`.code`/`.table`/`.diagram`,
not the originally planned `.error` — checked against the real backend's
`DynamicUiManager.cs` mid-build and corrected to match (`fix(chat): match
dynamic UI card kinds to backend`). Card rendering also grew beyond plain
design-token boxes: `.diagram` renders its Mermaid source as dark-themed SVG
(vendored mermaid.js), `.code` gets vendored highlight.js + github-dark
syntax highlighting with copy, `.table` is a native `Grid`, and every card
has an expand-to-fullscreen sheet — all mirroring the web client's card
behavior, all rendered client-side from vendored JS/CSS (`TIAGA/Resources/`,
never fetched at runtime) rather than trusting arbitrary backend HTML/CSS.
Also added: a destructive/cancel confirmation dialog before reset, and a
close button per dynamic UI card.

**Post-merge fixes (PR #11 review, PR #12):** a translucent HTML background
in code cards compositing lighter than the surrounding card; the Mermaid
`#stage` div collapsing to zero height (`html`/`body` never got an explicit
height, so its `height: 100%` resolved to nothing); the hand-rolled table
`HStack` clipping a wrapped cell's second line instead of growing the row
(replaced with `Grid`); the same `Grid`'s header background not filling its
full column width; diagram pan/pinch-zoom never working via touch
(`event.movementX`/`movementY` isn't reliably populated for touch-originated
Pointer Events in WKWebView, and pinch was wheel-event-only); panning down
in the fullscreen diagram triggering the sheet's own swipe-to-dismiss. See
git history on `main` for the individual fix commits.

**Revision (`feature/message-kind-unification`, after Section 6 merged):**
`ToolUsageEvent` (a domain type of its own) and `TranscriptEntry`/
`TranscriptMerger` (a wrapper enum + merge function over two separate arrays)
were a simplification that turned out not to match the real backend/web
contract. Checked `tiaga-nexus/web/src/types.ts` + `MessageList.tsx` +
`AgentChatWindow.tsx` directly: the real `Message` type is `{ role, kind?,
text }` — tool usage and errors are the *same* message type as a normal
reply, just with `kind: 'tool'` / `kind: 'error'` instead of `'voice'` (plus
`'context'`/`'task'`/`'ui'`). There is no separate tool-usage domain type on
the real product at all. Retired `ToolUsageEvent` and `TranscriptEntry`/
`TranscriptMerger` entirely; `ChatMessage` now carries a `kind:
ChatMessageKind` field (`.voice`/`.tool`/`.context`/`.task`/`.ui`/`.error`),
and both conversation repositories return `[ChatMessage]` directly — no
merging needed since there's only one array now. `TranscriptRow` initially
labeled each kind with a colored dot for Chat specifically (matching
`MessageList.tsx`'s richer `KIND_STYLES`), while Agent Chat kept its
existing plain style (matching `AgentChatWindow.tsx`, whose simpler
`role`-only wire format has no separate kind at all — tool/error are just
additional `role` values there) — that per-screen difference was reverted
per feedback, and both screens now render identically with the original
plain style (no labels, `.tool` as a dim monospace line, `.error` as an
unlabeled red bordered bubble). `ChatMessage.kind` itself stays — it's still
what picks the bubble style — only the extra label UI is gone. This also
fixed the original ask that prompted the discovery: an agent's `.error`
state now shows as an error-kind message in its own transcript (matching
the web), not just a status pill — and the orchestrator's own conversation
can carry an error message too, not only an agent's. `.context`/`.task`/
`.ui` are modeled but not yet exercised by any fixture. Removed
`TranscriptMergerTests.swift` (the function it tested no longer exists —
sorting one array by `sentAt` is a one-liner, not separately unit-tested).

- [x] `Domain/Models/ChatMessage.swift` — id, role (`.operator` / `.orchestrator`),
      text, sentAt.
- [x] `Domain/Models/ToolUsageEvent.swift` — tool name, target device (optional),
      human-readable summary, occurredAt. DocC: represents a tool call the
      orchestrator or an agent made, shown inline in the transcript.
- [x] `Domain/Models/DynamicUICard.swift` + `DynamicUICardKind` (`.text`, `.code`,
      `.table`, `.diagram`) — mirrors the real product's AI-composed UI cards.
- [x] `Domain/Models/ConversationContextUsage.swift` — fraction used + derived
      level (`.normal` / `.high` / `.critical`) at the 75%/100% thresholds.
- [x] `Domain/Repositories/OrchestratorConversationRepository.swift` (protocol) —
      send a message, observe the live transcript (messages + tool usage,
      merged in chronological order), observe context usage, reset the
      conversation, fetch dynamic UI card history.
- [x] `Data/Repositories/FakeOrchestratorConversationRepository.swift` —
      fixture-backed: canned replies (with an artificial short delay to
      exercise the "busy" state honestly) and a scripted context-usage ramp
      so the 75%/100% color thresholds are actually reachable in testing. No
      real LLM, no network — built under the original fake-everywhere policy,
      see CLAUDE.md's current live-backend policy.
- [x] `UseCases/SendChatMessageUseCase.swift` — reusable for both this feature
      and Agent Chat (takes a `ConversationTarget`: `.orchestrator` or
      `.agent(AgentIdentifier)`).
  - [x] Business rule: message text cannot be empty/whitespace-only
  - [x] Business rule: cannot send while the target is still streaming a reply
  - [x] Typed error: `SendChatMessageError` (`.messageIsEmpty`, `.conversationBusy`)
- [x] `UseCases/ResetConversationUseCase.swift`
  - [x] Business rule: cannot reset while a response is actively streaming (data-loss risk mid-stream)
  - [x] Typed error: `ResetConversationError` (`.conversationBusy`)
- [x] `UseCases/LoadDynamicUICardHistoryUseCase.swift` — backs the "browse
      dynamic UI" button.
  - [x] Typed error: `DynamicUICardHistoryError` (`.unavailable`)
- [x] `Presentation/ViewModels/ChatViewModel.swift`
- [x] `Presentation/Views/Chat/ChatView.swift` — transcript (messages + tool
      usage interleaved), `ChatComposerBar`, reset button, `ContextUsageBar`,
      dynamic-UI-browser entry point.
- [x] `Presentation/Views/Chat/DynamicUICardBrowserView.swift`
- [x] Unit tests (`TIAGATests/SendChatMessageUseCaseTests.swift`,
      `ResetConversationUseCaseTests.swift`):
  - [x] `test_sendChatMessage_succeeds_withNonEmptyText`
  - [x] `test_sendChatMessage_fails_whenTextIsEmpty`
  - [x] `test_sendChatMessage_fails_whenConversationIsAlreadyStreaming`
  - [x] `test_resetConversation_succeeds_whenConversationIsIdle`
  - [x] `test_resetConversation_fails_whileConversationIsStreaming`
  - [x] `test_transcriptMerge_ordersMessagesAndToolUsageChronologically` (pure-function test on the merge logic backing the transcript list)

---

## 6. Agent Chat — `feature/agent-chat` ✅

Per-agent conversation. Reuses `ChatMessage`, `ToolUsageEvent`,
`SendChatMessageUseCase`, and `ChatComposerBar`/`MessageBubble` from Chat —
do not duplicate them.

**Revision:** `SendChatMessageUseCase` already took a `ConversationTarget`,
but `OrchestratorConversationRepository` could only ever represent one
conversation — and `AgentState.compacting`'s business rule ("cannot accept a
new instruction") is agent-state-driven, not a generic streaming flag. Added
a separate `Domain/Repositories/AgentConversationRepository.swift` +
`FakeAgentConversationRepository` for per-agent transcript storage, and made
`SendChatMessageUseCase` branch on target: orchestrator sends still gate on
`isStreaming` exactly as before (no change to Section 5's behavior); agent
sends gate on that agent's own `.compacting` state via a fresh
`AgentRosterRepository` lookup. Also promoted `ChatView`'s private
`TranscriptRow` to a shared `Presentation/Components/` view (matching
`MessageBubble`/`ChatComposerBar`) so Agent Chat renders its transcript
without duplicating it.

**Post-review fixes (same PR):** two bugs found after the first pass —
(1) switching directly from one agent's chat to another's didn't work
(`AgentChatView` had no explicit `.id(agentID)`, so SwiftUI reused the
existing view — and its `@StateObject` — instead of treating the new agent
as a fresh identity); (2) deleting an agent didn't remove it from the side
menu, because `AgentChatViewModel` and `SideMenuViewModel` each defaulted to
their own separate `FakeAgentRosterRepository()` instance, so a delete
mutated state the menu's roster never saw. Fixed by having
`FleetConsoleRootView` own one shared `AgentRosterRepository` +
`AgentConversationRepository` instance and inject the same ones everywhere,
plus an `onRosterChanged` callback that reloads the side menu after a
cancel or delete.

- [x] `Domain/Repositories/AgentRosterRepository.swift` — extend with
      `cancelActiveTask(for:)` and `delete(_:)`, and an observe-single-agent method.
- [x] `UseCases/CancelAgentTaskUseCase.swift`
  - [x] Business rule: only valid while the agent is `.running` — a
        `.compacting` agent has an active operation too, but per
        `AgentState.compacting`'s own business rule it's a self-contained
        transition that must finish on its own, not something the operator
        can interrupt (corrected after first shipping "running or
        compacting" — no stop button should ever appear while compacting)
  - [x] Typed error: `AgentLifecycleError.noActiveTaskToCancel` (idle/error),
        `.cannotInterruptCompaction` (compacting)
- [x] `UseCases/DeleteAgentUseCase.swift`
  - [x] Business rule: deleting is allowed regardless of state (matches the
        real product — in-flight tool calls are closed cleanly), but a
        second delete of an already-gone agent must fail cleanly
  - [x] Typed error: `AgentLifecycleError.agentNoLongerExists`
- [x] `Presentation/ViewModels/AgentChatViewModel.swift`
- [x] `Presentation/Views/AgentChat/AgentChatView.swift` — composer, transcript,
      delete button, stop/cancel button shown only when state is `.running`
      or `.compacting`.
- [x] Unit tests (`TIAGATests/CancelAgentTaskUseCaseTests.swift`,
      `DeleteAgentUseCaseTests.swift`):
  - [x] `test_cancelAgentTask_succeeds_whenAgentIsRunning`
  - [x] `test_cancelAgentTask_fails_whenAgentIsIdle`
  - [x] `test_deleteAgent_succeeds_whenAgentExists`
  - [x] `test_deleteAgent_fails_whenAgentAlreadyDeleted`
  - [x] `test_sendChatMessage_fails_whenTargetAgentIsCompacting` (extends the shared use case's coverage for the agent-target case)

---

## 7. Devices — `feature/devices` ✅

**Revision:** the note added while building Section 6 ("each device's row
should show which agent(s) are pinned to it") was never actually checked
against the real product and turned out to be wrong — read `DevicesPane.tsx`
directly while building this section: it has no mention of "agent"
anywhere. Retracted; `DevicesView` shows only device data.

Two more corrections from the same pass of checking `DevicesPane.tsx` +
`DeviceManager.cs` directly before building, instead of only against this
plan:
- **No `lastSeenAt`/staleness derivation exists on the real product at
  all**, client or server. `DeviceManager.cs`'s `Online` flag is a plain
  boolean flipped on connect/disconnect (`d.Online = true` / `= false`) —
  there's no timestamp-based heuristic to replicate. Dropped
  `DevicePresence.swift` and the staleness business rule entirely;
  `Device.isOnline` is a plain trusted boolean, matching the real wire
  shape exactly.
- **The real field is `permissionsRequired: boolean`** (backend:
  `PermissionsRequired`, defaults `true`), not the invented `isProtected` —
  renamed to match. And on the real product this isn't a future-section
  read-only flag: `DeviceRow` in `DevicesPane.tsx` already renders a live,
  tappable pill for it ("permissions on"/"auto"). Pulled that forward into
  this section instead of deferring to Section 8 as originally planned —
  `ToggleDevicePermissionsUseCase` (renamed from the planned
  `ToggleDeviceProtectionUseCase`) and the interactive pill both exist now.
  Displayed here as "Permissions: On"/"Off" rather than web's "on"/"auto"
  wording. Section 8 still adds its own business rule on top (can't disable
  while a device has unresolved pending permission requests) once
  `PermissionRequest` exists.

- [x] `Domain/Models/Device.swift` — `DeviceIdentifier`, display name,
      `DeviceType` (`.mac`/`.windows`/`.linux`, raw values matching the
      backend's lowercase wire values), `isOnline`, `permissionsRequired`.
- [x] `Domain/Repositories/DeviceFleetRepository.swift` (protocol) +
      `Data/Repositories/FakeDeviceFleetRepository.swift` — fixture devices
      spanning online/offline and permissions on/off, plus an injectable
      failure mode for `fleetUnreachable`. No network. Mutable (a
      continuation-free in-memory dictionary, since nothing observes it
      live yet) to support the permissions toggle.
- [x] `UseCases/ObserveDeviceFleetUseCase.swift`
  - [x] Business rule: sort online devices before offline, then alphabetically
  - [x] Typed error: `DeviceFleetError.fleetUnreachable`
- [x] `UseCases/ToggleDevicePermissionsUseCase.swift` (pulled forward from
      Section 8 — see Revision above)
  - [x] Typed error: `DevicePermissionsError.deviceNoLongerExists`
- [x] `Presentation/ViewModels/DevicesViewModel.swift`
- [x] `Presentation/Views/Devices/DevicesView.swift` — row per device: name,
      `TIAGAIcon` for OS, `StatusPill` for online/offline, and a tappable
      "Permissions: On"/"Off" pill.
- [x] Unit tests (`TIAGATests/ObserveDeviceFleetUseCaseTests.swift`,
      `ToggleDevicePermissionsUseCaseTests.swift`):
  - [x] `test_observeDeviceFleet_sortsOnlineBeforeOffline`
  - [x] `test_observeDeviceFleet_breaksTiesAlphabetically` (boundary: same online status, falls through to the alphabetical tiebreak)
  - [x] `test_observeDeviceFleet_fails_whenFleetIsUnreachable`
  - [x] `test_toggleDevicePermissions_enables_whenCurrentlyDisabled`
  - [x] `test_toggleDevicePermissions_disables_whenCurrentlyEnabled`
  - [x] `test_toggleDevicePermissions_fails_whenDeviceNoLongerExists`

---

## 8. Permissions — `feature/permissions` ✅

**Revision (from Section 7):** the per-device permissions toggle and
`ToggleDevicePermissionsUseCase` already exist — Section 7 found the real
product has this live in the device row, not deferred here, and built it
there.

**Revision (checked `PermissionManager.cs`/`usePermissions.ts`/`api.ts`
directly before building this section):** two more assumptions in the
original plan turned out to be fictional, both traced to
`PermissionRequestUrgency` having been scaffolded in Section 1 without ever
being checked against the real backend:
- **There is no timeout, no auto-deny, no urgency/countdown concept at
  all.** Direct quote from `PermissionManager.cs`: *"No time limit — a
  request waits until the user explicitly approves or denies it (the
  overlay is non-dismissable, so it can't be silently lost)."* It only
  resolves without an explicit answer if the underlying call is cancelled
  (an agent/turn stop), and that's treated as a cancellation, not a denial.
  Removed `PermissionRequestUrgency.swift` and
  `TIAGAColor.forPermissionUrgency(_:)` entirely, and corrected the
  `PermissionRequest` domain-noun description in CLAUDE.md (it claimed the
  same 5-minute auto-deny). No countdown UI; the overlay has no dismiss
  gesture (not a scrim-tap-to-close, not a sheet) so it can only close via
  Approve/Deny, matching "non-dismissable" for free.
- **Toggling a device's permissions is unconditional on the real
  product** — `DeviceManager.cs`'s `Update` sets `PermissionsRequired`
  with no guard against pending requests anywhere. The planned
  "can't disable while pending requests exist" business rule doesn't
  exist; `ToggleDevicePermissionsUseCase` needs no changes this section.

The real wire shape (`usePermissions.ts`'s `PermissionRequest` interface +
`PermissionManager.cs`'s `PendingPermission` record) is also different from
what was planned: `requester` is a **plain display string** ("TIAGA" for
the orchestrator itself, or an agent's name) — not an `AgentIdentifier`
reference, since the backend never resolves it against a roster either.
`deviceName` is sent directly alongside `deviceId` (no client-side join
needed — same lesson as Section 7's retracted agents-per-device join).
`kind` (`command`/`write`/`edit`) is a separate field from `tool` (the
literal tool name). MCP-originated requests (`kind: "mcp"`, no real
device) are out of scope — no MCP domain concept exists in this app.

**Revision (post-review, same PR):** the first pass rendered `.edit`
requests from the backend's flattened `detail` text through one
syntax-highlighted block, with each file's path embedded as a plain line
inside it — feedback was that the file name was indistinguishable from the
code, and that the web client actually shows a switchable tab per file.
Rebuilt to match `PermissionOverlay.tsx`'s `EditReview`/`FileLabel`/
`DiffView` directly: `PermissionEditFilesView` renders a native SwiftUI tab
per file (when there's more than one) plus a native file-path label above
the code, and `PermissionEditDiff` runs a real LCS line diff (old → new) so
every changed line is colored, not just the first line of a hunk (the
`detail` string's own quirk, not what the web client's interactive overlay
renders). Two more bugs surfaced and fixed in the same pass: the tab row
needed its own horizontal scroll (`ScrollView(.horizontal)`, matching the
web client's `overflow-x-auto`) for more files than fit the card width, and
`HighlightedCodeView`'s `WKWebView` doesn't report its own content height
back to SwiftUI, so a diff block was silently clipped —
`HighlightedCodeView.estimatedHeight(forLineCount:)` fixes that. The
fixture now has 5 files in one request (to exercise the tab overflow) and
one file with two non-contiguous edits (to exercise multiple diff blocks
stacked under a single tab).

Depends on `Agent` (Section 4), `Device` (Section 7), and the root navigation
container from Section 4 (this branch adds the overlay to it).

- [x] `Domain/Models/PermissionRequest.swift` — id (`String`, matching the
      backend's opaque id), `DeviceIdentifier`, `deviceName`, `requester`
      (`String`), `tool`, `kind` (`PermissionRequestKind`: `.command`/
      `.write`/`.edit`), `file` (optional), `detail`, `files`
      (optional `[PermissionRequestFile]`, used by the tabbed diff view).
      DocC: real-world event = the orchestrator or an agent on a protected
      device blocking a sensitive tool call until a human decides; rule =
      no timeout, waits indefinitely (see revision note above).
- [x] `Domain/Repositories/PermissionRequestRepository.swift` (protocol) —
      observe the live stream of pending requests app-wide, `approve(_:)`, `deny(_:)`.
- [x] `Data/Repositories/FakePermissionRequestRepository.swift` — fixture
      requests with a realistic (fabricated, harmless) command and edit
      sample so the approval UI's visual weight is genuinely exercised.
      Approve/deny only ever mutate the in-memory fixture — no real command
      is ever authorized to run anywhere. No network.
- [x] `UseCases/ReviewPermissionRequestUseCase.swift` — approve or deny.
  - [x] Business rule: cannot act on a request that is already resolved
  - [x] Typed error: `PermissionRequestError.requestAlreadyResolved`
- [x] `Presentation/ViewModels/PermissionRequestOverlayViewModel.swift` —
      root-scoped; observes the pending-request stream and, when more than one
      is outstanding, queues them (oldest first, one shown at a time).
- [x] `Presentation/Views/Permissions/PermissionRequestOverlayView.swift` —
      device, requester, tool, `detail` (`TIAGATypography.command`) for
      `.command`/`.write`, a per-file tabbed diff view
      (`PermissionEditFilesView`) for `.edit`, Approve/Deny. No dismiss
      gesture of any kind.
- [x] Wire the overlay into the Section 4 root container as a `ZStack`/`.overlay`
      so it renders above the active tab/screen regardless of route.
- [x] Unit tests (`TIAGATests/ReviewPermissionRequestUseCaseTests.swift`):
  - [x] `test_reviewPermissionRequest_approves_whenRequestIsPending`
  - [x] `test_reviewPermissionRequest_denies_whenRequestIsPending`
  - [x] `test_reviewPermissionRequest_fails_whenRequestAlreadyResolved`

---

## 9. Settings — `feature/settings` ✅

**Revision (checked `UsagePanel.tsx`/`PrivacyPanel.tsx`/`BillingPanel.tsx`/
`ContextBar.tsx`/`api.ts` directly before building):** several premises in
the original plan above were wrong or incomplete:

- **`UsageSummary` has three mutually exclusive states, not two.** The real
  backend's `/api/billing` (`BillingInfo`) resolves to admin (dollar cost),
  subscribed (percentage meters), **or an unmodeled third state: no active
  plan at all** — the original plan only covered the first two. Modeled as
  `UsageSummary.admin`/`.subscription`/`.noActivePlan`.
- **Admin usage is four dollar figures, not "session and weekly."** The real
  `adminUsage` also includes past-30-days and all-time totals.
- **Subscription usage also carries reset timestamps and an extra-credits
  dollar balance** (`sessionResetsAt`/`weeklyResetsAt`/`extraCreditsUsd`),
  none of which were in the original plan.
- **The 60%/85% "don't reuse one threshold function for the other" note was
  wrong** — checked `ContextBar.tsx` directly: it uses the exact same 60/85
  thresholds as `UsagePanel.tsx`'s `Meter`, not 75%/100%. `UsageMeterView`
  reuses `TIAGAColor.forContextUsage` (normalized to a 0...1 fraction from
  the wire's 0...100 percentage) instead of a second, divergent color rule.
- **A plan's renewal status is a 4-way precedence, not just "renewal
  date."** `BillingPanel.tsx`: a pending downgrade beats queued time beats
  auto-renew beats plain ending. Modeled as `ActivePlan.RenewalStatus`
  (`.switchingTo`/`.queued`/`.renewing`/`.ending`); the exact display copy
  per case lives in `SettingsView.planStatusText(_:)`, matching
  `BillingPanel.tsx`'s status-line strings verbatim (date formatting itself
  uses native `Date.FormatStyle`, not a JS-identical reimplementation).
- **The privacy wire field is inverted**: `api.ts`'s `fetchPrivacy`/
  `setPrivacy` use `trainingOptOut`, the opposite of the "Use my
  conversations to improve AI" toggle shown. `PrivacyPreference` models the
  UI-facing `improveAIEnabled`, with a note for the eventual
  `RemotePrivacyRepository` about the inversion.
- **Devices and Integrations (MCP) tabs from the web's Settings modal don't
  need mobile equivalents** — Devices already has its own root-level screen
  (Section 7), and MCP has no domain concept in this app (Section 8's
  finding, unchanged). Usage/Billing/Privacy/Log out is the full mobile
  scope.
- Currency values use a hardcoded `"$" + String(format: "%.2f", _)`
  (`SettingsView.usd(_:)`), not `.currency(code: "USD")` — the latter is
  locale-dependent and can render as "USD 3.50" instead of "$3.50"
  depending on the device's region; the real product is dollar-only
  regardless of locale.
- Also fixed two stale doc comments found while in this area: `Account
  .swift`'s `AccountRole.admin` case said admin status is "not surfaced in
  this app" (Settings' Usage section now surfaces it), and
  `ToggleDevicePermissionsUseCase`'s doc comment still described a pending-
  requests guard as something Section 8 "would" add — Section 8 already
  found and documented that no such rule exists.

- [x] `Domain/Models/UsageSummary.swift` — `.admin(AdminUsage)`/
      `.subscription(SubscriptionUsage)`/`.noActivePlan(extraCreditsUsd:)`.
- [x] `Domain/Models/SubscriptionPlan.swift` — `.active(ActivePlan)`/`.none`;
      `ActivePlan.RenewalStatus` for the 4-way precedence above.
- [x] `Domain/Models/PrivacyPreference.swift`
- [x] `Domain/Repositories/AccountRepository.swift` (protocol) +
      `Data/Repositories/FakeAccountRepository.swift` — fixture usage/plan
      data (3 selectable variants, see `FakeAccountRepository.UsageVariant`)
      plus an injectable failure mode. No network.
- [x] `UseCases/LoadAccountUsageUseCase.swift` — returns usage + plan
      together as `AccountUsageSnapshot` (the real backend resolves both
      from the same call).
  - [x] Typed error: `AccountUsageError.accountUnreachable`
- [x] `UseCases/UpdatePrivacyPreferenceUseCase.swift`
  - [x] Typed error: `PrivacyPreferenceError.updateFailedWhileOffline`
- [x] `Presentation/ViewModels/SettingsViewModel.swift`
- [x] `Presentation/Views/Settings/SettingsView.swift`:
  - [x] Usage section (bound to `UsageSummary`, all three states)
  - [x] Privacy switch
  - [x] Billing section: current plan (read-only), static notice text that
        plan management happens on the web version — no tappable link,
        plain text only
  - [x] Log out action, calling `LogoutUseCase` from Section 3
- [x] Unit tests (`TIAGATests/LoadAccountUsageUseCaseTests.swift`,
      `UpdatePrivacyPreferenceUseCaseTests.swift`):
  - [x] `test_loadAccountUsage_succeeds_returningUsageAndPlan`
  - [x] `test_loadAccountUsage_fails_whenAccountIsUnreachable`
  - [x] `test_updatePrivacyPreference_succeeds_whenOnline`
  - [x] `test_updatePrivacyPreference_fails_whenOffline`

---

## 10. Live Backend Wiring — one `Remote*Repository` at a time

Not a numbered feature section with its own single branch — each repository
below is its own small, independently-mergeable PR (`feature/remote-<area>`),
checked against the real backend's actual endpoints the same way every prior
section was. See AGENTS.md's "Live backend" policy for the Preview-vs-
everywhere-else selection rule every `Remote*Repository` follows.

- [x] `RemoteAuthSessionRepository` (`AuthController`/`RedeemController`) —
      login, session restore (`GET /api/auth/me`, checked against
      `SessionCookieStore.hasSessionCookie` first to skip the network call
      when there's obviously no session), logout, invite code redemption.
      **Revision (checked `AuthController.cs`/`RedeemController.cs`/
      `Program.cs`'s rate limiter directly):** `/api/redeem`'s response is
      just `{ ok, message }` — it doesn't return the updated account, so
      `redeemInviteCode` re-fetches `/api/auth/me` after a successful
      redeem to pick up the new `.active` status. Login's rate limiting is
      HTTP 429 from ASP.NET's rate limiter middleware (`{error: "Too many
      attempts..."}`), not a custom error field — mapped from the status
      code, not the message text. **Logout order matters**: the real
      session-invalidation call must go out *with* the session cookie still
      attached (so the backend can find and delete that exact session
      row) — clearing local cookie storage before the request would send
      the logout call with no cookie at all, leaving the session valid
      server-side for its full 180-day sliding expiry. `defer` clears the
      cookie after the call regardless of outcome. **Deliberate deviation
      from the web client**: `/api/auth/me`'s `hasAccess` field (real
      subscription or credits) is fetched but intentionally unused — the
      web force-routes an `.active`, non-admin, `hasAccess: false` account
      to a billing paywall on login, but this app has no checkout flow to
      route to (Billing is read-only, web-only by design), so that account
      just reaches the Fleet Console with Settings already showing "no
      active plan."
- [ ] `RemoteAgentRosterRepository` / `RemoteAgentConversationRepository` /
      `RemoteOrchestratorConversationRepository` (Chat + Agent Chat) — the
      highest-stakes area to wire live: a real message sent from this app
      reaches a real LLM (real cost) and, if it dispatches a tool call, a
      real agent doing real things on a real machine. Needs `TIAGAEventStream`
      for streaming tokens/tool events, not just request/response.
- [ ] `RemoteDeviceFleetRepository` (Devices) — device list + online
      presence (likely via `TIAGAEventStream`, not polling) + the
      permissions-required toggle.
- [ ] `RemotePermissionRequestRepository` (Permissions) — the pending-
      requests stream (`TIAGAEventStream`) + approve/deny. Real approval
      overlay, real consequences: an approval here lets a real tool call
      proceed on a real machine.
- [ ] `RemoteAccountRepository` (Settings) — usage/plan (`GET /api/billing`)
      + privacy preference (`GET`/`POST /api/privacy`, remembering the wire
      field is inverted — `trainingOptOut`, not `improveAIEnabled`; see
      `PrivacyPreference`'s doc comment).

---

## Notes

- The assignment's minimum bar (3 Use Cases, 8 tests, 4 screens) is cleared by
  Section 5 (Chat) alone plus Sections 1–4; everything after that is genuine
  feature completeness, not padding for the rubric.
- If time runs short, Sections 1–5 are the load-bearing minimum for a
  submittable MVP (nothing works without Auth, and there's no app without
  Chat); 6–9 round it out. Permissions (8) matters most among those if time
  is tight — it's the one place a human decision is on the critical path.
- Scope is exactly the feature list given — do not pull in things only the web
  client has (voice, the particle sphere, dynamic UI drag/tether animation,
  meeting transcription, team workspaces, marketplace, sign-up/beta-application
  forms unless confirmed). If a task here seems to need one of those, stop and
  ask rather than building it.
