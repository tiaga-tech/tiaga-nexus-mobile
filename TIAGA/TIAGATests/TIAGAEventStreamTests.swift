//
//  TIAGAEventStreamTests.swift
//  TIAGATests
//

import Foundation
import Testing
@testable import TIAGA

/// Regression coverage for a real bug: `URLSession.AsyncBytes.lines` never
/// yields an empty-string element for a blank line, confirmed empirically
/// against a local raw-socket SSE server. A parser that waits for
/// `line.isEmpty` to flush an accumulated event therefore never yields
/// anything — which is exactly what made every live update (permission
/// requests, device presence) silently never arrive in the running app,
/// only ever visible after a relaunch's fresh REST fetch. These tests pin
/// down `TIAGAEventStream.parse(line:eventName:)`'s per-line behavior so
/// that fix can't silently regress back to blank-line-dependent buffering.
struct TIAGAEventStreamTests {

    @Test func test_parse_yieldsEventImmediately_onDataLine_withoutABlankLine() {
        var eventName: String?
        let event = TIAGAEventStream.parse(line: "data: {\"type\":\"hello\"}", eventName: &eventName)

        #expect(event == TIAGAEventStream.Event(name: nil, data: Data("{\"type\":\"hello\"}".utf8)))
    }

    @Test func test_parse_attachesPrecedingEventNameLine() {
        var eventName: String?
        #expect(TIAGAEventStream.parse(line: "event: ping", eventName: &eventName) == nil)

        let event = TIAGAEventStream.parse(line: "data: {}", eventName: &eventName)

        #expect(event?.name == "ping")
    }

    @Test func test_parse_clearsEventName_afterCompletingAnEvent() {
        var eventName: String?
        _ = TIAGAEventStream.parse(line: "event: ping", eventName: &eventName)
        _ = TIAGAEventStream.parse(line: "data: {}", eventName: &eventName)

        let event = TIAGAEventStream.parse(line: "data: {\"type\":\"tick\"}", eventName: &eventName)

        #expect(event?.name == nil)
    }

    @Test func test_parse_ignoresBlankAndCommentLines() {
        var eventName: String?
        #expect(TIAGAEventStream.parse(line: "", eventName: &eventName) == nil)
        #expect(TIAGAEventStream.parse(line: ": ping", eventName: &eventName) == nil)
    }

    @Test func test_parse_handlesConsecutiveDataLines_asSeparateEvents() {
        var eventName: String?
        let first = TIAGAEventStream.parse(line: "data: {\"n\":1}", eventName: &eventName)
        let second = TIAGAEventStream.parse(line: "data: {\"n\":2}", eventName: &eventName)

        #expect(first?.data == Data("{\"n\":1}".utf8))
        #expect(second?.data == Data("{\"n\":2}".utf8))
    }
}
