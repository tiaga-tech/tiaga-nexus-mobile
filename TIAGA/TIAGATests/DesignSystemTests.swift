//
//  DesignSystemTests.swift
//  TIAGATests
//

import Testing
@testable import TIAGA

struct DesignSystemTests {

    @Test func test_forContextUsage_returnsSuccessColor_belowSeventyFivePercent() {
        #expect(TIAGAColor.forContextUsage(percentage: 0.74) == TIAGAColor.statusSuccess)
    }

    @Test func test_forContextUsage_returnsWarningColor_atSeventyFivePercentBoundary() {
        #expect(TIAGAColor.forContextUsage(percentage: 0.75) == TIAGAColor.statusWarning)
    }

    @Test func test_forContextUsage_returnsDangerColor_atOneHundredPercent() {
        #expect(TIAGAColor.forContextUsage(percentage: 1.0) == TIAGAColor.statusDanger)
    }

    @Test func test_forAgentState_mapsCompactingToCompactingColor() {
        #expect(TIAGAColor.forAgentState(.compacting) == TIAGAColor.statusCompacting)
    }
}
