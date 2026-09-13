# AGENTS.md — TIAGA Mobile (Fleet Operations Console)

This file orients any coding agent working in this repo. Read it before
touching app code. It is the canonical index — when a decision here goes stale,
fixing this file is part of the change that made it stale.

## What this project is

The mobile companion app for [TIAGA](../tiaga-repos/tiaga-nexus) — a real
product, not a class exercise. TIAGA is a multi-machine AI control center that
dispatches persistent AI coding agents onto a user's fleet of
desktops/laptops/servers. The desktop product is voice-first and lives at the
machine; this app is the console you reach for **away from the machines**:
check whether a build finished, approve or deny a sensitive command an agent
wants to run, kill a runaway process, see which devices are online — from
your phone.

This build is also being submitted as a university iOS assessment (a
domain-centred MVP + architecture piece, not a tech demo). That's a
constraint layered on top of real product work, not the other way around —
build it to the standard the real product deserves: model the real backend's
actual shape faithfully (real auth flow, the actual account/billing model,
real business rules — not invented ones), even though nothing in this app
actually talks to it live from Xcode Previews (see "Live backend" below).
Treat the assessment rubric (DocC comments, the Use Case layer, named tests,
the reflective report) as documentation discipline the product should have
anyway, not busywork bolted on for a grade.

If you need deep context on the parent product (how agents, the harness,
auth/billing, and permission gating actually work today), read
`../tiaga-repos/tiaga-nexus/PITCH_REPORT.md`, `../tiaga-repos/tiaga-nexus/AGENT.md`,
and `../tiaga-repos/tiaga-nexus/backend/Services/AuthService.cs`. This app's
domain vocabulary must stay consistent with that product — it is not a
generic invented domain, and it is not a demo backend either.

## Domain & stakeholder

- **Stakeholder:** a developer/engineer who owns multiple machines running the
  TIAGA harness and dispatches AI agents to do real work on them (write code,
  run builds, manage processes).
- **Problem this app solves:** that stakeholder can't watch a screen all day.
  They need a mobile console to monitor fleet/agent state and to make the
  approval decisions that only a human can make (a sensitive command needs a
  yes/no before an agent can run it), without being at a desk.
- **Core domain nouns** (keep these exact names — do not genericise them):
  - **Device** — a machine with the harness installed. Has an identity, an
    auto-detected type (the OS), online/offline presence, and a protection
    mode (protected devices gate sensitive tools behind approval).
  - **Agent** — a named, persistent AI worker pinned to one device at spawn.
    Has a state (`idle` / `running` / `compacting` / `error`), its own chat
    history, and a report of its last task. See `AgentState`.
  - **PermissionRequest** — an approval prompt raised when the orchestrator
    or an agent on a protected device wants to run a sensitive tool (`bash`,
    `write`, `edit`, `run_app`, `kill_process`). Shows the exact command or
    an old/new diff. **No timeout**: the real backend's `PermissionManager`
    blocks the call indefinitely until the operator explicitly approves or
    denies it — the approval overlay is non-dismissable so it can never be
    silently lost. (An earlier version of this file claimed a 5-minute
    auto-deny; that was never checked against the real backend and doesn't
    exist — confirmed directly against `PermissionManager.cs` while building
    Section 8. There is no `PermissionRequestUrgency` type for the same
    reason.)
  - **ManagedProcess** — a long-running command the harness promoted to a
    tracked background process (pid, start time, exit code) on a device.
    Can be killed remotely.
  - **Account** — a signed-in TIAGA user. Has a `status` of `waitlisted` or
    `active` (TIAGA is in private beta — a new signup doesn't get in until
    invited or a beta application is approved). A `waitlisted` account
    authenticates successfully but sees the waitlist gate instead of the
    fleet console until an invite code redemption (or admin approval) flips
    it to `active`.
