//
//  DesignSystemTests.swift
//  TIAGATests
//

import Testing
@testable import TIAGA

struct DesignSystemTests {

    @Test func test_forContextUsage_returnsSuccessColor_belowSixtyPercent() {
        #expect(TIAGAColor.forContextUsage(percentage: 0.59) == TIAGAColor.statusSuccess)
    }

    @Test func test_forContextUsage_returnsWarningColor_atSixtyPercentBoundary() {
        #expect(TIAGAColor.forContextUsage(percentage: 0.60) == TIAGAColor.statusWarning)
    }

    @Test func test_forContextUsage_returnsDangerColor_atEightyFivePercent() {
        #expect(TIAGAColor.forContextUsage(percentage: 0.85) == TIAGAColor.statusDanger)
    }

    @Test func test_forAgentState_mapsCompactingToCompactingColor() {
        #expect(TIAGAColor.forAgentState(.compacting) == TIAGAColor.statusCompacting)
    }
}
