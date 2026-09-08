import Foundation
import Darwin
import MCP

struct GroveMain {
    static func main() async {
        let command = CommandLine.arguments.dropFirst().first

        do {
            switch command {
            case "--help", "-h":
                printHelp()
            case "--version", "-v":
                print(Grove.version)
            case "authorize":
                let store = await EventKitStore()
                let report = try await store.authorize()
                print(report)
            case "doctor":
                let store = await EventKitStore()
                print(await store.doctor())
            case nil:
                let store = await EventKitStore()
                try await GroveServer(store: store).run()
            default:
                throw GroveError.invalidArgument("Unknown command. Run `grove --help` for usage.")
            }
        } catch {
            FileHandle.standardError.write(Data("Grove: \(error.localizedDescription)\n".utf8))
            Darwin.exit(1)
        }
    }

    private static func printHelp() {
        print("""
        Grove \(Grove.version)

        Native Mac tools for AI assistants.

        Usage:
          grove                 Start the MCP server over stdio.
          grove authorize       Request Calendar and Reminders access.
          grove doctor          Show local permission and runtime status.
          grove --help          Show this help.
          grove --version       Show the version.
        """)
    }
}

enum Grove {
    static let version = "0.1.0"
}

await GroveMain.main()
