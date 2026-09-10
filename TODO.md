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

---

## 1. Design System — `feature/design-system` ✅

Foundation every later screen consumes. Built from scratch on the bare
project scaffold: `TIAGAColor`, `TIAGASpacing`, `TIAGARadius`, `TIAGATypography`,
the `Colors.xcassets` set, and the `AgentState`/`PermissionRequestUrgency`
domain models the color mappings need.

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

## 2. API Layer — `feature/api-layer`

Shared networking/transport only — **no feature-specific endpoints or DTOs
here**; those are added inside each feature's own `Data/Repositories`
implementation so this branch stays generic and every later branch has
something concrete to build on.

- [ ] `Data/API/TIAGAAPIClient.swift` — base HTTP client (base URL, request
      building, JSON decoding, response/status handling).
- [ ] `Data/API/TIAGAEventStream.swift` — SSE/WebSocket wrapper for live
      updates (device presence, agent state, streaming chat tokens) — the real
      backend uses SSE to the web client and WebSocket to harnesses; the phone
      client consumes the SSE-equivalent stream.
- [ ] `Data/API/SessionCookieStore.swift` — the real backend authenticates
      with a long, sliding **session cookie** (not a bearer token the client
      manages) — `URLSession`'s shared `HTTPCookieStorage` handles this
      naturally and persists across launches. No login screen lives in this
      branch; it just configures the client to carry cookies correctly. The
      actual login/waitlist flow is Section 3.
- [ ] `Domain/Errors/APITransportError.swift` — infra-level failure states
      (`unreachable`, `unauthorized`, `decodingFailed`) that feature
      repositories translate into their own domain error cases — Views and
      ViewModels never see this type directly.
- [ ] Unit tests (`TIAGATests/APIClientTests.swift`):
  - [ ] `test_apiClient_decodesSuccessfulResponse`
  - [ ] `test_apiClient_mapsUnauthorizedStatusToTransportError`
  - [ ] `test_apiClient_mapsUnreachableHostToTransportError`

---

## 3. Auth (Login + Waitlist Gate) — `feature/auth`

Gates every other screen. TIAGA is in private beta — signing in successfully
doesn't mean access; a `waitlisted` account must be shown the waitlist gate
instead of the fleet console until it's activated. Mirrors the web client's
`useAuth`/`authMe`/`authLogin`/`WaitlistScreen` behavior — see
`AuthService.cs` and `web/src/hooks/useAuth.ts` / `web/src/components/WaitlistScreen.tsx`
in the parent repo before naming anything here.

- [ ] `Domain/Models/Account.swift` — email, `AccountStatus`, roles. DocC:
      real-world entity = a signed-in TIAGA user; rule = authentication
      succeeding does not imply product access.
