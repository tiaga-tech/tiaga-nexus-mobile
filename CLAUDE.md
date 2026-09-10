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
build it to the standard the real product deserves (real backend contracts,
real auth, the actual TIAGA account/billing model), and treat the assessment
rubric (DocC comments, the Use Case layer, named tests, the reflective report)
as documentation discipline the product should have anyway, not busywork
bolted on for a grade.

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
  Concrete implementations (REST/WebSocket clients against the TIAGA backend,
  or fakes for tests) live in `Data/Repositories`.
- Domain models get DocC comments answering: what real-world entity/event is
  this, and what business rule governs it. See `AgentState.swift` and
  `PermissionRequestUrgency.swift` for the expected style.

Folders under `TIAGA/TIAGA/` use Xcode's file-system-synchronized groups —
just add/move files on disk, no `.pbxproj` editing needed. Empty layer folders
currently hold a `.gitkeep`; delete it the moment real content lands there.

## Design system — no hardcoded design values, ever

Every color, spacing value, corner radius, and font in a View must come from
a token in `TIAGA/TIAGA/DesignSystem/`:

- `TIAGAColor` — semantic tokens backed by `Assets.xcassets/Colors/*.colorset`
  (each has light + dark variants; the brand palette is TIAGA's real palette —
  see the colorset values, sourced from `web-v2/src/index.css` in the parent
  repo). Includes domain-state mappings (`forAgentState`, `forDevicePresence`,
  `forPermissionUrgency`) so a state enum, not a raw color, decides what an
  operator sees.
- `TIAGASpacing` — 4pt-based scale (`xs` … `xxxl`).
- `TIAGARadius` — corner radius scale (`xs` … `xl`, plus `pill`).
- `TIAGATypography` — Dynamic-Type-based font tokens, including a monospaced
  `command` token for showing shell commands/diffs on approval cards.

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
