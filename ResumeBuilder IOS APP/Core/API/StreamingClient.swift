import Foundation

struct StreamingClient {
    /// Streams `fullText` in small sequential chunks — used when the API returns JSON (not SSE).
    func streamDisplayedText(from fullText: String, chunkSize: Int = 12) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    continuation.finish()
                    return
                }
                let size = max(1, chunkSize)
                var i = trimmed.startIndex
                while i < trimmed.endIndex {
                    let next = trimmed.index(i, offsetBy: size, limitedBy: trimmed.endIndex) ?? trimmed.endIndex
                    continuation.yield(String(trimmed[i..<next]))
                    i = next
                    try? await Task.sleep(for: .milliseconds(18))
                }
                continuation.finish()
            }
        }
    }

    func streamLines(
        endpoint: Endpoint,
        token: String?
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var request = URLRequest(url: BackendConfig.apiBaseURL.appendingPathComponent(endpoint.path))
                    request.httpMethod = "POST"
                    if let token {
                        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    }

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                        throw APIClientError.invalidResponse
                    }

                    for try await line in bytes.lines where !line.isEmpty {
                        continuation.yield(line)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
