import Foundation

/// Minimal streaming HTTP client for AI API calls
enum HTTPClient {

    /// Perform a streaming POST request, yielding data chunks as they arrive
    static func stream(
        url: URL,
        headers: [String: String],
        body: Data
    ) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 300
            config.timeoutIntervalForResource = 600
            let delegate = StreamDelegate(continuation: continuation)
            let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)

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

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        let session = URLSession(configuration: config)
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
