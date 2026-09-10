import Foundation

@MainActor
final class GroveSkillInstaller {
    static let shared = GroveSkillInstaller()

    private let fileManager = FileManager.default
    private let skillFileName = "SKILL.md"

    private init() {}

    func installBundledSkill() {
        guard let sourceURL = Bundle.main.url(forResource: "SKILL", withExtension: "md") else {
            fputs("Grove: bundled agent skill was not found.\n", stderr)
            return
        }

        for destinationURL in destinationURLs {
            do {
                try fileManager.createDirectory(
                    at: destinationURL,
                    withIntermediateDirectories: true
                )

                let skillURL = destinationURL.appendingPathComponent(skillFileName)
                if fileManager.fileExists(atPath: skillURL.path) {
                    try fileManager.removeItem(at: skillURL)
                }
                try fileManager.copyItem(at: sourceURL, to: skillURL)
            } catch {
                fputs("Grove: could not install the agent skill: \(error.localizedDescription)\n", stderr)
            }
        }
    }

    // TODO: Add an explicit skill-management control when Grove exposes setup settings.
    private var destinationURLs: [URL] {
        let homeURL = fileManager.homeDirectoryForCurrentUser
        return [
            homeURL.appendingPathComponent(".agents/skills/grove"),
            homeURL.appendingPathComponent(".codex/skills/grove"),
            homeURL.appendingPathComponent(".claude/skills/grove")
        ]
    }
}
