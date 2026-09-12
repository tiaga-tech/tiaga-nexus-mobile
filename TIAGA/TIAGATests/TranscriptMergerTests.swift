//
//  TranscriptMergerTests.swift
//  TIAGATests
//

import Foundation
import Testing
@testable import TIAGA

struct TranscriptMergerTests {

    @Test func test_transcriptMerge_ordersMessagesAndToolUsageChronologically() {
        let earlyMessage = ChatMessage(
            role: .orchestrator,
            text: "early message",
            sentAt: Date(timeIntervalSince1970: 100)
        )
        let toolBetween = ToolUsageEvent(
            toolName: "bash",
            targetDevice: DeviceIdentifier(rawValue: "device-home-pc"),
            summary: "bash: xcodebuild build",
            occurredAt: Date(timeIntervalSince1970: 110)
        )
        let lateMessage = ChatMessage(
            role: .operator,
            text: "late message",
            sentAt: Date(timeIntervalSince1970: 120)
        )

        let result = TranscriptMerger.merge(
            messages: [lateMessage, earlyMessage],
            toolUsageEvents: [toolBetween]
        )

        #expect(result.count == 3)
        #expect(result.map(\.occurredAt) == [
            Date(timeIntervalSince1970: 100),
            Date(timeIntervalSince1970: 110),
            Date(timeIntervalSince1970: 120),
        ])

        guard case .message(let first) = result[0],
              case .toolUsage(let second) = result[1],
              case .message(let third) = result[2] else {
            Issue.record("Expected message, tool usage, message order.")
            return
        }
        #expect(first.text == "early message")
        #expect(second.toolName == "bash")
        #expect(third.text == "late message")
    }
}
