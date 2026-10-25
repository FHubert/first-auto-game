class_name ErrorLogger
extends Logger
## Podpina ErrorReporter pod Logger silnika (T-296). Wolane z dowolnego watku:
## tylko `ingest`, zadnego print/push_error (rekurencja).

var reporter: ErrorReporter = ErrorReporter.new()


func _log_error(
	_function: String,
	file: String,
	line: int,
	code: String,
	rationale: String,
	_editor_notify: bool,
	error_type: int,
	_script_backtraces: Array[ScriptBacktrace]
) -> void:
	reporter.ingest(file, line, rationale, error_type, code)
