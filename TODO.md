# TIAGA Mobile — Build Plan

Working checklist for building the MVP. See `CLAUDE.md` for domain context and
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
- [ ] Before opening any PR touching UI: boot a simulator, build, install, launch, and screenshot each new/changed screen (`xcrun simctl io booted screenshot`) and actually look at it — see CLAUDE.md's Testing section for the exact commands. Then still include a manual visual-confirmation checklist in the test plan for whatever that static screenshot pass can't cover (interactive multi-step flows, final polish) — the user runs those, Claude doesn't.
- [ ] Every repository is fixture-backed (`Fake*Repository`) — **the app never talks to the real TIAGA backend.** TIAGA can dispatch real agents onto real machines; a `Remote*Repository` wired into the running app would mean casual manual testing sends real chat messages, real approvals, and real kills against a real account. See CLAUDE.md's testing-safety policy before building any repository implementation.
- [ ] Screenshot every screen a PR adds or changes (not just the launch screen — use a DEBUG route override per screen), commit them to `docs/screenshots/`, and embed them in the PR body as a grid (HTML table, width-capped `<img>`s) — see CLAUDE.md's Testing section for the exact URL form (this repo is private) and the before/after pattern for a PR that changes an existing screen's UI.
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

**Status note (added after this section landed):** every later section now
builds a `Fake*Repository`, not a `Remote*Repository` — see the testing-
safety policy in CLAUDE.md and the Process checklist below. `TIAGAAPIClient`/
`TIAGAEventStream`/`SessionCookieStore` stay as-is: correct, tested transport-
layer plumbing that demonstrates the real contract, but nothing in the app
constructs one against the live backend. That's a deliberate, not temporary,
decision — don't "finish the job" by wiring it in later without being asked.

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
      wrong-password case and a rate-limited case. **No live backend
      integration** — see CLAUDE.md's testing-safety policy: TIAGA can
      dispatch real agents onto real machines, so nothing in this app talks
      to the real backend.
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
      real LLM, no network — see CLAUDE.md's testing-safety policy.
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

## 6. Agent Chat — `feature/agent-chat`

Per-agent conversation. Reuses `ChatMessage`, `ToolUsageEvent`,
`SendChatMessageUseCase`, and `ChatComposerBar`/`MessageBubble` from Chat —
do not duplicate them.

- [ ] `Domain/Repositories/AgentRosterRepository.swift` — extend with
      `cancelActiveTask(for:)` and `delete(_:)`, and an observe-single-agent method.
- [ ] `UseCases/CancelAgentTaskUseCase.swift`
  - [ ] Business rule: only valid while the agent is `.running` or `.compacting`
  - [ ] Typed error: `AgentLifecycleError.noActiveTaskToCancel`
- [ ] `UseCases/DeleteAgentUseCase.swift`
  - [ ] Business rule: deleting is allowed regardless of state (matches the
        real product — in-flight tool calls are closed cleanly), but a
        second delete of an already-gone agent must fail cleanly
  - [ ] Typed error: `AgentLifecycleError.agentNoLongerExists`
- [ ] `Presentation/ViewModels/AgentChatViewModel.swift`
- [ ] `Presentation/Views/AgentChat/AgentChatView.swift` — composer, transcript,
      delete button, stop/cancel button shown only when state is `.running`
      or `.compacting`.
