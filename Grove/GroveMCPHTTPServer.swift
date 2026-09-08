import Foundation
import MCP
import Network

@MainActor
final class GroveMCPHTTPServer {
    static let port: UInt16 = 52718

    private let transport = StatelessHTTPServerTransport()
    private var listener: NWListener?
    private var serverTask: Task<Void, Never>?

    var endpoint: URL {
        URL(string: "http://127.0.0.1:\(Self.port)/mcp")!
    }

    func start() {
        guard listener == nil else { return }

        guard let port = NWEndpoint.Port(rawValue: Self.port) else {
            fputs("Grove: invalid MCP port\n", stderr)
            return
        }

        do {
            let parameters = NWParameters.tcp
            parameters.requiredLocalEndpoint = .hostPort(
                host: NWEndpoint.Host("127.0.0.1"),
                port: port
            )
            let listener = try NWListener(using: parameters)
            listener.stateUpdateHandler = { state in
                if case .failed(let error) = state {
                    fputs("Grove: MCP listener failed: \(error.localizedDescription)\n", stderr)
                }
            }

            let transport = transport
            listener.newConnectionHandler = { connection in
                GroveHTTPConnection(connection: connection, transport: transport).start()
            }
            listener.start(queue: DispatchQueue(label: "com.thsnkhn.grove.mcp-http"))
            self.listener = listener

            serverTask = Task { [transport] in
                do {
                    try await GroveServer(store: EventKitStore()).run(transport: transport)
                } catch {
                    fputs("Grove: MCP server stopped: \(error.localizedDescription)\n", stderr)
                }
            }
        } catch {
            fputs("Grove: could not start MCP listener: \(error.localizedDescription)\n", stderr)
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        serverTask?.cancel()
        serverTask = nil

        let transport = transport
        Task {
            await transport.disconnect()
        }
    }
}

private final class GroveHTTPConnection: @unchecked Sendable {
    private static let maxRequestSize = 4 * 1024 * 1024

    private let connection: NWConnection
    private let transport: StatelessHTTPServerTransport
    private var buffer = Data()

    init(connection: NWConnection, transport: StatelessHTTPServerTransport) {
        self.connection = connection
        self.transport = transport
    }

    func start() {
        connection.start(queue: DispatchQueue.global(qos: .utility))
        Task { await run() }
    }

    private func run() async {
        defer { connection.cancel() }

        do {
            guard let request = try await readRequest() else { return }
            let response = await transport.handleRequest(request)
            try await send(response)
        } catch {
            return
        }
    }

    private func readRequest() async throws -> HTTPRequest? {
        while true {
            if let request = try parseRequest() {
                return request
            }

            let result = try await receiveData()
            if let data = result.data {
                buffer.append(data)
                guard buffer.count <= Self.maxRequestSize else {
                    throw GroveHTTPError.requestTooLarge
                }
            }

            if result.isComplete {
                if buffer.isEmpty { return nil }
                guard let request = try parseRequest() else {
                    throw GroveHTTPError.malformedRequest
                }
                return request
            }
        }
    }

    private func parseRequest() throws -> HTTPRequest? {
        let delimiter = Data("\r\n\r\n".utf8)
        guard let headerRange = buffer.range(of: delimiter) else {
            return nil
        }

        let headerData = buffer.subdata(in: 0..<headerRange.lowerBound)
        guard let headerText = String(data: headerData, encoding: .utf8) else {
            throw GroveHTTPError.malformedRequest
        }

        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            throw GroveHTTPError.malformedRequest
        }

        let requestParts = requestLine.split(separator: " ", maxSplits: 2)
        guard requestParts.count == 3 else {
            throw GroveHTTPError.malformedRequest
        }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let name = String(line[..<separator]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: separator)...])
                .trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }

        let contentLength = headers.first {
            $0.key.caseInsensitiveCompare("Content-Length") == .orderedSame
        }.flatMap { Int($0.value) } ?? 0
        guard contentLength >= 0 else {
            throw GroveHTTPError.malformedRequest
        }

        let bodyStart = headerRange.upperBound
        let bodyEnd = bodyStart + contentLength
        guard buffer.count >= bodyEnd else {
            return nil
        }

        let body = contentLength == 0 ? nil : buffer.subdata(in: bodyStart..<bodyEnd)
        let path = String(requestParts[1].split(separator: "?", maxSplits: 1).first ?? "")
        buffer.removeSubrange(0..<bodyEnd)

        return HTTPRequest(
            method: String(requestParts[0]),
            headers: headers,
            body: body,
            path: path
        )
    }

    private func receiveData() async throws -> (data: Data?, isComplete: Bool) {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<(Data?, Bool), Error>) in
            connection.receive(
                minimumIncompleteLength: 1,
                maximumLength: 64 * 1024
            ) { data, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (data, isComplete))
                }
            }
        }
    }

    private func send(_ response: HTTPResponse) async throws {
        let body: Data
        var headers = response.headers

        switch response {
        case .accepted, .ok:
            body = Data()
        case .data(let data, _):
            body = data
        case .error:
            body = response.bodyData ?? Data()
        case .stream:
            throw GroveHTTPError.unsupportedStreamingResponse
        }

        headers["Content-Length"] = String(body.count)
        headers["Connection"] = "close"
        if !body.isEmpty && !headers.keys.contains(where: {
            $0.caseInsensitiveCompare("Content-Type") == .orderedSame
        }) {
            headers["Content-Type"] = "application/json"
        }

        var output = Data()
        output.append(Data("HTTP/1.1 \(response.statusCode) \(reason(for: response.statusCode))\r\n".utf8))
        for key in headers.keys.sorted() {
            output.append(Data("\(key): \(headers[key]!)\r\n".utf8))
        }
        output.append(Data("\r\n".utf8))
        output.append(body)

        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: output, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            })
        }
    }

    private func reason(for statusCode: Int) -> String {
        switch statusCode {
        case 200: return "OK"
        case 202: return "Accepted"
        case 400: return "Bad Request"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 409: return "Conflict"
        case 421: return "Misdirected Request"
        default: return "Internal Server Error"
        }
    }
}

private enum GroveHTTPError: Error {
    case malformedRequest
    case requestTooLarge
    case unsupportedStreamingResponse
}
