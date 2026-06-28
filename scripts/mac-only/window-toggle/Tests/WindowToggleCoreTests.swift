import CoreGraphics
import Foundation

let screens = [
    CGRect(x: 0, y: 0, width: 1920, height: 1080),
    CGRect(x: 94, y: 1080, width: 1728, height: 1117),
]

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

func testBoundsEncoding() {
    let bounds = WindowBounds(origin: CGPoint(x: 8.9, y: 38.1), size: CGSize(width: 1904.7, height: 1042.2))
    expect(encode(bounds) == "8,38,1904,1042", "encode stores integer bounds")
    expect(decode("8,38,1904,1042") == WindowBounds(origin: CGPoint(x: 8, y: 38), size: CGSize(width: 1904, height: 1042)), "decode parses bounds")
    expect(decode("nope") == nil, "decode rejects invalid bounds")
    expect(decodeMany("1,2,3,4\n5,6,7,8").count == 2, "decodeMany parses newline bounds")
}

func testScreenClassificationUsesCoreGraphicsCoordinates() {
    let main = WindowBounds(origin: CGPoint(x: 8, y: 38), size: CGSize(width: 1904, height: 1042))
    let second = WindowBounds(origin: CGPoint(x: 102, y: 1120), size: CGSize(width: 1712, height: 1069))

    expect(isOnMainScreen(main, screens: screens), "main window is on main screen")
    expect(!isOnMainScreen(second, screens: screens), "second-display window is not on main screen")
    expect(isOnAnyScreen(second, screens: screens), "second-display window is still on a screen")
}

func testCornerParkingMatchesAeroSpaceStyle() {
    let bounds = WindowBounds(origin: CGPoint(x: 8, y: 38), size: CGSize(width: 1904, height: 1042))
    let parked = WindowBounds(origin: parkedPoint(for: bounds, screens: screens), size: bounds.size)

    expect(parked.origin == CGPoint(x: 1919, y: 1079), "parked point is bottom-right minus one pixel")
    expect(isParked(parked, screens: screens), "corner-parked window is detected as parked")
}

func testPlannerFocusesMainWindowsBeforeParking() {
    let windows = [
        WindowSnapshot(id: 1, bounds: WindowBounds(origin: CGPoint(x: 8, y: 38), size: CGSize(width: 900, height: 900)), isFocused: false),
        WindowSnapshot(id: 2, bounds: WindowBounds(origin: CGPoint(x: 980, y: 38), size: CGSize(width: 900, height: 900)), isFocused: false),
        WindowSnapshot(id: 3, bounds: WindowBounds(origin: CGPoint(x: 102, y: 1120), size: CGSize(width: 900, height: 900)), isFocused: true),
    ]

    expect(planToggle(windows: windows, screens: screens, savedBoundsText: "") == [.focus(ids: [1, 2])], "planner focuses all main-screen windows first")
}

func testPlannerParksAllFocusedMainWindows() {
    let windows = [
        WindowSnapshot(id: 1, bounds: WindowBounds(origin: CGPoint(x: 8, y: 38), size: CGSize(width: 900, height: 900)), isFocused: true),
        WindowSnapshot(id: 2, bounds: WindowBounds(origin: CGPoint(x: 980, y: 38), size: CGSize(width: 900, height: 900)), isFocused: false),
        WindowSnapshot(id: 3, bounds: WindowBounds(origin: CGPoint(x: 102, y: 1120), size: CGSize(width: 900, height: 900)), isFocused: false),
    ]

    let actions = planToggle(windows: windows, screens: screens, savedBoundsText: "")
    expect(actions.count == 3, "planner saves and parks two main-screen windows")
    expect(actions[0] == .save("8,38,900,900\n980,38,900,900"), "planner saves main-screen bounds")
    expect(actions[1] == .park(id: 1, point: CGPoint(x: 1919, y: 1079)), "planner parks first main-screen window")
    expect(actions[2] == .park(id: 2, point: CGPoint(x: 1919, y: 1079)), "planner parks second main-screen window")
}

func testPlannerRestoresParkedWindowsThenFocusesGroup() {
    let windows = [
        WindowSnapshot(id: 1, bounds: WindowBounds(origin: CGPoint(x: 1919, y: 1079), size: CGSize(width: 900, height: 900)), isFocused: false),
        WindowSnapshot(id: 2, bounds: WindowBounds(origin: CGPoint(x: 1919, y: 1079), size: CGSize(width: 900, height: 900)), isFocused: false),
    ]
    let saved = "8,38,900,900\n980,38,900,900"

    let actions = planToggle(windows: windows, screens: screens, savedBoundsText: saved)
    expect(actions == [
        .restore(id: 1, bounds: WindowBounds(origin: CGPoint(x: 8, y: 38), size: CGSize(width: 900, height: 900))),
        .restore(id: 2, bounds: WindowBounds(origin: CGPoint(x: 980, y: 38), size: CGSize(width: 900, height: 900))),
        .focus(ids: [1, 2]),
    ], "planner restores all parked windows and focuses the group")
}

@main
struct TestRunner {
    static func main() {
        testBoundsEncoding()
        testScreenClassificationUsesCoreGraphicsCoordinates()
        testCornerParkingMatchesAeroSpaceStyle()
        testPlannerFocusesMainWindowsBeforeParking()
        testPlannerParksAllFocusedMainWindows()
        testPlannerRestoresParkedWindowsThenFocusesGroup()
    }
}
