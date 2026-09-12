//
//  PrivacyPreference.swift
//  TIAGA
//

import Foundation

/// The operator's one privacy switch (`PrivacyPanel.tsx`): whether TIAGA's
/// AI partners may use their conversations to improve their models.
///
/// Business rule: turning this off only stops *future* collection — it is
/// not a request to delete conversations already used for training, and
/// this app must never imply otherwise in its copy or behavior. The real
/// backend also warns that turning it off can burn through usage allowance
/// faster (presumably by losing access to a cheaper/subsidized inference
/// path) — that warning is carried verbatim in `SettingsView`, not filler
/// text.
///
/// Note for a future `Remote*Repository`: the wire field is the inverse of
/// this, `trainingOptOut` (`api.ts`) — `improveAIEnabled == !trainingOptOut`.
struct PrivacyPreference: Equatable, Sendable {
    var improveAIEnabled: Bool
}
