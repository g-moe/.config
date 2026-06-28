import CoreGraphics
import Foundation

struct WindowBounds: Equatable {
    var origin: CGPoint
    var size: CGSize
}

struct WindowSnapshot: Equatable {
    var id: Int
    var bounds: WindowBounds
    var isFocused: Bool
}

enum WindowAction: Equatable {
    case restore(id: Int, bounds: WindowBounds)
    case focus(ids: [Int])
    case park(id: Int, point: CGPoint)
    case save(String)
}

func encode(_ bounds: WindowBounds) -> String {
    "\(Int(bounds.origin.x)),\(Int(bounds.origin.y)),\(Int(bounds.size.width)),\(Int(bounds.size.height))"
}

func decode(_ text: String) -> WindowBounds? {
    let parts = text.split(separator: ",").compactMap { Double($0) }
    guard parts.count == 4 else { return nil }
    return WindowBounds(
        origin: CGPoint(x: parts[0], y: parts[1]),
        size: CGSize(width: parts[2], height: parts[3])
    )
}

func decodeMany(_ text: String) -> [WindowBounds] {
    text.split(separator: "\n").compactMap { decode(String($0)) }
}

func center(of bounds: WindowBounds) -> CGPoint {
    CGPoint(
        x: bounds.origin.x + bounds.size.width / 2,
        y: bounds.origin.y + bounds.size.height / 2
    )
}

func screen(containing bounds: WindowBounds, screens: [CGRect]) -> CGRect? {
    let center = center(of: bounds)
    return screens.first { $0.contains(center) }
}

func isOnMainScreen(_ bounds: WindowBounds, screens: [CGRect]) -> Bool {
    guard let main = screens.first else { return false }
    return main.contains(center(of: bounds))
}

func isOnAnyScreen(_ bounds: WindowBounds, screens: [CGRect]) -> Bool {
    screen(containing: bounds, screens: screens) != nil
}

func parkedPoint(for bounds: WindowBounds, screens: [CGRect]) -> CGPoint {
    let screen = screen(containing: bounds, screens: screens) ?? screens.first ?? .zero
    return CGPoint(x: screen.maxX - 1, y: screen.maxY - 1)
}

func isParked(_ bounds: WindowBounds, screens: [CGRect]) -> Bool {
    if !isOnAnyScreen(bounds, screens: screens) || bounds.size.width <= 2 || bounds.size.height <= 2 {
        return true
    }

    return screens.contains { screen in
        abs(bounds.origin.x - (screen.maxX - 1)) <= 2 &&
            abs(bounds.origin.y - (screen.maxY - 1)) <= 2
    }
}

func planToggle(windows: [WindowSnapshot], screens: [CGRect], savedBoundsText: String) -> [WindowAction] {
    let parked = windows.filter { isParked($0.bounds, screens: screens) }
    let savedBounds = decodeMany(savedBoundsText)

    if !parked.isEmpty {
        var actions = zip(parked, savedBounds).map { WindowAction.restore(id: $0.id, bounds: $1) }
        let restoredIds = parked.map(\.id)
        actions.append(.focus(ids: restoredIds))
        return actions
    }

    let targets = windows.filter { isOnMainScreen($0.bounds, screens: screens) }
    if targets.isEmpty { return [] }

    if !targets.contains(where: \.isFocused) {
        return [.focus(ids: targets.map(\.id))]
    }

    let saved = targets.map { encode($0.bounds) }.joined(separator: "\n")
    return [.save(saved)] + targets.map { .park(id: $0.id, point: parkedPoint(for: $0.bounds, screens: screens)) }
}
