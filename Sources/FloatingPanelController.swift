import AppKit
import Foundation

// MARK: - Non-activating Floating Panel

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - Native Draggable Header View (Expanded Mode)

@MainActor
final class PanelHeaderView: NSView {
    private let liveDot = NSView()
    private let titleLabel = NSTextField(labelWithString: "GraviHUD")
    private let offlineBadge = NSTextField(labelWithString: "100% Offline")
    private let dockBtn = NSButton()
    private let collapseBtn = NSButton()
    private let hideBtn = NSButton()

    var onToggleDock: (() -> Void)?
    var onCollapse: (() -> Void)?
    var onHide: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        setupUI()
    }

    required init?(coder: NSCoder) { nil }

    private func setupUI() {
        liveDot.wantsLayer = true
        liveDot.layer?.cornerRadius = 4
        liveDot.layer?.backgroundColor = NSColor.systemGray.cgColor
        liveDot.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = NSFont.systemFont(ofSize: 12.5, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        offlineBadge.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        offlineBadge.textColor = .systemGreen
        offlineBadge.wantsLayer = true
        offlineBadge.layer?.cornerRadius = 8
        offlineBadge.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.14).cgColor
        offlineBadge.alignment = .center
        offlineBadge.translatesAutoresizingMaskIntoConstraints = false

        configureButton(dockBtn, symbol: "sidebar.left", action: #selector(handleDock))
        configureButton(collapseBtn, symbol: "arrow.down.right.and.arrow.up.left", action: #selector(handleCollapse))
        configureButton(hideBtn, symbol: "xmark", action: #selector(handleHide))

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false

        [liveDot, titleLabel, offlineBadge, dockBtn, collapseBtn, hideBtn, divider].forEach { addSubview($0) }

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 36),

            liveDot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            liveDot.centerYAnchor.constraint(equalTo: centerYAnchor),
            liveDot.widthAnchor.constraint(equalToConstant: 8),
            liveDot.heightAnchor.constraint(equalToConstant: 8),

            titleLabel.leadingAnchor.constraint(equalTo: liveDot.trailingAnchor, constant: 7),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            offlineBadge.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 6),
            offlineBadge.centerYAnchor.constraint(equalTo: centerYAnchor),
            offlineBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 72),
            offlineBadge.heightAnchor.constraint(equalToConstant: 17),

            hideBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            hideBtn.centerYAnchor.constraint(equalTo: centerYAnchor),
            hideBtn.widthAnchor.constraint(equalToConstant: 24),
            hideBtn.heightAnchor.constraint(equalToConstant: 24),

            collapseBtn.trailingAnchor.constraint(equalTo: hideBtn.leadingAnchor, constant: -3),
            collapseBtn.centerYAnchor.constraint(equalTo: centerYAnchor),
            collapseBtn.widthAnchor.constraint(equalToConstant: 24),
            collapseBtn.heightAnchor.constraint(equalToConstant: 24),

            dockBtn.trailingAnchor.constraint(equalTo: collapseBtn.leadingAnchor, constant: -3),
            dockBtn.centerYAnchor.constraint(equalTo: centerYAnchor),
            dockBtn.widthAnchor.constraint(equalToConstant: 24),
            dockBtn.heightAnchor.constraint(equalToConstant: 24),

            divider.leadingAnchor.constraint(equalTo: leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func configureButton(_ btn: NSButton, symbol: String, action: Selector) {
        btn.isBordered = false
        btn.bezelStyle = .regularSquare
        btn.target = self
        btn.action = action
        btn.contentTintColor = .secondaryLabelColor
        if let img = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
            let cfg = NSImage.SymbolConfiguration(pointSize: 11.5, weight: .medium)
            btn.image = img.withSymbolConfiguration(cfg)
        }
        btn.translatesAutoresizingMaskIntoConstraints = false
    }

    func update(isActive: Bool, language: String, dockSide: String) {
        liveDot.layer?.backgroundColor = (isActive ? NSColor.systemGreen : NSColor.systemGray).cgColor
        let isEn = language == "en"
        offlineBadge.stringValue = isEn ? "100% Offline" : "ออฟไลน์ 100%"
        dockBtn.toolTip = isEn
            ? (dockSide == "left" ? "Move to right edge" : "Move to left edge")
            : (dockSide == "left" ? "ย้ายไปขอบขวา" : "ย้ายไปขอบซ้าย")
        collapseBtn.toolTip = isEn ? "Collapse to compact edge card" : "พับเป็นแถบจิ๋วติดขอบจอ"
        hideBtn.toolTip = isEn ? "Hide to Menu Bar" : "ซ่อนไว้ที่ Menu Bar"

        let dockSymbol = dockSide == "left" ? "sidebar.right" : "sidebar.left"
        if let img = NSImage(systemSymbolName: dockSymbol, accessibilityDescription: nil) {
            let cfg = NSImage.SymbolConfiguration(pointSize: 11.5, weight: .medium)
            dockBtn.image = img.withSymbolConfiguration(cfg)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    @objc private func handleDock() { onToggleDock?() }
    @objc private func handleCollapse() { onCollapse?() }
    @objc private func handleHide() { onHide?() }
}

// MARK: - Native Compact Floating Card (Collapsed Edge Mode)

@MainActor
final class CompactEdgeCardView: NSView {
    private let liveDot = NSView()
    private let modelLabel = NSTextField(labelWithString: "GraviHUD")
    private let expandIcon = NSImageView()
    private let tokensLabel = NSTextField(labelWithString: "--")
    private let cacheBadge = NSTextField(labelWithString: "--%")
    private let meterTrack = NSView()
    private let meterFill = NSView()
    private let ctxLabel = NSTextField(labelWithString: "0% ctx")
    private var meterFillWidth: NSLayoutConstraint?
    private var lastCtxRatio: CGFloat = 0

    private var dragStartScreenPoint: NSPoint = .zero
    private var dragStartWindowOrigin: NSPoint = .zero
    private var didDrag = false

    var onExpand: (() -> Void)?
    var onDragFinished: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        setupUI()
    }

    required init?(coder: NSCoder) { nil }

    private func setupUI() {
        liveDot.wantsLayer = true
        liveDot.layer?.cornerRadius = 3.5
        liveDot.layer?.backgroundColor = NSColor.systemGray.cgColor
        liveDot.translatesAutoresizingMaskIntoConstraints = false

        modelLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        modelLabel.textColor = .secondaryLabelColor
        modelLabel.lineBreakMode = .byTruncatingTail
        modelLabel.translatesAutoresizingMaskIntoConstraints = false

        if let img = NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: "Expand") {
            let cfg = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
            expandIcon.image = img.withSymbolConfiguration(cfg)
        }
        expandIcon.contentTintColor = .secondaryLabelColor
        expandIcon.translatesAutoresizingMaskIntoConstraints = false

        tokensLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 19, weight: .bold)
        tokensLabel.textColor = .labelColor
        tokensLabel.translatesAutoresizingMaskIntoConstraints = false

        cacheBadge.font = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .semibold)
        cacheBadge.textColor = .systemGreen
        cacheBadge.alignment = .center
        cacheBadge.wantsLayer = true
        cacheBadge.layer?.cornerRadius = 7
        cacheBadge.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.14).cgColor
        cacheBadge.translatesAutoresizingMaskIntoConstraints = false

        meterTrack.wantsLayer = true
        meterTrack.layer?.cornerRadius = 3
        meterTrack.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.10).cgColor
        meterTrack.translatesAutoresizingMaskIntoConstraints = false

        meterFill.wantsLayer = true
        meterFill.layer?.cornerRadius = 3
        meterFill.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        meterFill.translatesAutoresizingMaskIntoConstraints = false
        meterTrack.addSubview(meterFill)

        ctxLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        ctxLabel.textColor = .secondaryLabelColor
        ctxLabel.alignment = .right
        ctxLabel.translatesAutoresizingMaskIntoConstraints = false

        [liveDot, modelLabel, expandIcon, tokensLabel, cacheBadge, meterTrack, ctxLabel].forEach { addSubview($0) }

        let widthC = meterFill.widthAnchor.constraint(equalToConstant: 0)
        self.meterFillWidth = widthC

        NSLayoutConstraint.activate([
            liveDot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            liveDot.topAnchor.constraint(equalTo: topAnchor, constant: 13),
            liveDot.widthAnchor.constraint(equalToConstant: 7),
            liveDot.heightAnchor.constraint(equalToConstant: 7),

            modelLabel.leadingAnchor.constraint(equalTo: liveDot.trailingAnchor, constant: 6),
            modelLabel.centerYAnchor.constraint(equalTo: liveDot.centerYAnchor),
            modelLabel.trailingAnchor.constraint(lessThanOrEqualTo: expandIcon.leadingAnchor, constant: -6),

            expandIcon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -11),
            expandIcon.centerYAnchor.constraint(equalTo: liveDot.centerYAnchor),
            expandIcon.widthAnchor.constraint(equalToConstant: 12),
            expandIcon.heightAnchor.constraint(equalToConstant: 12),

            tokensLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            tokensLabel.topAnchor.constraint(equalTo: liveDot.bottomAnchor, constant: 6),

            cacheBadge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -11),
            cacheBadge.centerYAnchor.constraint(equalTo: tokensLabel.centerYAnchor),
            cacheBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 48),
            cacheBadge.heightAnchor.constraint(equalToConstant: 18),

            meterTrack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            meterTrack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -13),
            meterTrack.trailingAnchor.constraint(equalTo: ctxLabel.leadingAnchor, constant: -8),
            meterTrack.heightAnchor.constraint(equalToConstant: 6),

            meterFill.leadingAnchor.constraint(equalTo: meterTrack.leadingAnchor),
            meterFill.topAnchor.constraint(equalTo: meterTrack.topAnchor),
            meterFill.bottomAnchor.constraint(equalTo: meterTrack.bottomAnchor),
            widthC,

            ctxLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -11),
            ctxLabel.centerYAnchor.constraint(equalTo: meterTrack.centerYAnchor),
            ctxLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])
    }

    func update(conv: ConversationMetrics?, settings: AppSettings) {
        let isEn = settings.language == "en"
        guard let conv = conv else {
            liveDot.layer?.backgroundColor = NSColor.systemGray.cgColor
            modelLabel.stringValue = isEn ? "No chats yet" : "ยังไม่พบแชท"
            tokensLabel.stringValue = "0"
            cacheBadge.stringValue = "0%"
            ctxLabel.stringValue = "0% ctx"
            lastCtxRatio = 0
            updateMeterFillWidth()
            toolTip = isEn ? "Click to expand GraviHUD" : "คลิกเพื่อกางแผง GraviHUD"
            return
        }

        liveDot.layer?.backgroundColor = (conv.isActive ? NSColor.systemGreen : NSColor.systemGray).cgColor
        modelLabel.stringValue = conv.latestStep?.modelShort ?? "GraviHUD"
        tokensLabel.stringValue = formatCompactTokens(conv.totals.totalTokens)

        let cachePct = conv.totals.cacheHitPct
        cacheBadge.stringValue = String(format: "%.0f%%", cachePct)
        let cacheColor: NSColor = cachePct >= 75 ? .systemGreen : (cachePct >= 40 ? .systemBlue : .systemOrange)
        cacheBadge.textColor = cacheColor
        cacheBadge.layer?.backgroundColor = cacheColor.withAlphaComponent(0.15).cgColor

        let latestCtx = conv.latestStep?.contextTokens ?? 0
        let refLimit = max(1, settings.contextRefLimit)
        let ctxRatio = min(1.0, max(0.0, Double(latestCtx) / Double(refLimit)))
        let ctxPct = Int((ctxRatio * 100.0).rounded())
        ctxLabel.stringValue = "\(ctxPct)% ctx"

        let meterColor: NSColor = ctxPct >= 85 ? .systemRed : (ctxPct >= 65 ? .systemOrange : .controlAccentColor)
        meterFill.layer?.backgroundColor = meterColor.cgColor

        lastCtxRatio = CGFloat(ctxRatio)
        updateMeterFillWidth()

        toolTip = isEn
            ? "Click to expand · Drag to move"
            : "คลิกเพื่อกางแผงเต็ม · ลากเพื่อย้ายตำแหน่ง"
    }

    override func layout() {
        super.layout()
        updateMeterFillWidth()
    }

    private func updateMeterFillWidth() {
        let trackWidth = meterTrack.bounds.width > 0 ? meterTrack.bounds.width : 114.0
        meterFillWidth?.constant = max(0, lastCtxRatio * trackWidth)
    }

    private func formatCompactTokens(_ n: Int64) -> String {
        let d = Double(n)
        if d >= 1_000_000 { return String(format: "%.2fM", d / 1_000_000) }
        if d >= 10_000 { return String(format: "%.1fK", d / 1_000) }
        if d >= 1_000 { return String(format: "%.2fK", d / 1_000) }
        return "\(n)"
    }

    override func mouseDown(with event: NSEvent) {
        dragStartScreenPoint = NSEvent.mouseLocation
        dragStartWindowOrigin = window?.frame.origin ?? .zero
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let win = window else { return }
        let cur = NSEvent.mouseLocation
        let dx = cur.x - dragStartScreenPoint.x
        let dy = cur.y - dragStartScreenPoint.y
        if hypot(dx, dy) >= 4.0 {
            didDrag = true
        }
        if didDrag {
            win.setFrameOrigin(NSPoint(x: dragStartWindowOrigin.x + dx, y: dragStartWindowOrigin.y + dy))
        }
    }

    override func mouseUp(with event: NSEvent) {
        if didDrag {
            onDragFinished?()
        } else {
            onExpand?()
        }
    }
}

