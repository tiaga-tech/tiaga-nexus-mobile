//
//  PermissionEditFilesView.swift
//  TIAGA
//

import SwiftUI

/// Per-file view for an `.edit` permission request, mirroring the web
/// client's `EditReview`/`FileLabel`: a tab per file when there's more than
/// one (basename + edit count), the active file's full path shown as a
/// label, then that file's edits as line-level diffs. Embedding the file
/// path as a plain line inside the same code block (an earlier pass here)
/// read as more code, not a label — native SwiftUI chrome for the path and
/// tabs, separate from the code surface, is what actually makes it legible.
struct PermissionEditFilesView: View {
    let files: [PermissionRequestFile]
    @State private var selectedIndex = 0

    private var activeFile: PermissionRequestFile {
        files[min(selectedIndex, files.count - 1)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TIAGASpacing.sm) {
            if files.count > 1 {
                // Matches the web client's tab row (`overflow-x-auto`) — enough
                // files (long paths especially) will overflow the card's width,
                // so this has to scroll rather than wrap or get clipped.
                ScrollView(.horizontal, showsIndicators: false) {
                    GlassEffectContainer {
                        HStack(spacing: TIAGASpacing.xs) {
                            ForEach(Array(files.enumerated()), id: \.offset) { index, file in
                                tab(file: file, isSelected: index == selectedIndex) {
                                    selectedIndex = index
                                }
                            }
                        }
                    }
                }
            }

            fileLabel(activeFile)

            ScrollView {
                VStack(alignment: .leading, spacing: TIAGASpacing.sm) {
                    ForEach(Array(activeFile.edits.enumerated()), id: \.offset) { _, edit in
                        let diffText = PermissionEditDiff.unifiedText(old: edit.old, new: edit.new)
                        let lineCount = diffText.components(separatedBy: "\n").count
                        HighlightedCodeView(code: diffText, language: "diff")
                            .frame(
                                maxWidth: .infinity,
                                minHeight: HighlightedCodeView.estimatedHeight(forLineCount: lineCount),
                                alignment: .leading
                            )
                            .background(TIAGAColor.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: TIAGARadius.sm, style: .continuous))
                    }
                }
            }
        }
    }

    private func tab(file: PermissionRequestFile, isSelected: Bool, action: @escaping () -> Void) -> some View {
        // .tint() alone doesn't make a plain `.glass` button look selected —
        // the glass *fill* itself needs the prominent variant (see
        // SideMenuRow for the same lesson with the drawer's route rows).
        Group {
            if isSelected {
                tabLabel(file, action: action).buttonStyle(.glassProminent).tint(TIAGAColor.brandAccent)
            } else {
                tabLabel(file, action: action).buttonStyle(.glass)
            }
        }
    }

    private func tabLabel(_ file: PermissionRequestFile, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: TIAGASpacing.xs) {
                Text(basename(file.path))
                Text("·\(file.edits.count)")
                    .foregroundStyle(TIAGAColor.textTertiary)
            }
            .font(TIAGATypography.commandCaption)
            .padding(.horizontal, TIAGASpacing.sm)
            .padding(.vertical, TIAGASpacing.xs)
        }
    }

    private func fileLabel(_ file: PermissionRequestFile) -> some View {
        HStack(spacing: TIAGASpacing.xs) {
            Text(file.path)
                .font(TIAGATypography.commandCaption)
                .foregroundStyle(TIAGAColor.textSecondary)
                .lineLimit(1)
                .truncationMode(.head)
            Text("· \(file.edits.count) edit\(file.edits.count == 1 ? "" : "s")")
                .font(TIAGATypography.caption)
                .foregroundStyle(TIAGAColor.textTertiary)
        }
    }

    private func basename(_ path: String) -> String {
        path.split(separator: "/").last.map(String.init) ?? path
    }
}

#Preview {
    ZStack {
        TIAGAColor.background.ignoresSafeArea()
        PermissionEditFilesView(files: [
            PermissionRequestFile(
                path: "web/src/App.tsx",
                edits: [
                    PermissionRequestEdit(
                        old: "const config = {\n  theme: 'light',\n  debug: false,\n  timeout: 3000\n}",
                        new: "const config = {\n  theme: 'dark',\n  debug: true,\n  timeout: 5000\n}"
                    ),
                ]
            ),
            PermissionRequestFile(
                path: "web/src/utils.ts",
                edits: [
                    PermissionRequestEdit(old: "export const VERSION = '1.0.0'", new: "export const VERSION = '1.1.0'"),
                ]
            ),
        ])
        .padding(TIAGASpacing.lg)
    }
}
