import AppKit
import SwiftUI

struct GroveMenuView: View {
    @ObservedObject var settings: GroveSettings
    @ObservedObject var updater: GroveUpdater
    @State private var showsOptions = false

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 10),
        count: 3
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsHeader

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

    private var settingsHeader: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.snappy(duration: 0.25, extraBounce: 0)) {
                    showsOptions.toggle()
                }
            } label: {
                HStack {
                    Text("Grove")
                        .font(.title3.weight(.semibold))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showsOptions ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(showsOptions ? "Hide Grove options" : "Show Grove options")
            .accessibilityLabel("Grove options")
            .accessibilityValue(showsOptions ? "Expanded" : "Collapsed")

            if showsOptions {
                options
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var options: some View {
        VStack(spacing: 0) {
            Toggle("Launch at Login", isOn: Binding(
                get: { settings.launchAtLogin },
                set: { settings.setLaunchAtLogin($0) }
            ))
            .toggleStyle(.switch)
            .padding(.vertical, 8)

            Divider()

            #if canImport(Sparkle)
            optionButton(updater.updateAvailable ? "Update Available…" : "Check for Updates…") {
                updater.checkForUpdates()
            }
            .disabled(!updater.canCheckForUpdates)
            #endif

            Divider()

            optionButton("Quit Grove", role: .destructive) {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func optionButton(
        _ title: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            HStack {
                Text(title)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
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
                        .font(.system(size: 17, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isEnabled ? color : Color.white.opacity(0.88))
                }
                .frame(width: 32, height: 32)

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