- [ ] Unit tests (`TIAGATests/CancelAgentTaskUseCaseTests.swift`,
      `DeleteAgentUseCaseTests.swift`):
  - [ ] `test_cancelAgentTask_succeeds_whenAgentIsRunning`
  - [ ] `test_cancelAgentTask_fails_whenAgentIsIdle`
  - [ ] `test_deleteAgent_succeeds_whenAgentExists`
  - [ ] `test_deleteAgent_fails_whenAgentAlreadyDeleted`
  - [ ] `test_sendChatMessage_fails_whenTargetAgentIsCompacting` (extends the shared use case's coverage for the agent-target case)

---

## 7. Devices — `feature/devices`

- [ ] `Domain/Models/Device.swift` — `DeviceIdentifier`, display name,
      `DeviceType` (`.macOS`/`.windows`/`.linux`), `isProtected`, `lastSeenAt`.
      DocC: real-world entity = a machine with the harness installed; rule =
      presence is derived, not just a stored flag (see below).
- [ ] `Domain/Models/DevicePresence.swift` — `.online` / `.offline`, derived
      from `lastSeenAt` against a staleness threshold, not trusted as a raw
      server flag (a device can go dark without sending a final "offline" event).
- [ ] `Domain/Repositories/DeviceFleetRepository.swift` (protocol) +
      `Data/Repositories/FakeDeviceFleetRepository.swift` — fixture devices
      spanning online/offline/stale-heartbeat (for the boundary test below)
      plus an injectable failure mode for `fleetUnreachable`. No network.
- [ ] `UseCases/ObserveDeviceFleetUseCase.swift`
  - [ ] Business rule: a device is `.offline` if `lastSeenAt` is older than the
        staleness threshold, even if the last reported state was online
  - [ ] Business rule: sort online devices before offline, then alphabetically
  - [ ] Typed error: `DeviceFleetError.fleetUnreachable`
- [ ] `Presentation/ViewModels/DevicesViewModel.swift`
- [ ] `Presentation/Views/Devices/DevicesView.swift` — row per device: name,
      `TIAGAIcon` for OS, `StatusPill` for presence, last-seen text. The row's
      protection `Toggle` is added in Section 8 (needs `ToggleDeviceProtectionUseCase`);
      this branch just renders `isProtected` read-only.
- [ ] Unit tests (`TIAGATests/ObserveDeviceFleetUseCaseTests.swift`):
  - [ ] `test_observeDeviceFleet_sortsOnlineBeforeOffline`
  - [ ] `test_observeDeviceFleet_treatsStaleHeartbeatAsOffline` (boundary: reported online, `lastSeenAt` past threshold)
  - [ ] `test_observeDeviceFleet_treatsRecentHeartbeatAsOnline` (boundary: just inside threshold)
  - [ ] `test_observeDeviceFleet_fails_whenFleetIsUnreachable`

---

## 8. Permissions — `feature/permissions`

Two related pieces: the approval pop-up that must appear above whatever screen
the operator is on, and the per-device switch that turns approval-gating on/off.
Depends on `Agent` (Section 4), `Device` (Section 7), and the root navigation
container from Section 4 (this branch adds the overlay to it).

- [ ] `Domain/Models/PermissionRequest.swift` — id, `AgentIdentifier`,
      `DeviceIdentifier`, tool name (`bash`/`write`/`edit`/`run_app`/`kill_process`),
      command-or-diff preview text, requestedAt, expiresAt. DocC: real-world
      event = a protected device blocking a sensitive tool call until a human
      approves it; rule = auto-denied if unanswered for 5 minutes. Exposes a
      computed `urgency: PermissionRequestUrgency` (already scaffolded) from
      `expiresAt`.
- [ ] `Domain/Repositories/PermissionRequestRepository.swift` (protocol) —
      observe the live stream of pending requests app-wide, `approve(_:)`, `deny(_:)`.
- [ ] `Data/Repositories/FakePermissionRequestRepository.swift` — fixture
      requests with a realistic (fabricated, harmless) command/diff sample so
      the approval UI's visual weight is genuinely exercised, plus one request
      close to its `expiresAt` to exercise `.expiringSoon`. Approve/deny only
      ever mutate the in-memory fixture — no real command is ever authorized
      to run anywhere. No network.
- [ ] Extend `Domain/Repositories/DeviceFleetRepository.swift` (Section 7) with
      `setProtectionEnabled(_:for:)`.
- [ ] `UseCases/ReviewPermissionRequestUseCase.swift` — approve or deny.
  - [ ] Business rule: cannot act on a request that is already resolved
  - [ ] Business rule: cannot act on a request that has expired (auto-denied)
  - [ ] Typed error: `PermissionRequestError` (`.requestAlreadyResolved`, `.requestExpired`)
- [ ] `UseCases/ToggleDeviceProtectionUseCase.swift`
  - [ ] Business rule: cannot disable protection on a device that has
        unresolved pending permission requests — the operator must resolve
        them first rather than have them silently voided
  - [ ] Typed error: `DeviceProtectionError.pendingRequestsMustBeResolvedFirst`
- [ ] `Presentation/ViewModels/PermissionRequestOverlayViewModel.swift` —
      root-scoped; observes the pending-request stream and, when more than one
      is outstanding, queues them (oldest first, one shown at a time).
- [ ] `Presentation/Views/Permissions/PermissionRequestOverlayView.swift` —
      device, agent, tool, command/diff (`TIAGATypography.command`), urgency-
      colored countdown (`TIAGAColor.forPermissionUrgency`), Approve/Deny.
- [ ] Wire the overlay into the Section 4 root container as a `ZStack`/`.overlay`
      so it renders above the active tab/screen regardless of route.
- [ ] Add the protection `Toggle` to `DevicesView` rows, bound through
      `DevicesViewModel` to `ToggleDeviceProtectionUseCase`.
- [ ] Unit tests (`TIAGATests/ReviewPermissionRequestUseCaseTests.swift`,
      `ToggleDeviceProtectionUseCaseTests.swift`):
  - [ ] `test_reviewPermissionRequest_approves_whenRequestIsPending`
  - [ ] `test_reviewPermissionRequest_denies_whenRequestIsPending`
  - [ ] `test_reviewPermissionRequest_fails_whenRequestAlreadyResolved`
  - [ ] `test_reviewPermissionRequest_fails_whenRequestHasExpired`
  - [ ] `test_toggleDeviceProtection_enables_whenCurrentlyDisabled`
  - [ ] `test_toggleDeviceProtection_fails_whenDisablingWithPendingRequestsOutstanding`

---

## 9. Settings — `feature/settings`

- [ ] `Domain/Models/UsageSummary.swift` — session (5-hour rolling window) and
      weekly percentage-of-plan usage, resolved against `web/src/components/UsagePanel.tsx`:
      admin accounts see actual dollar cost instead of a percentage (no plan
      limits to meter against) — model that as a variant, not a special case
      bolted onto the percentage path. **Note:** this is a *different* usage
      metric from the Chat context bar (Section 5) — account/billing usage
      colors at 60%/85% (`UsagePanel.tsx`'s `Meter`), context-window usage
      colors at 75%/100% (`TIAGAColor.forContextUsage`). Don't reuse one
      threshold function for the other.
- [ ] `Domain/Models/SubscriptionPlan.swift` — plan name/tier, renewal date.
      **Note found while building Section 3:** the invite code an operator
      redeems on the Waitlist Gate and a billing top-up/upgrade code are the
      *same* backend system (`RedemptionCodes`, `/api/redeem` — each code
      carries a `Tier` + `DurationDays`; redeeming always grants that plan).
      There's also an admin-direct-grant path with no code at all
      (`BillingService.GrantAsync`, from reviewing a beta application) — the
      app doesn't need to model that; it just shows up as the account already
      being `.active` on next login. If a future top-up/upgrade flow gets
      built here, reuse the invite-code redemption plumbing from Section 3
      rather than inventing a parallel one — same code type, same endpoint.
- [ ] `Domain/Models/PrivacyPreference.swift` — resolved against
      `web/src/components/PrivacyPanel.tsx`: the (only) privacy switch is
      "Use my conversations to improve AI" — an opt-out of TIAGA's AI partners
      using conversations for model training. Turning it off can burn through
      usage allowance faster (the real UI shows this exact warning inline —
      carry it over verbatim in the human-facing copy, it's a real product
      constraint, not filler text).
- [ ] `Domain/Repositories/AccountRepository.swift` (protocol) +
      `Data/Repositories/FakeAccountRepository.swift` — fixture usage/plan
      data plus an injectable failure mode for `accountUnreachable`. No network.
- [ ] `UseCases/LoadAccountUsageUseCase.swift`
  - [ ] Typed error: `AccountUsageError.accountUnreachable`
- [ ] `UseCases/UpdatePrivacyPreferenceUseCase.swift`
  - [ ] Business rule: turning a preference off must not retroactively delete
        already-collected data, only stop future collection
  - [ ] Typed error: `PrivacyPreferenceError.updateFailedWhileOffline`
- [ ] `Presentation/ViewModels/SettingsViewModel.swift`
- [ ] `Presentation/Views/Settings/SettingsView.swift`:
  - [ ] Usage section (bound to `UsageSummary`)
  - [ ] Privacy switch
  - [ ] Billing section: current plan (read-only), static notice text that
        plan management happens on the web version — **no tappable link**,
        plain text only
  - [ ] Log out action, calling `LogoutUseCase` from Section 3
- [ ] Unit tests (`TIAGATests/LoadAccountUsageUseCaseTests.swift`,
      `UpdatePrivacyPreferenceUseCaseTests.swift`):
  - [ ] `test_loadAccountUsage_succeeds_returningUsageAndPlan`
  - [ ] `test_loadAccountUsage_fails_whenAccountIsUnreachable`
  - [ ] `test_updatePrivacyPreference_succeeds_whenOnline`
  - [ ] `test_updatePrivacyPreference_fails_whenOffline`

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
