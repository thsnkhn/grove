import Darwin
import Foundation

enum GroveProcessRegistry {
    private static let directoryURL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Grove/Servers", isDirectory: true)

    static func registerCurrentProcess() throws -> URL {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let url = directoryURL.appendingPathComponent("\(getpid()).pid")
        try Data(String(getpid()).utf8).write(to: url, options: .atomic)
        return url
    }

    static func unregister(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    static func terminateServers() {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        for url in urls where url.pathExtension == "pid" {
            guard let data = try? Data(contentsOf: url),
                  let value = String(data: data, encoding: .utf8),
                  let pid = Int32(value.trimmingCharacters(in: .whitespacesAndNewlines)),
                  pid != getpid() else {
                try? FileManager.default.removeItem(at: url)
                continue
            }

            _ = kill(pid, SIGTERM)
            for _ in 0..<10 where kill(pid, 0) == 0 {
                usleep(50_000)
            }
            if kill(pid, 0) == 0 {
                _ = kill(pid, SIGKILL)
            }
            try? FileManager.default.removeItem(at: url)
        }
    }
}

final class GroveProcessLease {
    private let url: URL

    init() throws {
        url = try GroveProcessRegistry.registerCurrentProcess()
    }

    deinit {
        GroveProcessRegistry.unregister(url)
    }
}
