import Foundation

/// Minimal streaming HTTP client for AI API calls
enum HTTPClient {

    private static func aiConfig() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        return config
    }

    /// Perform a streaming POST request, yielding data chunks as they arrive
    static func stream(
        url: URL,
        headers: [String: String],
        body: Data
    ) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            let delegate = StreamDelegate(continuation: continuation)
            let session = URLSession(configuration: aiConfig(), delegate: delegate, delegateQueue: nil)

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = body
            request.timeoutInterval = 300
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }

            let task = session.dataTask(with: request)
            continuation.onTermination = { @Sendable _ in
                task.cancel()
                session.invalidateAndCancel()
            }
            task.resume()
        }
    }

    /// Perform a non-streaming GET request
    static func get(
        url: URL,
        headers: [String: String]
    ) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, httpResponse)
    }

    /// Perform a non-streaming POST request
    static func post(
        url: URL,
        headers: [String: String],
        body: Data
    ) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = 300
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let session = URLSession(configuration: aiConfig())
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, httpResponse)
    }
}

// MARK: - Stream Delegate

private final class StreamDelegate: NSObject, URLSessionDataDelegate, Sendable {
    let continuation: AsyncThrowingStream<Data, Error>.Continuation
    /// Access serialized by URLSession's delegate queue
    nonisolated(unsafe) private var httpResponse: HTTPURLResponse?

    init(continuation: AsyncThrowingStream<Data, Error>.Continuation) {
        self.continuation = continuation
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        httpResponse = response as? HTTPURLResponse
        if let status = httpResponse?.statusCode, !(200...299).contains(status) {
            // Still allow data to flow so we can read the error body
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if let status = httpResponse?.statusCode, !(200...299).contains(status) {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            continuation.finish(throwing: AIError.apiError(status: status, message: body))
            return
        }
        continuation.yield(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            continuation.finish(throwing: error)
        } else {
            continuation.finish()
        }
    }
}