// MARK: - Main Floating Panel + Menu Bar Controller

@MainActor
final class FloatingPanelController: NSObject, NSWindowDelegate, WebUIBridgeDelegate {
    static let showNotificationName = Notification.Name("dev.kinatoshi99.gravihud.show")
    private static let antigravityBundlePrefix = "com.google.antigravity"
    private static let edgeMargin: CGFloat = 12
    private static let expandedWidth: CGFloat = 368
    private static let expandedMaxHeight: CGFloat = 680
    private static let collapsedSize = NSSize(width: 196, height: 86)

    private let scanner: TranscriptScanner
    private let settingsStore: SettingsStore
    private var settings: AppSettings

    private let panel: FloatingPanel
    private let effectView = NSVisualEffectView()
    private let expandedContainer = NSView()
    private let headerView = PanelHeaderView()
    private let webUI = OfflineWebUIController()
    private let compactView = CompactEdgeCardView()

    private var statusItem: NSStatusItem!
    private var statusSummaryItem: NSMenuItem!
    private var showHideItem: NSMenuItem!
    private var collapseExpandItem: NSMenuItem!
    private var onlyAgyItem: NSMenuItem!
    private var dockRightItem: NSMenuItem!
    private var dockLeftItem: NSMenuItem!
    private var refreshItem: NSMenuItem!
    private var revealDirItem: NSMenuItem!
    private var quitItem: NSMenuItem!