- Do not invent generic replacements for these (no `Item`, `Record`, `Entry`).
  If a new concept doesn't map to something in the real product, check
  `PITCH_REPORT.md` before naming it.

## Architecture (required layering — see assessment spec for the rubric)

```
SwiftUI Views          Presentation/Views/<Feature>/
ViewModels (MVVM)       Presentation/ViewModels/
Use Cases               UseCases/                (business operations — the required layer)
Domain Models + Repos    Domain/Models/, Domain/Repositories/ (protocols), Domain/Errors/
Data (repo impls)       Data/Repositories/
```

Rules:
- Views never call a Repository directly, and never contain business rules —
  they call a ViewModel, which calls a Use Case.
- Every significant business operation (approve a permission request, kill a
  process, dispatch a task to an agent, …) is its own `...UseCase` struct with
  a typed domain error enum. Minimum 3 for the assessment; see rubric below.
- `Domain/Repositories` holds **protocols only** (e.g. `AgentRosterRepository`).
  Concrete implementations live in `Data/Repositories` — see "Live backend"
  below for which kind to actually build.
- Domain models get DocC comments answering: what real-world entity/event is
  this, and what business rule governs it. See `AgentState.swift` and
  `PermissionRequestUrgency.swift` for the expected style.

Folders under `TIAGA/TIAGA/` use Xcode's file-system-synchronized groups —
just add/move files on disk, no `.pbxproj` editing needed. Empty layer folders
currently hold a `.gitkeep`; delete it the moment real content lands there.

## Live backend: real everywhere except Xcode Previews

**Every repository has (or will have) two implementations — `Fake*Repository`
(fixture-backed, no network) and `Remote*Repository` (the real backend at
`https://tiaga.tech`) — and which one gets constructed depends on *where the
app is running*, not a manual toggle:**

- **Xcode Previews (the SwiftUI canvas)** always use `Fake*Repository`.
  Previews re-render constantly and must stay fast, offline, and
  deterministic — they must never touch the network, depend on connectivity,
  or mutate a real account. Detect Preview context with
  `ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"`.
- **The running app — Simulator or a real device — uses `Remote*Repository`.**
  This is a real product; the operator wants to sign in with their real
  account and see their real fleet, not a canned demo, when actually running
  the app.

This is a deliberate reversal of the original policy (fixture-backed
*everywhere*, always — see TODO.md's Section 5 revision note and this file's
own git history for that reasoning and when it changed). The risk that
motivated the original policy hasn't gone away, it's just now accepted
rather than avoided: TIAGA dispatches persistent AI agents onto real
machines, so once a feature area's `Remote*Repository` exists, a chat
message, a permission approval, or a process kill sent from the app running
on Simulator/device is **real** — real LLM cost, real chat history, in the
worst case a real agent doing something destructive on a real machine. There
is no "just testing" mode on the live backend. Be deliberate exploring a
live-wired screen manually. That exact risk is why Previews stay on fake
data unconditionally, with no override.

What this means in practice:
- `Domain/Repositories` protocols are unchanged by this — a View/ViewModel/
  Use Case never knows or cares which concrete repository it's talking to.
- Each ViewModel's repository parameter should default based on the
  Preview-context check above (Preview → `Fake*Repository`, else →
  `Remote*Repository`), not hardcode `Fake*Repository` the way every
  ViewModel currently does — that hardcoding is exactly what needs to change
  as each feature area's `Remote*Repository` gets built.
- `TIAGAAPIClient`/`TIAGAEventStream`/`SessionCookieStore` (Section 2) are
  the transport layer every `Remote*Repository` is built on.
- **Building a `Remote*Repository` is its own, separate piece of work per
  feature area** — this section records the *decision*, not a claim that
  every `Remote*Repository` already exists. Check TODO.md for which ones
  are actually built before assuming a screen is live. As of this writing:
  `RemoteAuthSessionRepository` is done (Login, Waitlist Gate, session
  restore, logout all talk to the real backend outside Previews); Chat,
  Agent Chat, Devices, Permissions, and Settings still default to
  `Fake*Repository` everywhere, unconditionally.
