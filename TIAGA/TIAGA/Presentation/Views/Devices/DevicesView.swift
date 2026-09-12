//
//  DevicesView.swift
//  TIAGA
//

import SwiftUI

/// The operator's fleet: one row per device — OS icon, name, online/offline
/// status, and a native switch for whether sensitive tools on that device
/// require approval (the real web client uses a custom tappable pill for
/// this in `DevicesPane.tsx`; a native `Toggle` is the right iOS-native
/// equivalent of the same control, not a literal pixel match).
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
            VStack(spacing: TIAGASpacing.sm) {
                HStack(spacing: TIAGASpacing.md) {
                    Image(systemName: TIAGAIcon.forDeviceType(device.type))
                        .foregroundStyle(device.isOnline ? TIAGAColor.textPrimary : TIAGAColor.textTertiary)
                        .frame(width: 24)

                    Text(device.name)
                        .font(TIAGATypography.body)
                        .foregroundStyle(device.isOnline ? TIAGAColor.textPrimary : TIAGAColor.textTertiary)

                    Spacer(minLength: TIAGASpacing.sm)

                    StatusPill(isOnline: device.isOnline)
                }

                Divider().overlay(TIAGAColor.border)

                Toggle(isOn: Binding(
                    get: { device.permissionsRequired },
                    set: { _ in onTogglePermissions() }
                )) {
                    Text("Permissions enabled")
                        .font(TIAGATypography.subheadline)
                        .foregroundStyle(TIAGAColor.textSecondary)
                }
                .tint(TIAGAColor.brandAccent)
            }
        }
    }
}

#Preview {
    DevicesView()
}
