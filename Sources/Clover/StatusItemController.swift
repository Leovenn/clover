import AppKit
import SwiftUI

/// The clover in the menu bar and the panel it opens: drops in on open, fades out on
/// close, closes on a click elsewhere or Esc. Each opening refreshes the model.
@MainActor
final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let panel = FloatingPanel()
    private let model: AppModel
    private var outsideClicks: Any?

    init(model: AppModel) {
        self.model = model
        super.init()
        item.button?.image = Self.glyph
        item.button?.target = self
        item.button?.action = #selector(toggle)
        panel.onEscape = { [weak self] in self?.close() }
        model.closePanel = { [weak self] in self?.close() }
        panel.setContent(PanelView(model: model))
    }

    @objc private func toggle() {
        panel.isVisible ? close() : open()
    }

    private func open() {
        guard let button = item.button, let window = button.window else { return }
        let anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
        model.reload()  // the rows the panel sizes itself to
        panel.present(below: anchor)
        item.button?.highlight(true)
        outsideClicks = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
        Task { await model.panelOpened() }
    }

    private func close() {
        guard panel.isVisible else { return }
        panel.dismiss()
        item.button?.highlight(false)
        if let outsideClicks { NSEvent.removeMonitor(outsideClicks) }
        outsideClicks = nil
    }

    /// The clover as a template image, so the menu bar tints it.
    private static let glyph: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            for part in CloverShape.parts(in: rect.insetBy(dx: 1, dy: 1)) {
                ctx.addPath(part)
                ctx.fillPath()
            }
            return true
        }
        image.isTemplate = true
        return image
    }()
}

/// A borderless panel holding SwiftUI content on the system panel material, as menu bar
/// extras have. It sizes itself to the content and keeps its top edge under the menu bar item.
@MainActor
final class FloatingPanel: NSPanel {
    var onEscape: () -> Void = {}
    private let background = NSVisualEffectView()
    private var anchorTop: CGFloat = 0
    private static let cornerRadius: CGFloat = 16

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isReleasedWhenClosed = false
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        // The window server cuts both the panel and its shadow to this mask.
        background.maskImage = Self.roundedMask
        contentView = background
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) { onEscape() }

    func setContent(_ view: some View) {
        let host = NSHostingView(rootView: view.onGeometryChange(for: CGSize.self, of: \.size) { [weak self] size in
            self?.fit(size)
        })
        host.sizingOptions = [.intrinsicContentSize]
        host.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(host)
        NSLayoutConstraint.activate([
            host.topAnchor.constraint(equalTo: background.topAnchor),
            host.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            host.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])
    }

    func present(below anchor: NSRect) {
        anchorTop = anchor.minY - 6
        let size = background.subviews.first?.fittingSize ?? .zero
        let final = NSRect(x: anchor.midX - size.width / 2, y: anchorTop - size.height, width: size.width, height: size.height)
        setFrame(final.offsetBy(dx: 0, dy: 8), display: false)
        alphaValue = 0
        makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.25, 1)
            animator().setFrame(final, display: true)
            animator().alphaValue = 1
        }
    }

    func dismiss() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().setFrame(frame.offsetBy(dx: 0, dy: 4), display: true)
            animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated { self.orderOut(nil) }
        }
    }

    /// Grows or shrinks downward as rows come and go. Animated, so that during the opening
    /// animation it replaces that animation's target instead of being overridden by it.
    private func fit(_ size: CGSize) {
        guard isVisible, size != frame.size else { return }
        let target = NSRect(x: frame.midX - size.width / 2, y: anchorTop - size.height, width: size.width, height: size.height)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            animator().setFrame(target, display: true)
        }
    }

    /// A stretchable rounded rectangle: only its corners keep their size.
    private static let roundedMask: NSImage = {
        let r = cornerRadius
        let image = NSImage(size: NSSize(width: r * 2 + 1, height: r * 2 + 1), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: r, yRadius: r).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: r, left: r, bottom: r, right: r)
        image.resizingMode = .stretch
        return image
    }()
}
