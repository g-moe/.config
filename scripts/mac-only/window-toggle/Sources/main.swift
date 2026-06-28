import AppKit
import ApplicationServices
import Foundation

struct Config {
    var appName: String
    var bundleIdentifier: String
    var stateFileName: String
}

let config = Config(
    appName: CommandLine.arguments.dropFirst().first ?? "",
    bundleIdentifier: CommandLine.arguments.dropFirst(2).first ?? "",
    stateFileName: CommandLine.arguments.dropFirst(3).first ?? "window-toggle.state"
)

let stateURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(config.stateFileName)

func get(_ element: AXUIElement, _ attribute: CFString) -> AnyObject? {
    var value: AnyObject?
    return AXUIElementCopyAttributeValue(element, attribute, &value) == .success ? value : nil
}

func set(_ element: AXUIElement, _ attribute: CFString, _ value: AnyObject) {
    AXUIElementSetAttributeValue(element, attribute, value)
}

func point(_ element: AXUIElement) -> CGPoint? {
    guard let value = get(element, kAXPositionAttribute as CFString) else { return nil }
    var point = CGPoint.zero
    AXValueGetValue(value as! AXValue, .cgPoint, &point)
    return point
}

func size(_ element: AXUIElement) -> CGSize? {
    guard let value = get(element, kAXSizeAttribute as CFString) else { return nil }
    var size = CGSize.zero
    AXValueGetValue(value as! AXValue, .cgSize, &size)
    return size
}

func setPoint(_ element: AXUIElement, _ point: CGPoint) {
    var point = point
    set(element, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &point)!)
}

func setSize(_ element: AXUIElement, _ size: CGSize) {
    var size = size
    set(element, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!)
}

func activeScreens() -> [CGRect] {
    var count: UInt32 = 0
    CGGetActiveDisplayList(0, nil, &count)
    var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
    CGGetActiveDisplayList(count, &displays, &count)
    return displays.map(CGDisplayBounds)
}

func focus(_ ids: [Int], windows: [AXUIElement], app: NSRunningApplication, axApp: AXUIElement) {
    app.activate(options: [])

    for id in ids.reversed() {
        AXUIElementPerformAction(windows[id], kAXRaiseAction as CFString)
    }

    guard let id = ids.first else { return }
    let window = windows[id]
    set(window, kAXMainAttribute as CFString, kCFBooleanTrue)
    set(axApp, kAXFocusedWindowAttribute as CFString, window)
    AXUIElementPerformAction(window, kAXRaiseAction as CFString)
}

let app = NSWorkspace.shared.runningApplications.first {
    $0.bundleIdentifier == config.bundleIdentifier || $0.localizedName == config.appName
}
guard let app, app.processIdentifier > 0 else { exit(0) }

let axApp = AXUIElementCreateApplication(app.processIdentifier)
guard let axWindows = get(axApp, kAXWindowsAttribute as CFString) as? [AXUIElement] else { exit(0) }

let focused = get(axApp, kAXFocusedWindowAttribute as CFString)
let snapshots = axWindows.enumerated().compactMap { index, window -> WindowSnapshot? in
    guard let point = point(window), let size = size(window) else { return nil }
    return WindowSnapshot(
        id: index,
        bounds: WindowBounds(origin: point, size: size),
        isFocused: app.isActive && focused != nil && CFEqual(focused, window)
    )
}

let savedBounds = (try? String(contentsOf: stateURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""

for action in planToggle(windows: snapshots, screens: activeScreens(), savedBoundsText: savedBounds) {
    switch action {
        case .restore(let id, let bounds):
            guard axWindows.indices.contains(id) else { continue }
            setPoint(axWindows[id], bounds.origin)
            setSize(axWindows[id], bounds.size)
            AXUIElementPerformAction(axWindows[id], kAXRaiseAction as CFString)
        case .focus(let ids):
            focus(ids, windows: axWindows, app: app, axApp: axApp)
        case .park(let id, let point):
            guard axWindows.indices.contains(id) else { continue }
            setPoint(axWindows[id], point)
        case .save(let text):
            try? text.write(to: stateURL, atomically: true, encoding: .utf8)
    }
}