- Unit tests are unaffected either way: every Use Case test runs against a
  purpose-built fake constructed directly in the test file, regardless of
  what the running app defaults to.
- **"Fixture-backed" still means plain Swift values held in memory** for
  whichever `Fake*Repository` remains in play (every Preview, and any
  feature area not yet wired live) — an array of `Device`/`Agent`/
  `ChatMessage` literals inside the fake's init, nothing else. No SQLite, no
  local database, no JSON fixture files on disk.
- Two flavors of fake, both fine, pick whichever makes a given test/screen
  clearest:
  - The `Data/Repositories/Fake*Repository.swift` used by **Previews and
    any not-yet-live feature** carries richer demo data — several devices,
    agents spanning every state — so there's something to actually look at.
  - A **Use Case unit test** often wants a smaller, purpose-built fake
    constructed right in the test file instead (see `MockURLDataSession` in
    `APIClientTests.swift` for the pattern) — just the one device/agent in
    exactly the state that scenario needs, so the test is precise and easy
    to read. Same protocol, deliberately thinner data.

## Design system — no hardcoded design values, ever

Every color, spacing value, corner radius, and font in a View must come from
a token in `TIAGA/TIAGA/DesignSystem/`:

**The app is dark-only**, matching the real TIAGA web client's actual visual
identity — not an invented light theme. Ground every token in the real
product's code, specifically **`web/` (v1), not `web-v2/`** — v1 is the
"glass" aesthetic (near-black canvas, translucent blurred panels, `Inter`,
Tailwind's default palette) that's actually shipping; v2's flat canvas/ink/
accent CSS variables are a different, unrelated visual direction. When in
doubt, grep `web/src/components/*.tsx` for the real Tailwind classes before
picking a value.

- `TIAGAColor` — semantic tokens backed by `Assets.xcassets/Colors/*.colorset`
  (single-appearance, no light variant). Sourced from v1: background `#05070d`
  (`App.tsx`), surfaces as translucent white (`--glass-bg: rgba(255,255,255,.05)`,
  `border-white/10`), brand accent Tailwind blue-500 `#3b82f6` (primary
  buttons, the switch-on state), status colors emerald-400/amber-400/red-500/
  sky-300. Notably **offline is `statusDanger` (red), not a neutral color** —
  that's the real product's own choice (`DevicesPane.tsx`), not a mistake to
  "fix". Includes domain-state mappings (`forAgentState`, `forDevicePresence`,
  `forPermissionUrgency`, `forContextUsage`) so a state enum, not a raw color,
  decides what an operator sees.
- `TIAGASpacing` — 4pt-based scale (`xs` … `xxxl`).
- `TIAGARadius` — corner radius scale (`xs` … `xl`, plus `pill`).
- `TIAGATypography` — Dynamic-Type-based font tokens, including a monospaced
  `command` token for showing shell commands/diffs on approval cards.
- Glass panels (`TIAGACard`, `ChatComposerBar`) use a real SwiftUI `Material`
  (`.ultraThinMaterial`) for the blur, not a flat color — that's the native
  equivalent of the web client's `backdrop-blur-xl` `.glass` class. Flat
  translucent fills (`TIAGAColor.surface`/`surfaceElevated`) are for small
  chips/badges that aren't blurred in the real product either (status pills,
  meter tracks).

**Interactive controls use native Liquid Glass (iOS 26 SDK), not a hand-rolled
approximation** — `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)` for
buttons, `.glassEffect(in:)` for a standalone glass shape, `GlassEffectContainer`
to let nearby glass elements blend/merge correctly with each other. Lessons
from getting the side menu wrong on the first few passes:
- Liquid Glass is a material for **floating controls**, not backgrounds.
  `.glassEffect()` on a whole panel merges every button's own glass into one
  flat surface (only real system chrome — a toolbar — will look "native" by
  comparison). Give the panel itself a plain/solid background and reserve
  `.glassEffect()`/`.buttonStyle(.glass)` for the actual controls sitting on it.
