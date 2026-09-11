//
//  DeviceIdentifier.swift
//  TIAGA
//

import Foundation

/// A stable identifier for a device running the TIAGA harness. Defined here,
/// ahead of the full `Device` model (added when the Devices feature lands),
/// since `Agent` needs to reference the device it's pinned to.
struct DeviceIdentifier: Hashable, Equatable, CustomStringConvertible {
    let rawValue: String
    var description: String { rawValue }
}
