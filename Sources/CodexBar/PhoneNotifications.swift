import CodexBarCore
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct NtfyNotificationRequestBuilder {
    enum BuildError: Error {
        case invalidServerURL
        case invalidTopic
    }

    static func request(
        serverURL: String,
        topic: String,
        title: String,
        body: String) throws -> URLRequest
    {
        let trimmedServerURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let server = URL(string: trimmedServerURL),
              let scheme = server.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              server.host != nil
        else {
            throw BuildError.invalidServerURL
        }

        let trimmedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTopic.isEmpty,
              !trimmedTopic.contains("/"),
              !trimmedTopic.contains("\\"),
              !trimmedTopic.contains(where: { $0.isWhitespace })
        else {
            throw BuildError.invalidTopic
        }

        var request = URLRequest(url: server.appendingPathComponent(trimmedTopic))
        request.httpMethod = "POST"
        request.httpBody = Data(body.utf8)
        request.setValue(title, forHTTPHeaderField: "Title")
        request.setValue("high", forHTTPHeaderField: "Priority")
        request.setValue("warning", forHTTPHeaderField: "Tags")
        request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
        return request
    }
}

@MainActor
final class PhoneNotifications {
    static let shared = PhoneNotifications()

    static let defaultServerURL = "https://ntfy.sh"

    private let logger = CodexBarLog.logger(LogCategories.notifications)

    func send(
        title: String,
        body: String,
        topic: String,
        serverURL: String = PhoneNotifications.defaultServerURL)
    {
        guard UserDefaults.standard.bool(forKey: "phoneNotificationsEnabled") else {
            self.logger.debug("phone notification skipped: disabled")
            return
        }
        let topic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !topic.isEmpty else {
            self.logger.debug("phone notification skipped: no ntfy topic configured")
            return
        }

        Task { [logger] in
            do {
                let request = try NtfyNotificationRequestBuilder.request(
                    serverURL: serverURL,
                    topic: topic,
                    title: title,
                    body: body)
                let (_, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200 ... 299).contains(httpResponse.statusCode)
                else {
                    let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                    throw NtfyNotificationError.httpStatus(status)
                }
                logger.info("phone notification sent", metadata: ["topic": topic])
            } catch {
                logger.error(
                    "phone notification failed",
                    metadata: ["topic": topic, "error": String(describing: error)])
            }
        }
    }

    func sendTest(topic: String, serverURL: String = PhoneNotifications.defaultServerURL) {
        self.send(
            title: "CodexBar test notification",
            body: "Phone notifications are configured correctly.",
            topic: topic,
            serverURL: serverURL)
    }
}

private enum NtfyNotificationError: Error {
    case httpStatus(Int)
}