- A small icon-only glass button (a close "X") needs an explicit fixed frame
  (e.g. `.frame(width: 36, height: 36)`) and `.buttonBorderShape(.circle)` to
  render as a proper circle with the same shimmer quality as other glass
  controls — without it, it's sized to just the glyph and looks flat.
- `.tint()` alone does not visually distinguish a "selected" glass button —
  `.buttonStyle(.glass)` stays visually neutral regardless of tint. Use
  `.buttonStyle(.glassProminent)` (+ `.tint()`) for the selected/active state
  and plain `.buttonStyle(.glass)` for the rest, branched with an `if` inside
  the view (both arms return `some View` under the implicit `@ViewBuilder`).
- A custom `Button` label needs `.frame(maxWidth: .infinity, alignment: .leading)`
  **and** `.contentShape(_:)` or only the glyphs (text/icon) are tappable —
  the whitespace in the row is not part of the hit area by default.
- A static screenshot cannot verify Liquid Glass's dynamic specular highlight
  (it responds to motion/interaction, not a still frame) — say so explicitly
  rather than claiming a screenshot confirms it "looks native"; that needs
  the user's own eyes on the running simulator.
- **Don't conditionally insert/remove Liquid Glass content with `if` +
  `.transition()` for a custom overlay (a drawer, a modal) — it does not
  reliably animate on removal**, likely because `GlassEffectContainer`'s own
  rendering pass tears its content down immediately when removed from the
  hierarchy instead of participating in the transition like an ordinary view.
  This cost two rounds of debugging on the side menu: the drawer opened
  with an animation but closed instantly, because the scrim/drawer were
  wrapped in `if isSideMenuOpen { ... }`. The fix that actually worked: keep
  the overlay's content **always present** in the view hierarchy, and drive
  visibility by directly animating `opacity` and `offset` (core `Animatable`
  properties SwiftUI handles reliably regardless of what's rendering inside)
  instead of relying on insertion/removal at all. Pair with
  `.allowsHitTesting(isOpen)` so the always-present, off-screen/invisible
  content doesn't intercept touches when "closed". Apply this same pattern
  to any future custom overlay with glass content (e.g. the Permissions
  approval overlay, Section 8) — don't rediscover it from scratch.

Never write `Color(red:green:blue:)`, a raw hex, a bare `.font(.system(size:))`,
or a bare numeric literal in `.padding()` / `.cornerRadius()` inside a View.
If a token you need doesn't exist yet, add it to the relevant `DesignSystem`
file (and a colorset if it's a color) rather than inlining a value.

## Error handling philosophy

Domain error enums are written for the stakeholder, not the developer. Every
case must answer: who hits this in the real workflow, what do they see in
plain language, and what can they do next. No "something went wrong". Follow
the `MedicationAdministrationError` shape from the assessment spec.

## Testing

Use Case tests live under `TIAGATests/`. Name tests as domain scenarios:
`test_approvePermissionRequest_fails_whenRequestHasExpired`, not `testError1`.
Minimum 8 tests across the 3+ Use Cases: happy path, boundary condition, and
each error case per Use Case.

Automated tests only cover logic — they don't catch a legibility bug like
white-on-white placeholder text.

**Before opening any PR that touches UI, take a real screenshot and look at
it** — don't just eyeball the code:
```
xcrun simctl boot <udid>                                  # once, if nothing's booted
xcodebuild -project TIAGA.xcodeproj -scheme TIAGA -sdk iphonesimulator \
  -destination 'id=<udid>' build
xcrun simctl install booted <path-to-.app-in-DerivedData>
xcrun simctl launch booted com.tiaga.TIAGA
xcrun simctl io booted screenshot <path>.png               # then Read the png
```
This catches what a build/test pass can't: contrast, sizing, an element that's
missing or in the wrong place, a token that renders differently than expected.
`simctl` can't tap or type, so on its own it only reaches whatever screen the
app lands on at launch. **Every screen a PR adds or changes needs its own
screenshot**, not just the launch screen — reach the others with a DEBUG-only
route override read from a launch environment variable (see
`AuthViewModel.debugRouteOverride()` for the pattern), passed via
`SIMCTL_CHILD_<VAR_NAME>=<value> xcrun simctl launch booted com.tiaga.TIAGA`.
Extend that pattern for each new feature's ViewModel rather than inventing a
different mechanism per section. It's still launch-state only — it can't
verify a multi-step *interaction* (does tapping this button actually do the
right thing) — so the **manual visual-confirmation checklist** in the PR's
test plan is still required for that and for final polish/interaction feel.
Write it as concrete, checkable claims ("Send button dims to ~30% opacity
when the composer is empty"), not "looks good".

**Every screenshot taken this way gets committed and embedded in the PR**,
not just described in prose — save it to `docs/screenshots/<descriptive-name>.png`
(outside `TIAGA/`, so it's never bundled into the app or shown in Xcode's
navigator), commit it on the same branch as the change it documents, push,
then embed it in the PR body/comment as a markdown image.

**This repo is private — use the `blob`+`?raw=true` URL, not
`raw.githubusercontent.com`:**
`https://github.com/tiaga-tech/tiaga-nexus-mobile/blob/<branch>/docs/screenshots/<name>.png?raw=true`.
`raw.githubusercontent.com` doesn't serve private-repo content without a
short-lived signed token (confirmed: it 404s even right after pushing — that
was a private-repo auth issue, not a CDN propagation delay). The `blob`
form rides the viewer's own github.com session instead, so it works for an
authenticated viewer with repo access. Neither form can be verified with an
anonymous `curl` — GitHub masks private-repo resources as 404 either way — so
after embedding, ask the user to confirm it actually renders for them rather
than assuming success.

**Lay multiple screenshots out in a grid, not stacked full-width** — a
full-device-height PNG at full column width makes the PR body absurdly tall.
Use a raw HTML table (GitHub renders HTML in PR bodies) with a `width` on
each `<img>`, a few screens per row:
```html
<table><tr>
<td><img src="...auth-login.png?raw=true" width="250"></td>
<td><img src="...auth-waitlist-gate.png?raw=true" width="250"></td>
<td><img src="...auth-authenticated-placeholder.png?raw=true" width="250"></td>
</tr></table>
```

Reuse a name across PRs when it's the same screen (the file just gets
replaced/updated) rather than accumulating `-v2`/`-v3` copies.

**If the PR changes an existing screen's UI (not just adding a new one),
show old vs. new side by side** — don't just silently overwrite the
screenshot and let the reviewer dig through the Files-changed tab. No need
for a separate `-before` file: find the commit that last touched that
screenshot (`git log -1 --format=%H -- docs/screenshots/<name>.png`, checked
*before* overwriting it) and link that SHA's blob for "before" next to the
current branch's blob for "after", in the same grid table:
```html
<table><tr>
<td align="center"><b>Before</b><br><img src="https://github.com/tiaga-tech/tiaga-nexus-mobile/blob/<old-sha>/docs/screenshots/<name>.png?raw=true" width="240"></td>
<td align="center"><b>After</b><br><img src="https://github.com/tiaga-tech/tiaga-nexus-mobile/blob/<branch>/docs/screenshots/<name>.png?raw=true" width="240"></td>
</tr></table>
```

## Git workflow

- **Never commit directly to `main`.** Every change — including docs — happens
  on its own branch (`feature/<slug>` for app features, `docs/<slug>` for
  planning/doc-only changes) and is merged to `main` only after the user has
  reviewed it.
- **Never push `main`.** Feature/docs branches may be pushed to open a PR for
  the user to review once a section's work (including its tests) is complete
  — that's the review mechanism, not a substitute for it. Never push straight
  to `main`, and never merge a PR yourself.
- **Every commit uses Conventional Commits** (`feat:`, `fix:`, `docs:`, `test:`,
  `chore:`, `refactor:`) — no exceptions, including doc-only and scaffolding
  commits.
- One feature branch at a time: finish it (including its tests), stop, wait
  for review/merge, then start the next.
- **Whenever the user says something merged, clean up immediately** —
  `git checkout main && git pull`, `git branch -d <merged-branch>` (safe
  delete; if it refuses, the branch has unmerged work — stop and check
  rather than forcing it), `git fetch --prune`. Do this without being asked
  each time.

## Current status

Sections 1–9 (Design System, API Layer, Auth, Side Menu, Chat, Agent Chat,
Devices, Permissions, Settings) are merged to `main`, plus a follow-up
unifying `ChatMessage`'s domain shape with the real backend's. The
Permissions approval overlay renders `.edit` requests as a native per-file
tab view with a real line-level diff (`PermissionEditFilesView`/
`PermissionEditDiff`), matching the web client's `EditReview`/`DiffView` —
not the backend's flattened `detail` text, which only prefixes the first
line of a multi-line change. Settings' Usage section models all three of
the real backend's mutually exclusive usage states (admin/subscribed/no
active plan), reusing `TIAGAColor.forContextUsage`'s 60%/85% thresholds
rather than a second, divergent color rule. This was the last section in
the original build plan — see `TODO.md` for each merged section's notes on
what shipped differently from the original plan, and this file's own "Live
backend" section above for what's deliberately still out of scope (no MCP
domain concept).

