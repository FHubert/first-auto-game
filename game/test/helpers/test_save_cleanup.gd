class_name TestSaveCleanup
extends RefCounted
## Removes a test save file together with its .tmp and .bak companions.
## Not a test suite: do not extend GdUnitTestSuite.


static func remove(path: String) -> void:
	for p in [path, path + ".tmp", SaveSystem.backup_path_for(path)]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
