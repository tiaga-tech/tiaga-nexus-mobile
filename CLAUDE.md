# CLAUDE.md — TIAGA Mobile (Fleet Operations Console)

This file orients any Claude Code session working in this repo. Read it before
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
actually talks to it live (see "Testing safety: no live backend" below).
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
  - **PermissionRequest** — an approval prompt raised when an agent on a
    protected device wants to run a sensitive tool (`bash`, `write`, `edit`,
    `run_app`, `kill_process`). Shows the exact command or an old/new diff.
    Auto-denies if unanswered for 5 minutes. See `PermissionRequestUrgency`.
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
  Concrete implementations live in `Data/Repositories` — see "Testing safety:
  no live backend" below for which kind to actually build.
- Domain models get DocC comments answering: what real-world entity/event is
  this, and what business rule governs it. See `AgentState.swift` and
  `PermissionRequestUrgency.swift` for the expected style.

Folders under `TIAGA/TIAGA/` use Xcode's file-system-synchronized groups —
just add/move files on disk, no `.pbxproj` editing needed. Empty layer folders
currently hold a `.gitkeep`; delete it the moment real content lands there.

## Testing safety: no live backend

**Every `Data/Repositories` implementation in this app is `Fake*Repository`,
fixture-backed, no network calls — never `Remote*Repository` wired into the
running app.** This isn't a placeholder to "finish later"; it's a deliberate
decision.

Why: TIAGA isn't a toy backend. The real product dispatches persistent AI
agents onto real machines, and a chat message, a permission approval, or a
process kill sent from this app would be real — real LLM cost, real chat
history on a real account, and in the worst case a real agent doing something
destructive on a real machine, all triggered by what was meant to be casual
UI testing. There is no "just testing" mode on the live backend.

What this means in practice:
- Every `Fake*Repository` uses deterministic, hardcoded/generated fixture
  data — enough variety to exercise every state a Use Case or View needs
  (online/offline devices, every `AgentState`, an about-to-expire permission
  request, a rate-limited login, etc.), plus an injectable failure mode where
  a test needs one (e.g. `fleetUnreachable`).
- `TIAGAAPIClient`/`TIAGAEventStream`/`SessionCookieStore` (Section 2) still
  exist as correct, tested transport-layer plumbing — they demonstrate the
  real backend contract, which matters for this being a real product, not a
  toy — but nothing in the app actually constructs one against
  `https://tiaga.tech`. Don't wire one in without being explicitly asked to.
- Unit tests already follow this by construction: every Use Case test runs
  against a `Fake*Repository`, never a live network call.
- **"Fixture-backed" means plain Swift values held in memory** — an array of
  `Device`/`Agent`/`ChatMessage` literals inside the fake's init, nothing
  else. No SQLite, no local database, no JSON fixture files on disk. A
  chatbot reply from `FakeOrchestratorConversationRepository` is a hardcoded
  `ChatMessage` value in that file, not fetched or generated from anything.
- Two flavors of fake, both fine, pick whichever makes a given test/screen
  clearest:
  - The `Data/Repositories/Fake*Repository.swift` used by the **running
    app** (what you see when manually exploring the simulator) carries
    richer demo data — several devices, agents spanning every state — so
    there's something to actually look at.
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
It's a static, launch-state check only — `simctl` can't tap or type, so it
can't drive a multi-step flow (log in → land on a specific screen → open a
sheet). For that, and for final polish/interaction feel, the **manual
visual-confirmation checklist** in the PR's test plan is still required: one
line per thing that needs a human driving it (each visually distinct state —
loading/empty/error, a full interactive flow, anything the static screenshot
pass didn't already cover). Write it as concrete, checkable claims ("Send
button dims to ~30% opacity when the composer is empty"), not "looks good".

**Every screenshot taken this way gets committed and embedded in the PR**,
not just described in prose — save it to `docs/screenshots/<descriptive-name>.png`
(outside `TIAGA/`, so it's never bundled into the app or shown in Xcode's
navigator), commit it on the same branch as the change it documents, push,
then embed it in the PR body/comment as a markdown image using the raw CDN
URL: `https://raw.githubusercontent.com/tiaga-tech/tiaga-nexus-mobile/<branch>/docs/screenshots/<name>.png`.
Reuse a name across PRs when it's the same screen (the file just gets
replaced/updated) rather than accumulating `-v2`/`-v3` copies.

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

## Current status

Clean slate — `main` holds only the empty Xcode project shell (no app target
files). Planning docs (`CLAUDE.md`, `TODO.md`) exist on `docs/initial-planning`,
not yet merged. Nothing else has been built. See `TODO.md` for the ordered,
checkbox-tracked build plan (one feature branch at a time, merged to `main`
before the next starts) — start at Section 1.

## Assessment context (for reference — full spec given by the user)

This repo is graded against: Domain-Centred Architecture (semantic models,
OOP/protocol-oriented design, a required Use Case layer), a SwiftUI UI in
domain language (min. 4 screens), human-centred error handling, ≥8 domain-named
unit tests, a Human-System Architecture diagram, Git history with Conventional
Commits, and a 600–800 word reflective report. Don't build ahead of what's
been asked — this file exists so each incremental addition stays consistent
with the whole, not so everything gets built at once.