Live-backend wiring is now underway: `RemoteAuthSessionRepository` (Auth),
`RemoteDeviceFleetRepository` (Devices), `RemotePermissionRequestRepository`
(Permissions), and `RemoteOrchestratorConversationRepository` (Chat) all
talk to the real backend outside Xcode Previews — see `TODO.md`'s "Live
Backend Wiring" section for each one's own revision notes. Agent Chat and
Settings still default to `Fake*Repository` unconditionally; those are
separate, not-yet-started pieces of work. One deliberate deviation from the
web client: an `.active`, non-admin account with no subscription or credits
(`hasAccess: false` on `/api/auth/me`) is NOT force-routed to a billing
paywall the way the web client does — this app has no checkout flow to
route to (Settings' Billing section is read-only, web-only by design), and
Settings' Usage/Billing sections already surface "no active plan"
gracefully, so the Fleet Console just stays reachable at zero usage budget
instead.

**Real bug found and fixed post-merge**: `RemoteEventBus` (the shared
`/api/events` SSE multiplexer every live repository above subscribes
through) opened one connection for the whole process's lifetime and never
re-read the session cookie once live. Logging out and into a different
account without restarting the app left that connection permanently bound
to whichever account first opened it — every subsequent account's Chat/
Devices/Permissions screens looked "connected" but silently received
nothing live (regular REST calls were unaffected, since those pick up the
current cookie per request). Fixed with `RemoteEventBus.disconnect()`,
called from `RemoteAuthSessionRepository.logout()`, so the next login opens
a fresh connection bound to whatever account is now signed in. Verified
against a real repeated logout/relogin cycle across two accounts.

## Assessment context (for reference — full spec given by the user)

This repo is graded against: Domain-Centred Architecture (semantic models,
OOP/protocol-oriented design, a required Use Case layer), a SwiftUI UI in
domain language (min. 4 screens), human-centred error handling, ≥8 domain-named
unit tests, a Human-System Architecture diagram, Git history with Conventional
Commits, and a 600–800 word reflective report. Don't build ahead of what's
been asked — this file exists so each incremental addition stays consistent
with the whole, not so everything gets built at once.