- [ ] `Domain/Models/AccountStatus.swift` — `.waitlisted`, `.active` (exact
      values the real backend uses — do not add states it doesn't have).
- [ ] `Domain/Repositories/AuthSessionRepository.swift` (protocol) —
      `restoreSession()`, `login(email:password:)`, `redeemInviteCode(_:)`, `logout()`.
- [ ] `Data/Repositories/RemoteAuthSessionRepository.swift`
- [ ] `UseCases/RestoreSessionUseCase.swift` — checks for a valid existing
      session on launch so a returning active user skips straight to the app.
  - [ ] Typed error: `SessionRestoreError.connectionUnavailable`
- [ ] `UseCases/LoginUseCase.swift`
  - [ ] Business rule: email must be a plausible address, password non-empty
  - [ ] Typed error: `LoginError` (`.invalidCredentials`, `.tooManyAttempts`, `.connectionUnavailable`)
- [ ] `UseCases/RedeemInviteCodeUseCase.swift`
  - [ ] Business rule: only meaningful for a `.waitlisted` account — redeeming
        against an already-`.active` account is rejected rather than silently ignored
  - [ ] Typed error: `InviteCodeError` (`.codeInvalid`, `.accountAlreadyActive`)
- [ ] `UseCases/LogoutUseCase.swift` — business rule: always clears the local
      session even if the remote invalidation call fails; a user must never
      be stuck "logged in" locally by a network error. No typed error — it
      cannot meaningfully fail from the operator's side. (UI trigger for this
      lives in Settings, Section 9 — defined here because it's session logic.)
- [ ] `Presentation/ViewModels/AuthViewModel.swift` — drives launch routing:
      `.unauthenticated` → Login, `.authenticated(.waitlisted)` → Waitlist Gate,
      `.authenticated(.active)` → the Section 4 app shell.
- [ ] `Presentation/Views/Auth/LoginView.swift` — email + password, submit,
      inline error text. **Login only — no sign-up screen** (accounts are
      created on the web today; confirm if that should change).
- [ ] `Presentation/Views/Auth/WaitlistGateView.swift` — "you're on the
      waiting list" message + invite code field. **Assumption to confirm:**
      the web waitlist screen also has a beta-application form; this mobile
      version defaults to message + code redemption only (no application
      form) since that's the action a mobile user is most likely to take on
      the spot. Flag if the application form should be included too.
- [ ] Unit tests (`TIAGATests/LoginUseCaseTests.swift`,
      `RestoreSessionUseCaseTests.swift`, `RedeemInviteCodeUseCaseTests.swift`):
  - [ ] `test_login_succeeds_withValidCredentials`
  - [ ] `test_login_fails_withInvalidCredentials`
  - [ ] `test_login_fails_whenRateLimited`
  - [ ] `test_restoreSession_returnsActiveAccount_whenSessionIsValid`
  - [ ] `test_restoreSession_returnsUnauthenticated_whenNoSessionExists`
  - [ ] `test_redeemInviteCode_activatesWaitlistedAccount_whenCodeIsValid`
  - [ ] `test_redeemInviteCode_fails_whenCodeIsInvalid`
  - [ ] `test_redeemInviteCode_fails_whenAccountIsAlreadyActive`

---

## 4. Side Menu — `feature/side-menu`

Navigation shell for an authenticated, `.active` account (reached only after
Section 3 routes here). Introduces the `Agent` domain model (previously only
`AgentState` existed).

- [ ] `Domain/Models/Agent.swift` — `AgentIdentifier`, display name, `AgentState`,
      pinned `DeviceIdentifier`, last-activity summary, context-usage fraction.
      DocC: real-world entity = a persistent named agent; rule = it is always
      pinned to exactly one device from spawn.
- [ ] `Domain/Models/AppRoute.swift` — navigation destinations: `.chat`,
      `.agentChat(AgentIdentifier)`, `.devices`, `.settings`.
- [ ] `Domain/Repositories/AgentRosterRepository.swift` (protocol) — list/observe
      the operator's agents.
- [ ] `Data/Repositories/RemoteAgentRosterRepository.swift` — implementation on
      `TIAGAAPIClient`/`TIAGAEventStream`.
- [ ] `UseCases/ListAgentRosterUseCase.swift` — business rule: running/compacting
      agents sort before idle, idle before error, ties broken by most-recent
      activity — an operator scanning the menu should see what needs attention first.
  - [ ] Typed error: `AgentRosterError` (`.fleetUnreachable`)
- [ ] `Presentation/ViewModels/SideMenuViewModel.swift`
- [ ] `Presentation/Views/SideMenuView.swift` — replaces the current stub.
      Rows: "Chat" (fixed, always first), agent list (name + `StatusPill`),
      "Devices", "Settings".
- [ ] Root navigation container wiring the menu to a detail pane, routing to
      placeholder screens for Chat/Devices/Settings/Agent Chat until their
      branches land.
- [ ] Unit tests (`TIAGATests/ListAgentRosterUseCaseTests.swift`):
  - [ ] `test_listAgentRoster_ordersRunningAgentsBeforeIdle`
  - [ ] `test_listAgentRoster_ordersErrorAgentsAfterIdle`
  - [ ] `test_listAgentRoster_breaksTiesByMostRecentActivity`
  - [ ] `test_listAgentRoster_fails_whenFleetIsUnreachable`

---

## 5. Chat (main orchestrator chat) — `feature/chat`

The "Chat" entry from the side menu — conversation with the orchestrator.
Voice is explicitly out of scope: no mic input, no spoken output, text only.

- [ ] `Domain/Models/ChatMessage.swift` — id, role (`.operator` / `.orchestrator`),
      text, sentAt.
- [ ] `Domain/Models/ToolUsageEvent.swift` — tool name, target device (optional),
      human-readable summary, occurredAt. DocC: represents a tool call the
      orchestrator or an agent made, shown inline in the transcript.
- [ ] `Domain/Models/DynamicUICard.swift` + `DynamicUICardKind` (`.text`, `.code`,
      `.table`, `.error`) — mirrors the real product's AI-composed UI cards.
- [ ] `Domain/Models/ConversationContextUsage.swift` — fraction used + derived
      level (`.normal` / `.high` / `.critical`) at the 75%/100% thresholds.
- [ ] `Domain/Repositories/OrchestratorConversationRepository.swift` (protocol) —
      send a message, observe the live transcript (messages + tool usage,
      merged in chronological order), observe context usage, reset the
      conversation, fetch dynamic UI card history.
- [ ] `Data/Repositories/RemoteOrchestratorConversationRepository.swift`
- [ ] `UseCases/SendChatMessageUseCase.swift` — reusable for both this feature
      and Agent Chat (takes a `ConversationTarget`: `.orchestrator` or
      `.agent(AgentIdentifier)`).
  - [ ] Business rule: message text cannot be empty/whitespace-only
  - [ ] Business rule: cannot send while the target is still streaming a reply
  - [ ] Typed error: `SendChatMessageError` (`.messageIsEmpty`, `.conversationBusy`)
- [ ] `UseCases/ResetConversationUseCase.swift`
  - [ ] Business rule: cannot reset while a response is actively streaming (data-loss risk mid-stream)
  - [ ] Typed error: `ResetConversationError` (`.conversationBusy`)
- [ ] `UseCases/LoadDynamicUICardHistoryUseCase.swift` — backs the "browse
      dynamic UI" button.
  - [ ] Typed error: `DynamicUICardHistoryError` (`.unavailable`)
- [ ] `Presentation/ViewModels/ChatViewModel.swift`
- [ ] `Presentation/Views/Chat/ChatView.swift` — transcript (messages + tool
      usage interleaved), `ChatComposerBar`, reset button, `ContextUsageBar`,
      dynamic-UI-browser entry point.
- [ ] `Presentation/Views/Chat/DynamicUICardBrowserView.swift`
- [ ] Unit tests (`TIAGATests/SendChatMessageUseCaseTests.swift`,
      `ResetConversationUseCaseTests.swift`):
  - [ ] `test_sendChatMessage_succeeds_withNonEmptyText`
  - [ ] `test_sendChatMessage_fails_whenTextIsEmpty`
  - [ ] `test_sendChatMessage_fails_whenConversationIsAlreadyStreaming`
  - [ ] `test_resetConversation_succeeds_whenConversationIsIdle`
  - [ ] `test_resetConversation_fails_whileConversationIsStreaming`
  - [ ] `test_transcriptMerge_ordersMessagesAndToolUsageChronologically` (pure-function test on the merge logic backing the transcript list)

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
- [ ] `Domain/Repositories/DeviceFleetRepository.swift` (protocol) + `Data/Repositories/RemoteDeviceFleetRepository.swift`
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
- [ ] `Data/Repositories/RemotePermissionRequestRepository.swift`
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

- [ ] `Domain/Models/UsageSummary.swift` — tokens/requests used vs. plan quota,
      current billing period.
- [ ] `Domain/Models/SubscriptionPlan.swift` — plan name/tier, renewal date.
- [ ] `Domain/Models/PrivacyPreference.swift` — **needs a decision from you
      before building:** what does the privacy switch actually control? (e.g.
      whether the memory/context tree persists conversation history vs. a
      diagnostics-sharing toggle). Placeholder assumption below; confirm or
      correct when this branch starts.
- [ ] `Domain/Repositories/AccountRepository.swift` (protocol) + `Data/Repositories/RemoteAccountRepository.swift`
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
