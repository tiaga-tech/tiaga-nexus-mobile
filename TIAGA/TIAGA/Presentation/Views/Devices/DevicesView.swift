//
//  DevicesView.swift
//  TIAGA
//

import SwiftUI

/// The operator's fleet: one row per device — OS icon, name, online/offline
/// status, and a tappable pill to switch approval-gating on/off for
/// sensitive tools (matching the real web client's `permissions on`/`auto`
/// pill in `DevicesPane.tsx`, worded here as "Permissions: On"/"Off").
struct DevicesView: View {
    @StateObject private var viewModel = DevicesViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(TIAGATypography.subheadline)
                        .foregroundStyle(TIAGAColor.statusDanger)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(TIAGASpacing.lg)
                } else if viewModel.devices.isEmpty {
                    Text(viewModel.isLoading ? "" : "No devices yet.")
                        .font(TIAGATypography.subheadline)
                        .foregroundStyle(TIAGAColor.textTertiary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: TIAGASpacing.sm) {
                            if let message = viewModel.toggleErrorMessage {
                                Text(message)
                                    .font(TIAGATypography.caption)
                                    .foregroundStyle(TIAGAColor.statusDanger)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            ForEach(viewModel.devices) { device in
                                DeviceRow(device: device) {
                                    Task { await viewModel.togglePermissionsRequired(for: device) }
                                }
                            }
                        }
                        .padding(TIAGASpacing.lg)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(TIAGAColor.background)
            .navigationTitle("Devices")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await viewModel.load() }
    }
}

private struct DeviceRow: View {
    let device: Device
    let onTogglePermissions: () -> Void

    var body: some View {
        TIAGACard {
            HStack(spacing: TIAGASpacing.md) {
                Image(systemName: TIAGAIcon.forDeviceType(device.type))
                    .foregroundStyle(device.isOnline ? TIAGAColor.textPrimary : TIAGAColor.textTertiary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: TIAGASpacing.xs) {
                    Text(device.name)
                        .font(TIAGATypography.body)
                        .foregroundStyle(device.isOnline ? TIAGAColor.textPrimary : TIAGAColor.textTertiary)

                    Button(action: onTogglePermissions) {
                        HStack(spacing: TIAGASpacing.xs) {
                            Circle()
                                .fill(device.permissionsRequired ? TIAGAColor.statusSuccess : TIAGAColor.statusWarning)
                                .frame(width: 6, height: 6)
                            Text("Permissions: \(device.permissionsRequired ? "On" : "Off")")
                                .font(TIAGATypography.caption)
                                .foregroundStyle(device.permissionsRequired ? TIAGAColor.statusSuccess : TIAGAColor.statusWarning)
                        }
                        .padding(.horizontal, TIAGASpacing.sm)
                        .padding(.vertical, TIAGASpacing.xs)
                        .background(
                            (device.permissionsRequired ? TIAGAColor.statusSuccess : TIAGAColor.statusWarning).opacity(0.15)
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: TIAGASpacing.sm)

                StatusPill(isOnline: device.isOnline)
            }
        }
    }
}

#Preview {
    DevicesView()
}
