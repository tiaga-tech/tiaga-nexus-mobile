//
//  APIClientTests.swift
//  TIAGATests
//

import Testing
import Foundation
@testable import TIAGA

private struct FakeResponse: Codable, Equatable {
    let value: String
}

/// A stand-in transport so these tests never touch the network.
private final class MockURLDataSession: URLDataSession {
    enum Behaviour {
        case success(status: Int, body: Data)
        case transportFailure
    }

    let behaviour: Behaviour

    init(_ behaviour: Behaviour) {
        self.behaviour = behaviour
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        switch behaviour {
        case .transportFailure:
            throw URLError(.notConnectedToInternet)
        case .success(let status, let body):
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: nil,
                headerFields: nil
            )!
            return (body, response)
        }
    }
}

struct APIClientTests {

    @Test func test_apiClient_decodesSuccessfulResponse() async throws {
        let body = try! JSONEncoder().encode(FakeResponse(value: "atlas"))
        let client = TIAGAAPIClient(session: MockURLDataSession(.success(status: 200, body: body)))

        let result: FakeResponse = try await client.get("devices")

        #expect(result == FakeResponse(value: "atlas"))
    }

    @Test func test_apiClient_mapsUnauthorizedStatusToTransportError() async throws {
        let client = TIAGAAPIClient(session: MockURLDataSession(.success(status: 401, body: Data())))

        await #expect(throws: APITransportError.unauthorized) {
            let _: FakeResponse = try await client.get("devices")
        }
    }

    @Test func test_apiClient_mapsUnreachableHostToTransportError() async throws {
        let client = TIAGAAPIClient(session: MockURLDataSession(.transportFailure))

        await #expect(throws: APITransportError.unreachable) {
            let _: FakeResponse = try await client.get("devices")
        }
    }
}
