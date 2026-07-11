import Foundation
import Testing
@testable import CodexBar

struct PhoneNotificationTests {
    @Test
    func `builds ntfy request with alert metadata`() throws {
        let request = try NtfyNotificationRequestBuilder.request(
            serverURL: "https://ntfy.sh",
            topic: "codexbar-test-topic",
            title: "Codex depleted",
            body: "Remaining 0%.")

        #expect(request.url?.absoluteString == "https://ntfy.sh/codexbar-test-topic")
        #expect(request.httpMethod == "POST")
        #expect(String(data: try #require(request.httpBody), encoding: .utf8) == "Remaining 0%.")
        #expect(request.value(forHTTPHeaderField: "Title") == "Codex depleted")
        #expect(request.value(forHTTPHeaderField: "Priority") == "high")
    }

    @Test
    func `rejects malformed ntfy topics`() {
        #expect(throws: NtfyNotificationRequestBuilder.BuildError.invalidTopic) {
            try NtfyNotificationRequestBuilder.request(
                serverURL: "https://ntfy.sh",
                topic: "codexbar/topic",
                title: "Title",
                body: "Body")
        }
    }

    @Test
    func `rejects non http server URLs`() {
        #expect(throws: NtfyNotificationRequestBuilder.BuildError.invalidServerURL) {
            try NtfyNotificationRequestBuilder.request(
                serverURL: "file:///tmp/ntfy",
                topic: "codexbar-test-topic",
                title: "Title",
                body: "Body")
        }
    }
}
