import AppKit
import SwiftUI

/// Visual tone of a toast. Drives the icon + tint but never uses alarming red
/// for non-events (empty clipboard is `.neutral`, not `.error`).
enum ToastStyle {
    case success
    case neutral
    case error

    var symbol: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .neutral: return "info.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .success: return .green
        case .neutral: return .secondary
        case .error: return .orange
        }
    }
}

/// One primary recovery action shown on a toast (ux-adhd §6: "exactly one
/// primary recovery button, never a bare OK").
struct ToastAction {
    let title: String
    let handler: () -> Void
}

/// Non-focus-stealing HUD toast shown near the menu-bar icon. Manufactures the
/// immediate, honest feedback an accessory app otherwise lacks on the hotkey
/// path (ux-adhd §2). Uses a `nonactivatingPanel` so it never pulls focus from
/// the app the user is working in.
@MainActor
final class HUDToast {

    static let shared = HUDToast()

    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?

    /// Show a toast. `onClick` fires when the body is clicked (e.g. reveal in
    /// Finder). `action` renders a single trailing button (recovery / Undo).
    func show(style: ToastStyle,
              title: String,
              subtitle: String? = nil,
              duration: TimeInterval = 3.0,
              onClick: (() -> Void)? = nil,
              action: ToastAction? = nil) {

        dismissTask?.cancel()

        let root = ToastView(
            style: style,
            title: title,
            subtitle: subtitle,
            action: action,
            onBodyClick: { [weak self] in
                onClick?()
                self?.dismiss()
            },
            onActionTap: { [weak self] in
                action?.handler()
                self?.dismiss()
            }
        )

        let hosting = NSHostingView(rootView: root)
        hosting.layout()
        let size = hosting.fittingSize

        let panel = existingPanel(size: size)
        panel.contentView = hosting
        position(panel, size: size)
        panel.orderFrontRegardless()
        self.panel = panel

        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        panel?.orderOut(nil)
        panel = nil
    }

    private func existingPanel(size: NSSize) -> NSPanel {
        if let panel { return panel }
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }

    /// Top-right of the screen containing the menu bar, just under it.
    private func position(_ panel: NSPanel, size: NSSize) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let frame = screen?.visibleFrame else { return }
        let margin: CGFloat = 12
        let x = frame.maxX - size.width - margin
        let y = frame.maxY - size.height - margin
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }
}

/// SwiftUI body of the toast.
private struct ToastView: View {
    let style: ToastStyle
    let title: String
    let subtitle: String?
    let action: ToastAction?
    let onBodyClick: () -> Void
    let onActionTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: style.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(style.tint)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if let action {
                Button(action.title, action: onActionTap)
                    .buttonStyle(.borderless)
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minWidth: 220, maxWidth: 340, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onBodyClick)
    }
}
