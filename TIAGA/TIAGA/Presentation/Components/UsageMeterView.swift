//
//  UsageMeterView.swift
//  TIAGA
//

import SwiftUI

/// A labelled percentage bar for one usage window (session or weekly),
/// matching the web client's `Meter` (`UsagePanel.tsx`)/`ContextBar.tsx` —
/// both use the same 60%/85% color thresholds, so this reuses
/// `TIAGAColor.forContextUsage` rather than a second copy of that rule.
struct UsageMeterView: View {
    let label: String
    /// 0...100 — already a percentage, not a 0...1 fraction (matches the
    /// wire and `SubscriptionUsage`).
    let percentage: Double
    let resetsAt: Date?

    private var clamped: Double { min(100, max(0, percentage.rounded())) }

    var body: some View {
        VStack(alignment: .leading, spacing: TIAGASpacing.xs) {
            HStack {
                Text(label)
                    .font(TIAGATypography.caption)
                    .foregroundStyle(TIAGAColor.textSecondary)
                Spacer()
                Text("\(Int(clamped))%")
                    .font(TIAGATypography.caption)
                    .foregroundStyle(TIAGAColor.textSecondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(TIAGAColor.surface)
                    Capsule()
                        .fill(TIAGAColor.forContextUsage(percentage: clamped / 100))
                        .frame(width: geometry.size.width * (clamped / 100))
                }
            }
            .frame(height: 6)

            if clamped > 0, let resetText = Self.resetText(resetsAt) {
                Text(resetText)
                    .font(TIAGATypography.caption)
                    .foregroundStyle(TIAGAColor.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    /// "Resets by 4:32 PM" today, or "Resets by Mon, Sep 15, 4:32 PM" for a
    /// later day — matches `UsagePanel.tsx`'s `resetText`: a bare weekday
    /// would read as *this* coming occurrence when the weekly window can
    /// reset up to 7 days out, so a later reset always includes the date.
    private static func resetText(_ date: Date?) -> String? {
        guard let date, date > Date() else { return nil }
        let timeStyle = Date.FormatStyle.dateTime.hour().minute()
        if Calendar.current.isDateInToday(date) {
            return "Resets by \(date.formatted(timeStyle))"
        }
        let dateStyle = Date.FormatStyle.dateTime.weekday(.abbreviated).month(.abbreviated).day()
        return "Resets by \(date.formatted(dateStyle)), \(date.formatted(timeStyle))"
    }
}

#Preview {
    VStack(spacing: TIAGASpacing.lg) {
        UsageMeterView(label: "This session", percentage: 42, resetsAt: Date().addingTimeInterval(2 * 3600))
        UsageMeterView(label: "This week", percentage: 68, resetsAt: Date().addingTimeInterval(4 * 86400))
        UsageMeterView(label: "Near limit", percentage: 92, resetsAt: nil)
    }
    .padding()
    .background(TIAGAColor.background)
}
