import AppKit
import SwiftUI

struct GroveMenuView: View {
    @ObservedObject var settings: GroveSettings
    @ObservedObject var updater: GroveUpdater

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 10),
        count: 3
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(GroveService.allCases) { service in
                    ServiceTile(
                        title: service.title,
                        symbolName: settings.isEnabled(service)
                            ? service.filledSymbolName
                            : service.outlineSymbolName,
                        status: settings.isEnabled(service) ? "On" : "Off",
                        color: color(for: service),
                        isEnabled: settings.isEnabled(service)
                    ) {
                        settings.setEnabled(!settings.isEnabled(service), for: service)
                    }
                }

                ForEach(ComingSoonTool.all) { tool in
                    ServiceTile(
                        title: tool.title,
                        symbolName: tool.symbolName,
                        status: "Soon",
                        color: .secondary,
                        isEnabled: false,
                        action: nil
                    )
                }
            }
        }
        .padding(16)
        .frame(width: 304)
    }

    private var header: some View {
        HStack {
            Text("Grove")
                .font(.title3.weight(.semibold))

            Spacer()

            Menu {
                Toggle("Launch at Login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))

                #if canImport(Sparkle)
                Button(updater.updateAvailable ? "Update Available…" : "Check for Updates…") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
                #endif

                Divider()

                Button("Quit Grove") {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Grove options")
            .accessibilityLabel("Grove options")
        }
    }

    private func color(for service: GroveService) -> Color {
        switch service {
        case .calendar: return .red
        case .reminders: return .blue
        }
    }

}

private struct ServiceTile: View {
    let title: String
    let symbolName: String
    let status: String
    let color: Color
    let isEnabled: Bool
    let action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isEnabled ? Color.white.opacity(0.94) : Color.secondary.opacity(0.32))

                    Image(systemName: symbolName)
                        .font(.system(size: 19, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isEnabled ? color : Color.white.opacity(0.88))
                }
                .frame(width: 36, height: 36)

                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(action == nil ? .secondary : .primary)

                    Text(status)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .accessibilityLabel("\(title), \(status)")
    }
}

private struct ComingSoonTool: Identifiable {
    let title: String
    let symbolName: String

    var id: String { title }

    static let all = [
        ComingSoonTool(title: "Mail", symbolName: "envelope"),
        ComingSoonTool(title: "Notes", symbolName: "note.text"),
        ComingSoonTool(title: "Messages", symbolName: "message"),
        ComingSoonTool(title: "Contacts", symbolName: "person.2")
    ]
}
