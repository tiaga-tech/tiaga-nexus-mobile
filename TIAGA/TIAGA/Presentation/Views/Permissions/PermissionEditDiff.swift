//
//  PermissionEditDiff.swift
//  TIAGA
//

import Foundation

/// Builds a line-level diff between an edit's `old`/`new` text, matching the
/// web client's `DiffView.tsx` — which runs an actual `diffLines(old, new)`
/// and colors every resulting row. `PermissionManager.cs`'s `DescribeEdit`
/// builds a flattened `detail` string instead, but only prefixes the first
/// line of a multi-line change (a quirk of its own string concatenation) —
/// that flattened text is a plain-text summary field on the wire, not what
/// the web client's interactive overlay actually renders for an edit
/// request, so this app renders from `PermissionRequest.files` instead.
enum PermissionEditDiff {
    struct Line: Equatable {
        let sign: Character
        let text: String
    }

    /// Longest-common-subsequence line diff (old → new). Small blocks only
    /// (a permission request's edits are a few lines), so a plain O(n·m)
    /// DP table is more than fast enough — no need for Myers' algorithm.
    static func lines(old: String, new: String) -> [Line] {
        let oldLines = old.components(separatedBy: "\n")
        let newLines = new.components(separatedBy: "\n")
        let n = oldLines.count
        let m = newLines.count

        var lcs = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                if oldLines[i] == newLines[j] {
                    lcs[i][j] = lcs[i + 1][j + 1] + 1
                } else {
                    lcs[i][j] = max(lcs[i + 1][j], lcs[i][j + 1])
                }
            }
        }

        var result: [Line] = []
        var i = 0, j = 0
        while i < n && j < m {
            if oldLines[i] == newLines[j] {
                result.append(Line(sign: " ", text: oldLines[i]))
                i += 1
                j += 1
            } else if lcs[i + 1][j] >= lcs[i][j + 1] {
                result.append(Line(sign: "-", text: oldLines[i]))
                i += 1
            } else {
                result.append(Line(sign: "+", text: newLines[j]))
                j += 1
            }
        }
        while i < n { result.append(Line(sign: "-", text: oldLines[i])); i += 1 }
        while j < m { result.append(Line(sign: "+", text: newLines[j])); j += 1 }
        return result
    }

    /// Renders as unified-diff text so the vendored highlight.js "diff"
    /// grammar paints a full-line background on every changed row, not just
    /// a hand-picked first line.
    static func unifiedText(old: String, new: String) -> String {
        lines(old: old, new: new)
            .map { "\($0.sign) \($0.text)" }
            .joined(separator: "\n")
    }

    /// One block per file — its path as a plain header line (unstyled by
    /// the diff grammar, so it reads as a label) followed by that file's
    /// edits, each as unified-diff text. Blank line between files.
    static func unifiedText(files: [PermissionRequestFile]) -> String {
        files.map { file in
            let diffs = file.edits
                .map { unifiedText(old: $0.old, new: $0.new) }
                .joined(separator: "\n")
            return "\(file.path)\n\(diffs)"
        }.joined(separator: "\n\n")
    }
}
