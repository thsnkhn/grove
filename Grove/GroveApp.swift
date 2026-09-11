import AppKit
import Darwin
import SwiftUI

enum GroveLaunchMode {
    static var isPreview: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            || environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"
    }

    static var argument: String? {
        CommandLine.arguments.dropFirst().first
    }

    static var isHeadless: Bool {
        argument != nil
    }
}

@MainActor
final class GroveAppDelegate: NSObject, NSApplicationDelegate {
    private var mcpHTTPServer: GroveMCPHTTPServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !GroveLaunchMode.isPreview else { return }
        if GroveLaunchMode.isHeadless {
            NSApp.setActivationPolicy(.prohibited)
            Task { await runHeadlessCommand() }
        } else {
            NSApp.setActivationPolicy(.accessory)
            GroveSkillInstaller.shared.installBundledSkill()
            mcpHTTPServer = GroveMCPHTTPServer()
            mcpHTTPServer?.start()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !GroveLaunchMode.isPreview else { return .terminateNow }
        mcpHTTPServer?.stop()
        GroveProcessRegistry.terminateServers()
        return .terminateNow
    }

    private func runHeadlessCommand() async {
        do {
            switch GroveLaunchMode.argument {
            case "--mcp":
                let store = EventKitStore()
                try await GroveServer(store: store).run()
            case "authorize":
                print(try await EventKitStore().authorize())
            case "doctor":
                print(EventKitStore().doctor())
            case "--help", "-h":
                printHelp()
            case "--version", "-v":
                print(Grove.version)
            default:
                throw GroveError.invalidArgument("Unknown command. Run `Grove --help` for usage.")
            }
        } catch {
            FileHandle.standardError.write(Data("Grove: \(error.localizedDescription)\n".utf8))
            Darwin.exit(1)
        }

        NSApp.terminate(nil)
    }

    private func printHelp() {
        print("""
        Grove \(Grove.version)

        Native Mac tools for AI assistants.

        Usage:
          Grove                 Open the Grove menu bar app.
          Grove --mcp           Start the MCP server over stdio.
          Grove authorize       Request Calendar and Reminders access.
          Grove doctor          Show local permission and runtime status.
          Grove --help          Show this help.
          Grove --version       Show the version.
        """)
    }
}

@main
struct GroveApp: App {
    @NSApplicationDelegateAdaptor(GroveAppDelegate.self) private var appDelegate
    @StateObject private var settings = GroveSettings()
    @StateObject private var updater = GroveUpdater()
    @StateObject private var agentManager = GroveAgentManager()

    var body: some Scene {
        MenuBarExtra("Grove", systemImage: "tree.fill") {
            GroveMenuView(settings: settings, updater: updater, agentManager: agentManager)
        }
        .menuBarExtraStyle(.window)
    }
}

enum Grove {
    static let version = "1.0.0"
}
