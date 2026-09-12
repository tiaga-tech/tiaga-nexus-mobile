//
//  DevicesViewModel.swift
//  TIAGA
//

import Combine
import Foundation
import SwiftUI

/// Drives the Devices screen: the fleet list, and toggling each device's
/// approval-gating on/off.
@MainActor
final class DevicesViewModel: ObservableObject {
    @Published private(set) var devices: [Device] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var toggleErrorMessage: String?
    @Published private(set) var isLoading = false

    private let observeDeviceFleetUseCase: ObserveDeviceFleetUseCase
    private let toggleDevicePermissionsUseCase: ToggleDevicePermissionsUseCase

    init(deviceFleetRepository: DeviceFleetRepository? = nil) {
        // Fake*Repository only inside Xcode Previews — everywhere else
        // (Simulator or a real device) talks to the real backend. See
        // AGENTS.md's "Live backend" policy.
        let repository = deviceFleetRepository ?? (
            ProcessInfo.isRunningInXcodePreview ? FakeDeviceFleetRepository() : RemoteDeviceFleetRepository()
        )
        self.observeDeviceFleetUseCase = ObserveDeviceFleetUseCase(repository: repository)
        self.toggleDevicePermissionsUseCase = ToggleDevicePermissionsUseCase(repository: repository)
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await observeDeviceFleetUseCase.execute()
            withAnimation(.easeInOut(duration: 0.2)) {
                devices = result
            }
        } catch let error as DeviceFleetError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = DeviceFleetError.fleetUnreachable.errorDescription
        }
    }

    func togglePermissionsRequired(for device: Device) async {
        toggleErrorMessage = nil
        do {
            try await toggleDevicePermissionsUseCase.execute(
                deviceID: device.id,
                permissionsRequired: !device.permissionsRequired
            )
            await load()
        } catch let error as DevicePermissionsError {
            toggleErrorMessage = error.errorDescription
        } catch {
            toggleErrorMessage = DevicePermissionsError.deviceNoLongerExists.errorDescription
        }
    }
}
