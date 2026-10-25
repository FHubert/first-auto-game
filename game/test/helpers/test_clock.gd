class_name TestClock
extends RefCounted
## Shared fixed clock for suites that build App/Home (result independent of system time).
## Not a test suite: do not extend GdUnitTestSuite.

const FIXED_UNIX: int = 1792843200  # 2026-10-24 12:00 UTC (= ScreenshotArgs.SCREENSHOT_NOW_UNIX)
const FIXED_DAY: int = 20750


## Constant clock returning FIXED_UNIX.
static func fixed() -> Callable:
	return func() -> int: return FIXED_UNIX


## Clock reading t[0] (unix seconds); the test advances time by mutating t.
static func ticking(t: Array) -> Callable:
	return func() -> int: return t[0]


## Float clock reading t[0] (seconds). Classes taking a `float` clock: ConsentFlow, AdService
## (`Ads.clock`); `ticking` (int) is for unix-time clocks (App, Home).
static func ticking_float(t: Array) -> Callable:
	return func() -> float: return t[0]
