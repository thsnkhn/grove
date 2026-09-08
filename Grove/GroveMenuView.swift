import AppKit
import SwiftUI

struct GroveMenuView: View {
    @ObservedObject var settings: GroveSettings
    @ObservedObject var updater: GroveUpdater
    @State private var showsOptions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsHeader

            LazyVStack(spacing: 0) {
                ForEach(GroveService.allCases) { service in
                    ServiceRow(
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
                    ServiceRow(
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
        VStack(spacing: 16) {
            Button {
                withAnimation(.snappy(duration: 0.25, extraBounce: 0)) {
                    showsOptions.toggle()
                }
            } label: {
                HStack {
                    Text("Grove")
                        .font(.system(size: 15, weight: .semibold))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
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
            HStack(spacing: 8) {
                Text("Launch at Login")
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Toggle("", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .accessibilityLabel("Launch at Login")
            }
            .frame(height: 32)

            Divider()
                .opacity(0.65)

            #if canImport(Sparkle)
            optionButton(updater.updateAvailable ? "Update Available…" : "Check for Updates…") {
                updater.checkForUpdates()
            }
            .disabled(!updater.canCheckForUpdates)
            #endif

            Divider()
                .opacity(0.65)

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
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .contentShape(Rectangle())
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private func color(for service: GroveService) -> Color {
        switch service {
        case .calendar: return Color(nsColor: .systemRed)
        case .reminders: return Color(nsColor: .systemBlue)
        }
    }

}

private struct ServiceRow: View {
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
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isEnabled
                            ? Color(nsColor: .textBackgroundColor).opacity(0.94)
                            : Color(nsColor: .tertiarySystemFill))

                    Image(systemName: symbolName)
                        .font(.system(size: 14, weight: .medium))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(isEnabled ? color : Color(nsColor: .secondaryLabelColor))
                }
                .frame(width: 26, height: 26)

                Text(title)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(action == nil
                        ? Color(nsColor: .tertiaryLabelColor)
                        : .primary)

                Spacer(minLength: 8)

                Text(status)
                    .font(.system(size: 12))
                    .foregroundStyle(action == nil
                        ? Color(nsColor: .tertiaryLabelColor)
                        : .secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
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
