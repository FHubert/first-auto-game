extends GdUnitTestSuite
## Provider contracts checked before Phase 5 SDK adapters are wired in.
## Checked per base/fake pair (methods DEFINED in each script, not inherited):
##  (a) every public fake override has the same name and argument count as in the base,
##  (b) public fake methods absent from the base are only the FAKE_ONLY test hooks,
##  (c) the base no-op never poses as a working SDK (bool -> false, Dictionary/Array -> empty).
## A fake that does not override a base method satisfies the contract by inheritance.
## New SDK adapters: add a pair to PAIRS (see docs/RELEASE_CHECKLIST.md).

const DIR: String = "res://src/systems/"
const PAIRS: Array = [
	["ad_provider.gd", "fake_ad_provider.gd"],
	["iap_provider.gd", "fake_iap_provider.gd"],
	["consent_provider.gd", "fake_consent_provider.gd"],
	["notification_provider.gd", "fake_notification_provider.gd"],
	["analytics_provider.gd", "fake_analytics_provider.gd"],
]
## Key = fake script file name; value = public test hooks that the base lacks.
const FAKE_ONLY: Dictionary = {
	# Completes a held rewarded/interstitial ad (hold_show mode).
	"fake_ad_provider.gd": ["release", "release_at", "fail_next_loads", "release_load"],
	# Answers a held UMP form / ATT prompt (hold_form / hold_att mode).
	"fake_consent_provider.gd": ["release_form", "release_att"],
	# Answers a held system notification permission request (hold_permission mode).
	"fake_notification_provider.gd": ["release_permission"],
}
## Safe arguments for base methods with required parameters (bool/Dictionary/Array returns).
const NOOP_ARGS: Dictionary = {}


func _public(script: Script) -> Dictionary:
	var out: Dictionary = {}
	for m: Dictionary in script.get_script_method_list():
		var n: String = m["name"]
		if not n.begins_with("_"):
			out[n] = m
	return out


func test_pairs_not_empty() -> void:
	assert_int(PAIRS.size()).is_equal(5)


func test_fake_overrides_match_base_signatures() -> void:
	for pair: Array in PAIRS:
		var base := _public(load(DIR + pair[0]))
		var fake := _public(load(DIR + pair[1]))
		for n: String in fake:
			if base.has(n):
				var same: bool = base[n]["args"].size() == fake[n]["args"].size()
				var msg := "%s.%s: arg count differs" % [pair[1], n]
				assert_bool(same).override_failure_message(msg).is_true()


func test_fake_extra_public_methods_are_whitelisted() -> void:
	for pair: Array in PAIRS:
		var base := _public(load(DIR + pair[0]))
		var fake := _public(load(DIR + pair[1]))
		var allowed: Array = FAKE_ONLY.get(pair[1], [])
		for n: String in fake:
			if not base.has(n):
				var ok: bool = allowed.has(n)
				var msg := "%s: unlisted extra method %s" % [pair[1], n]
				assert_bool(ok).override_failure_message(msg).is_true()


func test_base_noop_never_claims_to_work() -> void:
	for pair: Array in PAIRS:
		var script: Script = load(DIR + pair[0])
		var inst: Object = script.new()
		for n: String in _public(script):
			var m: Dictionary = _public(script)[n]
			var t: int = m["return"]["type"]
			if t != TYPE_BOOL and t != TYPE_DICTIONARY and t != TYPE_ARRAY:
				continue
			var args: Array = NOOP_ARGS.get(pair[0] + "." + n, [])
			var res: Variant = inst.callv(n, args)
			var msg := "%s.%s no-op must be false/empty" % [pair[0], n]
			if t == TYPE_BOOL:
				assert_bool(res as bool).override_failure_message(msg).is_false()
			else:
				assert_bool(res.is_empty()).override_failure_message(msg).is_true()