    private var selectedRange = "7d"
    private var selectedConvMode = "auto"
    private var lastSignature = ""
    private var latestPayload: TelemetryPayload?
    private var pollTimer: Timer?
    private var visibilityTimer: Timer?
    private var spaceSettleWorkItem: DispatchWorkItem?
    private var userManuallyHidden = false
    private var temporarilyPinnedVisible = false
    private var appearanceObservation: NSKeyValueObservation?

    override init() {
        self.scanner = TranscriptScanner()
        self.settingsStore = SettingsStore()
        self.settings = settingsStore.load()

        let initialRect = NSRect(x: 0, y: 0, width: Self.expandedWidth, height: 600)
        self.panel = FloatingPanel(
            contentRect: initialRect,
            styleMask: [.nonactivatingPanel, .borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        super.init()

        setupPanel()
        setupMenuBar()
        setupObservers()
        applyModeLayout(animated: false)
        refreshTelemetry(force: true)
        updateVisibilityForFrontmostApp(forceInitialShow: true)
    }

    // MARK: - Window & View Hierarchy

    private func setupPanel() {
        panel.delegate = self
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.worksWhenModal = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovable = false
        panel.isReleasedWhenClosed = false

        effectView.material = .popover
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 14
        effectView.layer?.masksToBounds = true
        effectView.layer?.borderWidth = 1.0
        effectView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.45).cgColor
        effectView.translatesAutoresizingMaskIntoConstraints = true
        effectView.autoresizingMask = [.width, .height]
        effectView.frame = panel.contentRect(forFrameRect: panel.frame)
        panel.contentView = effectView

        expandedContainer.translatesAutoresizingMaskIntoConstraints = false
        webUI.webView.translatesAutoresizingMaskIntoConstraints = false
        webUI.delegate = self

        headerView.onToggleDock = { [weak self] in self?.toggleDockSide() }
        headerView.onCollapse = { [weak self] in self?.setCollapsed(true) }
        headerView.onHide = { [weak self] in self?.hideManually() }

        expandedContainer.addSubview(headerView)
        expandedContainer.addSubview(webUI.webView)
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: expandedContainer.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: expandedContainer.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: expandedContainer.trailingAnchor),

            webUI.webView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            webUI.webView.leadingAnchor.constraint(equalTo: expandedContainer.leadingAnchor),
            webUI.webView.trailingAnchor.constraint(equalTo: expandedContainer.trailingAnchor),
            webUI.webView.bottomAnchor.constraint(equalTo: expandedContainer.bottomAnchor),
        ])

        compactView.onExpand = { [weak self] in self?.setCollapsed(false) }
        compactView.onDragFinished = { [weak self] in self?.snapAfterDrag() }

        effectView.addSubview(expandedContainer)
        effectView.addSubview(compactView)

        NSLayoutConstraint.activate([
            expandedContainer.topAnchor.constraint(equalTo: effectView.topAnchor),
            expandedContainer.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            expandedContainer.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            expandedContainer.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),

            compactView.topAnchor.constraint(equalTo: effectView.topAnchor),
            compactView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            compactView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            compactView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
        ])
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem.button {
            let symbol = NSImage(systemSymbolName: "chart.bar.xaxis", accessibilityDescription: "GraviHUD")
                ?? NSImage(systemSymbolName: "gauge.medium", accessibilityDescription: "GraviHUD")
            symbol?.isTemplate = true
            btn.image = symbol
            btn.toolTip = "GraviHUD (100% Offline)"
        }

        let menu = NSMenu()

        statusSummaryItem = NSMenuItem(title: "GraviHUD · 100% Offline", action: nil, keyEquivalent: "")
        statusSummaryItem.isEnabled = false
        menu.addItem(statusSummaryItem)
        menu.addItem(.separator())

        showHideItem = NSMenuItem(title: "", action: #selector(menuToggleShowHide), keyEquivalent: "")
        showHideItem.target = self
        menu.addItem(showHideItem)

        collapseExpandItem = NSMenuItem(title: "", action: #selector(menuToggleCollapse), keyEquivalent: "")
        collapseExpandItem.target = self
        menu.addItem(collapseExpandItem)
        menu.addItem(.separator())

        onlyAgyItem = NSMenuItem(title: "", action: #selector(menuToggleOnlyAntigravity), keyEquivalent: "")
        onlyAgyItem.target = self
        menu.addItem(onlyAgyItem)

        dockRightItem = NSMenuItem(title: "", action: #selector(menuDockRight), keyEquivalent: "")
        dockRightItem.target = self
        menu.addItem(dockRightItem)

        dockLeftItem = NSMenuItem(title: "", action: #selector(menuDockLeft), keyEquivalent: "")
        dockLeftItem.target = self
        menu.addItem(dockLeftItem)
        menu.addItem(.separator())

        refreshItem = NSMenuItem(title: "", action: #selector(menuRefreshNow), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        revealDirItem = NSMenuItem(title: "", action: #selector(menuRevealTranscriptDir), keyEquivalent: "")
        revealDirItem.target = self
        menu.addItem(revealDirItem)
        menu.addItem(.separator())

        quitItem = NSMenuItem(title: "", action: #selector(menuQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        updateMenuLabels()
    }

    private func updateMenuLabels() {
        let isEn = settings.language == "en"
        let visible = panel.isVisible

        if let conv = latestPayload?.activeConversation {
            let tok = formatMenuTokens(conv.totals.totalTokens)
            let hit = String(format: "%.0f%%", conv.totals.cacheHitPct)
            statusSummaryItem.title = isEn
                ? "Offline · \(tok) tok · Cache \(hit)"
                : "ออฟไลน์ 100% · \(tok) โทเคน · แคช \(hit)"
        } else {
            statusSummaryItem.title = isEn ? "GraviHUD · 100% Offline" : "GraviHUD · ออฟไลน์ 100%"
        }

        showHideItem.title = visible
            ? (isEn ? "Hide Floating Panel" : "ซ่อนแผงลอย")
            : (isEn ? "Show Floating Panel" : "แสดงแผงลอย")

        collapseExpandItem.title = settings.collapsed
            ? (isEn ? "Expand Full Panel" : "กางแผงเต็ม (4 แท็บ)")
            : (isEn ? "Collapse to Compact Card" : "พับเป็นแถบจิ๋วติดขอบจอ")

        onlyAgyItem.title = isEn ? "Only Show with Antigravity" : "โผล่เฉพาะตอนใช้ Antigravity"
        onlyAgyItem.state = settings.onlyWhenAntigravityActive ? .on : .off

        dockRightItem.title = isEn ? "Dock Right Edge" : "วางติดขอบขวา"
        dockRightItem.state = settings.dockSide != "left" ? .on : .off

        dockLeftItem.title = isEn ? "Dock Left Edge" : "วางติดขอบซ้าย"
        dockLeftItem.state = settings.dockSide == "left" ? .on : .off

        refreshItem.title = isEn ? "Refresh Now" : "รีเฟรชข้อมูลตอนนี้"
        revealDirItem.title = isEn ? "Reveal Transcript Folder (Read-only)" : "เปิดโฟลเดอร์ไฟล์บันทึกแชทใน Finder"
        quitItem.title = isEn ? "Quit GraviHUD" : "ออกจาก GraviHUD"
    }

    private func formatMenuTokens(_ n: Int64) -> String {
        let d = Double(n)
        if d >= 1_000_000 { return String(format: "%.2fM", d / 1_000_000) }
        if d >= 10_000 { return String(format: "%.1fK", d / 1_000) }
        if d >= 1_000 { return String(format: "%.2fK", d / 1_000) }
        return "\(n)"
    }

    // MARK: - Workspace & Appearance Observers

    private func setupObservers() {
        let wsCenter = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.activeSpaceDidChangeNotification,
            NSWorkspace.didWakeNotification,
        ]
        for name in names {
            wsCenter.addObserver(self, selector: #selector(workspaceDidChange(_:)), name: name, object: nil)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleExternalShowRequest),
            name: Self.showNotificationName,
            object: nil
        )

        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                self?.syncTheme()
            }
        }

        // Lightweight safety-net timer (reads only in-memory frontmostApplication; zero disk/network I/O)
        // so Full-Screen Space transitions or wake-from-sleep can never leave the panel out of sync.
        visibilityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateVisibilityForFrontmostApp(activatedApp: nil, fromSpaceChange: false)
            }
        }
    }

    private func isDarkAppearance() -> Bool {
        let match = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        return match == .darkAqua
    }

    private func syncTheme() {
        let dark = isDarkAppearance()
        effectView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(dark ? 0.55 : 0.40).cgColor
        webUI.pushTheme(darkMode: dark)
    }

    // MARK: - Antigravity Frontmost Detection (Public NSWorkspace API Only)

    private func isAntigravityApp(_ app: NSRunningApplication?) -> Bool {
        guard let app = app else { return false }
        if let bid = app.bundleIdentifier?.lowercased() {
            if bid == Self.antigravityBundlePrefix || bid.hasPrefix(Self.antigravityBundlePrefix + ".") {
                return true
            }
        }
        if let name = app.localizedName?.lowercased(), name == "antigravity" {
            return true
        }
        return false
    }

    private func isAntigravityRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { isAntigravityApp($0) && !$0.isTerminated }
    }

    private func shouldBeVisibleNow(activatedApp: NSRunningApplication? = nil) -> Bool {
        if userManuallyHidden { return false }
        if !settings.onlyWhenAntigravityActive { return true }
        if temporarilyPinnedVisible { return true }

        let front = activatedApp ?? NSWorkspace.shared.frontmostApplication
        if isAntigravityApp(front) {
            return true
        }
        if let front = front, front.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            return isAntigravityRunning()
        }
        return false
    }

    private func surfacePanelAboveActiveSpace(reposition: Bool) {
        if reposition {
            positionPanelOnEdge(animated: false)
        }
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.orderFrontRegardless()
    }

    private func scheduleFullScreenSettleReassert() {
        spaceSettleWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                if self.shouldBeVisibleNow() {
                    self.surfacePanelAboveActiveSpace(reposition: true)
                }
            }
        }
        spaceSettleWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30, execute: item)
    }

    private func updateVisibilityForFrontmostApp(
        activatedApp: NSRunningApplication? = nil,
        fromSpaceChange: Bool = false,
        forceInitialShow: Bool = false
    ) {
        let show = shouldBeVisibleNow(activatedApp: activatedApp)
        if show {
            let wasHidden = !panel.isVisible
            if wasHidden {
                refreshTelemetry(force: true)
            }
            if wasHidden || fromSpaceChange || activatedApp != nil || forceInitialShow {
                surfacePanelAboveActiveSpace(reposition: wasHidden || fromSpaceChange)
                if fromSpaceChange || activatedApp != nil {
                    scheduleFullScreenSettleReassert()
                }
            }
            startPolling()
        } else {
            spaceSettleWorkItem?.cancel()
            if panel.isVisible {
                panel.orderOut(nil)
            }
            stopPolling()
        }
        updateMenuLabels()
    }

    @objc private func workspaceDidChange(_ note: Notification) {
        let activatedApp: NSRunningApplication?
        if note.name == NSWorkspace.didActivateApplicationNotification {
            activatedApp = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            if let app = activatedApp,
               app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                temporarilyPinnedVisible = false
            }
        } else {
            activatedApp = nil
        }
        let isSpaceChange = (note.name == NSWorkspace.activeSpaceDidChangeNotification || note.name == NSWorkspace.didWakeNotification)
        updateVisibilityForFrontmostApp(activatedApp: activatedApp, fromSpaceChange: isSpaceChange)
    }

    @objc private func screenDidChange() {
        positionPanelOnEdge(animated: false)
    }

    @objc func handleExternalShowRequest() {
        userManuallyHidden = false
        temporarilyPinnedVisible = true
        refreshTelemetry(force: true)
        surfacePanelAboveActiveSpace(reposition: true)
        scheduleFullScreenSettleReassert()
        startPolling()
        updateMenuLabels()
    }

    // MARK: - Window Positioning, Collapse & Drag

    private func currentScreen() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        if let underMouse = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) {
            return underMouse
        }
        if panel.isVisible, let ps = panel.screen {
            return ps
        }
        return NSScreen.main ?? NSScreen.screens.first!
    }

    private func computeFrame(collapsed: Bool, dockSide: String, verticalRatio: Double) -> NSRect {
        let vf = currentScreen().visibleFrame
        let margin = Self.edgeMargin

        let size: NSSize
        if collapsed {
            size = Self.collapsedSize
        } else {
            let maxH = max(440, vf.height - margin * 2)
            let targetH = min(Self.expandedMaxHeight, maxH)
            size = NSSize(width: Self.expandedWidth, height: targetH)
        }

        let x: CGFloat = (dockSide == "left")
            ? (vf.minX + margin)
            : (vf.maxX - size.width - margin)

        let minY = vf.minY + margin
        let maxY = max(minY, vf.maxY - size.height - margin)
        let y: CGFloat = collapsed
            ? (minY + CGFloat(verticalRatio) * (maxY - minY))
            : maxY
        return NSRect(origin: NSPoint(x: x, y: y), size: size)
    }

    private func applyModeLayout(animated: Bool) {
        let collapsed = settings.collapsed
        expandedContainer.isHidden = collapsed
        compactView.isHidden = !collapsed

        if collapsed {
            panel.styleMask.remove(.resizable)
            panel.minSize = Self.collapsedSize
            panel.maxSize = Self.collapsedSize
        } else {
            panel.styleMask.insert(.resizable)
            panel.minSize = NSSize(width: 320, height: 420)
            panel.maxSize = NSSize(width: 560, height: 1400)
        }

        positionPanelOnEdge(animated: animated)
        headerView.update(
            isActive: latestPayload?.activeConversation?.isActive ?? false,
            language: settings.language,
            dockSide: settings.dockSide
        )
        compactView.update(conv: latestPayload?.activeConversation, settings: settings)
        updateMenuLabels()
    }

    private func positionPanelOnEdge(animated: Bool) {
        let target = computeFrame(
            collapsed: settings.collapsed,
            dockSide: settings.dockSide,
            verticalRatio: settings.verticalRatio
        )
        panel.setFrame(target, display: true, animate: animated)
    }

    private func snapAfterDrag() {
        let vf = currentScreen().visibleFrame
        let f = panel.frame
        let midX = f.midX
        let nextSide = (midX < vf.midX) ? "left" : "right"
        let minY = vf.minY + Self.edgeMargin
        let maxY = max(minY, vf.maxY - f.height - Self.edgeMargin)
        let ratio = maxY > minY ? Double((f.minY - minY) / (maxY - minY)) : 0.85

        settings.dockSide = nextSide
        settings.verticalRatio = min(0.95, max(0.05, ratio))
        settings = settingsStore.save(settings)
        positionPanelOnEdge(animated: true)
        pushCurrentSettings()
    }

    func windowDidMove(_ notification: Notification) {
        guard !settings.collapsed else { return }
        let vf = currentScreen().visibleFrame
        let f = panel.frame
        let nextSide = f.midX < vf.midX ? "left" : "right"
        if nextSide != settings.dockSide {
            settings.dockSide = nextSide
            settings = settingsStore.save(settings)
            headerView.update(
                isActive: latestPayload?.activeConversation?.isActive ?? false,
                language: settings.language,
                dockSide: settings.dockSide
            )
            updateMenuLabels()
        }
    }

    // MARK: - Polling & Telemetry

    private func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshTelemetry(force: false)
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func refreshTelemetry(force: Bool) {
        let (conversations, sig) = scanner.scanAllConversations()
        let activeConv: ConversationMetrics?
        if selectedConvMode != "auto", let found = conversations.first(where: { $0.conversationId == selectedConvMode }) {
            activeConv = found
        } else {
            activeConv = conversations.first
        }

        let settingsData = (try? JSONEncoder().encode(settings)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let compositeSig = "\(sig)|\(selectedConvMode)|\(activeConv?.conversationId ?? "")|\(selectedRange)|\(settingsData)"
        if !force && compositeSig == lastSignature {
            return
        }
        lastSignature = compositeSig

        let history = TranscriptScanner.buildHistoryAggregation(conversations: conversations, range: selectedRange)
        let listItems = conversations.prefix(40).map { c in
            ConversationListItem(
                conversationId: c.conversationId,
                title: c.title,
                lastActivityMs: c.lastActivityMs,
                isActive: c.isActive,
                modelStepCount: c.modelStepCount,
                totalTokens: c.totals.totalTokens,
                costUsd: c.totals.costUsd,
                latestModelShort: c.latestStep?.modelShort ?? ""
            )
        }

        let payload = TelemetryPayload(
            generatedAtMs: Int64(Date().timeIntervalSince1970 * 1000),
            settings: settings,
            meta: TelemetryMeta(
                offlineOnly: true,
                zeroPorts: true,
                brainDir: scanner.brainDir.path,
                settingsFile: settingsStore.settingsURL.path,
                scannedConversations: conversations.count,
                pricingEntries: OfflinePricing.entries.count,
                autoFollowingLatest: selectedConvMode == "auto",
                antigravityRunning: isAntigravityRunning()
            ),
            selectedConvMode: selectedConvMode,
            activeConversation: activeConv,
            conversations: listItems,
            history: history
        )

        latestPayload = payload
        headerView.update(
            isActive: activeConv?.isActive ?? false,
            language: settings.language,
            dockSide: settings.dockSide
        )
        compactView.update(conv: activeConv, settings: settings)
        webUI.pushTelemetry(payload, darkMode: isDarkAppearance())
        updateMenuLabels()
    }

    private func pushCurrentSettings() {
        lastSignature = ""
        refreshTelemetry(force: true)
    }

    // MARK: - Actions

    private func setCollapsed(_ collapsed: Bool) {
        guard settings.collapsed != collapsed else { return }
        settings.collapsed = collapsed
        settings = settingsStore.save(settings)
        applyModeLayout(animated: true)
        pushCurrentSettings()
    }

    private func toggleDockSide() {
        settings.dockSide = (settings.dockSide == "left") ? "right" : "left"
        settings = settingsStore.save(settings)
        applyModeLayout(animated: true)
        pushCurrentSettings()
    }

    private func hideManually() {
        userManuallyHidden = true
        temporarilyPinnedVisible = false
        spaceSettleWorkItem?.cancel()
        panel.orderOut(nil)
        stopPolling()
        updateMenuLabels()
    }

    // MARK: - Menu Actions

    @objc private func menuToggleShowHide() {
        if panel.isVisible {
            hideManually()
        } else {
            userManuallyHidden = false
            temporarilyPinnedVisible = true
            refreshTelemetry(force: true)
            surfacePanelAboveActiveSpace(reposition: true)
            scheduleFullScreenSettleReassert()
            startPolling()
            updateMenuLabels()
        }
    }

    @objc private func menuToggleCollapse() {
        setCollapsed(!settings.collapsed)
        if !panel.isVisible && !userManuallyHidden {
            updateVisibilityForFrontmostApp()
        }
    }

    @objc private func menuToggleOnlyAntigravity() {
        settings.onlyWhenAntigravityActive.toggle()
        settings = settingsStore.save(settings)
        updateVisibilityForFrontmostApp()
        pushCurrentSettings()
    }

    @objc private func menuDockRight() {
        settings.dockSide = "right"
        settings = settingsStore.save(settings)
        applyModeLayout(animated: true)
        pushCurrentSettings()
    }

    @objc private func menuDockLeft() {
        settings.dockSide = "left"
        settings = settingsStore.save(settings)
        applyModeLayout(animated: true)
        pushCurrentSettings()
    }

    @objc private func menuRefreshNow() {
        refreshTelemetry(force: true)
    }

    @objc private func menuRevealTranscriptDir() {
        NSWorkspace.shared.activateFileViewerSelecting([scanner.brainDir])
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }

    // MARK: - WebUIBridgeDelegate

    func webUIDidBecomeReady() {
        refreshTelemetry(force: true)
    }

    func webUIRequestedRefresh() {
        refreshTelemetry(force: true)
    }

    func webUISelectedRange(_ range: String) {
        guard ["today", "7d", "30d", "all"].contains(range) else { return }
        selectedRange = range
        refreshTelemetry(force: true)
    }

    func webUISelectedConversation(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed == "auto" || trimmed.isEmpty {
            selectedConvMode = "auto"
        } else if TranscriptScanner.isValidUUID(trimmed) {
            selectedConvMode = trimmed
        }
        refreshTelemetry(force: true)
    }

    func webUIUpdatedSettings(_ patch: [String: Any]) {
        let prevDock = settings.dockSide
        let prevCollapsed = settings.collapsed
        let prevOnlyAgy = settings.onlyWhenAntigravityActive

        settings = settingsStore.applyPatch(patch, to: settings)
        if settings.dockSide != prevDock || settings.collapsed != prevCollapsed {
            applyModeLayout(animated: true)
        }
        if settings.onlyWhenAntigravityActive != prevOnlyAgy {
            updateVisibilityForFrontmostApp()
        }
        pushCurrentSettings()
    }

    func webUIResetSettings() {
        settings = settingsStore.reset()
        applyModeLayout(animated: true)
        updateVisibilityForFrontmostApp()
        pushCurrentSettings()
    }
}
