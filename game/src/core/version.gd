class_name Version
extends RefCounted
## Build metadata. release.yml rewrites the two const lines below by regex;
## keep them EXACTLY in this format (one line each, double quotes):
##   const BUILD_INFO: String = "<text>"
##   const VERSION: String = "<x.y.z>"

const BUILD_INFO: String = "dev"
const VERSION: String = "0.1.0"


## True when BUILD_INFO carries no "+<code>" suffix (e.g. "dev").
static func is_dev_build() -> bool:
	return BUILD_INFO.find("+") == -1


## Build number from BUILD_INFO ("<name>+<code>"), or -1 for dev builds.
static func build_code() -> int:
	return parse_build_code(BUILD_INFO)


## Parses "<name>+<code>" and returns <code> as int; -1 when there is no "+",
## the part after the last "+" is empty, or it contains non-digit characters.
static func parse_build_code(info: String) -> int:
	var sep: int = info.rfind("+")
	if sep == -1:
		return -1
	var code_part: String = info.substr(sep + 1)
	if code_part.is_empty() or code_part.lstrip("0123456789") != "":
		return -1
	return code_part.to_int()
