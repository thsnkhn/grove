import AppKit
import Foundation

struct GroveAgent: Identifiable, Sendable {
    fileprivate let definition: AgentDefinition
    let executableURL: URL?
    var mcpInstalled: Bool

    var id: String { definition.id }
    var title: String { definition.title }
    var supportsMCPCommands: Bool { definition.addArguments != nil && executableURL != nil }
    var manualURL: URL { definition.manualURL }
}

@MainActor
final class GroveAgentManager: ObservableObject {
    @Published private(set) var agents: [GroveAgent] = []
    @Published private(set) var busyAgentIDs: Set<String> = []
    @Published var errorMessage: String?

    private let isPreview: Bool

    init(isPreview: Bool = GroveLaunchMode.isPreview) {
        self.isPreview = isPreview
        if isPreview {
            agents = AgentDefinition.all.map { definition in
                GroveAgent(
                    definition: definition,
                    executableURL: definition.executableName.map { URL(fileURLWithPath: "/preview/" + $0) },
                    mcpInstalled: definition.id == "codex"
                )
            }
        }
    }

    func refresh() {
        guard !isPreview else { return }
        let detected = AgentDefinition.all.compactMap { definition -> GroveAgent? in
            guard definition.isInstalled else { return nil }
            return GroveAgent(
                definition: definition,
                executableURL: definition.executableURL,
                mcpInstalled: false
            )
        }
        agents = detected

        for agent in detected where agent.supportsMCPCommands {
            Task { await refreshStatus(for: agent) }
        }
    }

    func isBusy(_ agent: GroveAgent) -> Bool {
        busyAgentIDs.contains(agent.id)
    }

    func toggleMCP(for agent: GroveAgent) {
        if isPreview {
            if let index = agents.firstIndex(where: { $0.id == agent.id }) {
                agents[index].mcpInstalled.toggle()
            }
            return
        }
        guard agent.supportsMCPCommands, !isBusy(agent), let executableURL = agent.executableURL else { return }

        busyAgentIDs.insert(agent.id)
        Task {
            do {
                let arguments = agent.mcpInstalled
                    ? agent.definition.removeArguments!
                    : agent.definition.addArguments!
                let result = try await GroveCommandRunner.run(executableURL, arguments: arguments)
                guard result.status == 0 else {
                    throw GroveCommandError.failed(result.message)
                }

                if let index = agents.firstIndex(where: { $0.id == agent.id }) {
                    agents[index].mcpInstalled.toggle()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            busyAgentIDs.remove(agent.id)
        }
    }

    func openREADME(for agent: GroveAgent) {
        guard !isPreview else { return }
        NSWorkspace.shared.open(agent.manualURL)
    }

    private func refreshStatus(for agent: GroveAgent) async {
        guard let executableURL = agent.executableURL,
              let arguments = agent.definition.statusArguments else { return }

        let installed = (try? await GroveCommandRunner.run(executableURL, arguments: arguments).status == 0) ?? false
        guard let index = agents.firstIndex(where: { $0.id == agent.id }) else { return }
        agents[index].mcpInstalled = installed
    }
}

private struct AgentDefinition: Sendable {
    let id: String
    let title: String
    let executableName: String?
    let applicationPaths: [String]
    let addArguments: [String]?
    let removeArguments: [String]?
    let statusArguments: [String]?
    let manualURL: URL

    @MainActor
    var executableURL: URL? {
        guard let executableName else { return nil }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let pathDirectories = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
        let directories = pathDirectories + [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(home)/.local/bin",
            "\(home)/.npm-global/bin"
        ]

        for directory in Set(directories) {
            let url = URL(fileURLWithPath: directory).appendingPathComponent(executableName)
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    @MainActor
    var isInstalled: Bool {
        if id == "other" { return true }
        if executableURL != nil { return true }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return applicationPaths.contains { path in
            let expandedPath = path.replacingOccurrences(of: "~", with: home)
            return FileManager.default.fileExists(atPath: expandedPath)
        }
    }

    static let all: [AgentDefinition] = [
        AgentDefinition(
            id: "codex",
            title: "Codex",
            executableName: "codex",
            applicationPaths: [],
            addArguments: ["mcp", "add", "grove", "--url", GroveMCPEndpoint.url.absoluteString],
            removeArguments: ["mcp", "remove", "grove"],
            statusArguments: ["mcp", "get", "grove"],
            manualURL: GroveURLs.mcpSetup
        ),
        AgentDefinition(
            id: "claude-code",
            title: "Claude Code",
            executableName: "claude",
            applicationPaths: [],
            addArguments: ["mcp", "add", "--transport", "http", "grove", GroveMCPEndpoint.url.absoluteString],
            removeArguments: ["mcp", "remove", "grove"],
            statusArguments: ["mcp", "get", "grove"],
            manualURL: GroveURLs.mcpSetup
        ),
        AgentDefinition(
            id: "openclaw",
            title: "OpenClaw",
            executableName: "openclaw",
            applicationPaths: ["/Applications/OpenClaw.app", "~/Applications/OpenClaw.app"],
            addArguments: [
                "mcp", "set", "grove",
                "{\"url\":\"\(GroveMCPEndpoint.url.absoluteString)\",\"transport\":\"streamable-http\"}"
            ],
            removeArguments: ["mcp", "unset", "grove"],
            statusArguments: ["mcp", "show", "grove"],
            manualURL: GroveURLs.mcpSetup
        ),
        AgentDefinition(
            id: "cursor",
            title: "Cursor",
            executableName: nil,
            applicationPaths: ["/Applications/Cursor.app", "~/Applications/Cursor.app"],
            addArguments: nil,
            removeArguments: nil,
            statusArguments: nil,
            manualURL: GroveURLs.mcpSetup
        ),
        AgentDefinition(
            id: "other",
            title: "Other",
            executableName: nil,
            applicationPaths: [],
            addArguments: nil,
            removeArguments: nil,
            statusArguments: nil,
            manualURL: GroveURLs.mcpSetup
        )
    ]
}

private enum GroveCommandRunner {
    static func run(_ executableURL: URL, arguments: [String]) async throws -> GroveCommandResult {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            let output = Pipe()
            let errors = Pipe()
            process.executableURL = executableURL
            process.arguments = arguments
            process.standardOutput = output
            process.standardError = errors
            try process.run()
            process.waitUntilExit()

            let stdout = output.fileHandleForReading.readDataToEndOfFile()
            let stderr = errors.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: stderr.isEmpty ? stdout : stderr, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return GroveCommandResult(status: process.terminationStatus, message: message ?? "Command failed.")
        }.value
    }
}

private struct GroveCommandResult: Sendable {
    let status: Int32
    let message: String
}

private enum GroveCommandError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message): return message
        }
    }
}

enum GroveURLs {
    static let mcpSetup = URL(string: "https://github.com/thsnkhn/grove#add-grove-to-an-mcp-client")!
}

private enum GroveMCPEndpoint {
    static let url = URL(string: "http://127.0.0.1:52718/mcp")!
}
