class_name ErrorReporter
extends RefCounted
## Zbiera bledy silnika (z dowolnego watku) i wysyla je do analityki z deduplikacja
## i limitem na sesje (T-296). `ingest` tylko dopisuje do bufora; `flush` na watku glownym.

const MAX_MESSAGE_LEN: int = 256

var _mutex: Mutex = Mutex.new()
var _pending: Array[String] = []
var _sent: Dictionary = {}
var _sent_count: int = 0
var _digits: RegEx = RegEx.create_from_string("\\d+")


## Bezpieczne watkowo: tylko dopisanie do bufora (bez print/push_error - rekurencja).
func ingest(file: String, line: int, rationale: String, error_type: int, code: String = "") -> void:
	if error_type == Logger.ERROR_TYPE_WARNING:
		return
	# push_error/assert: tresc bywa w `code`, a `rationale` pusty
	var text: String = "%s:%d %s" % [file, line, rationale if not rationale.is_empty() else code]
	_mutex.lock()
	if _pending.size() < 1000:
		_pending.append(text)
	_mutex.unlock()


## Wysyla nowe sygnatury (1x na sygnature, do limitu sesji); zwraca liczbe wyslanych.
func flush(analytics: Object) -> int:
	_mutex.lock()
	var batch: Array[String] = _pending.duplicate()
	_pending.clear()
	_mutex.unlock()
	var limit: int = int(GameConfig.get_value("error_report_max_per_session"))
	var sent: int = 0
	for raw in batch:
		if _sent_count >= limit:
			break
		var sig: String = _digits.sub(raw, "N", true).strip_edges().left(MAX_MESSAGE_LEN)
		if _sent.has(sig):
			continue
		_sent[sig] = true
		_sent_count += 1
		sent += 1
		analytics.track_error("error", sig)
	return sent
