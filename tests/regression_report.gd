class_name RegressionReport
extends RefCounted
## Test-only output. Never writes a campaign slot or requires checkout directories.
static func root_path() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report-root="): return argument.trim_prefix("--report-root=")
	return "user://regression-reports/%d"%OS.get_process_id()
static func write_json(relative: String,data: Variant) -> bool:
	if relative.is_absolute_path() or ".." in relative.split("/"):
		push_error("Invalid regression report path: "+relative);return false
	var path:=ProjectSettings.globalize_path(root_path().path_join(relative))
	var error:=DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error!=OK:push_error("Cannot create test report directory: "+error_string(error));return false
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:push_error("Cannot write test report: "+error_string(FileAccess.get_open_error()));return false
	file.store_string(JSON.stringify(data,"\t"));file.flush();error=file.get_error();file.close()
	if error!=OK:push_error("Cannot finish test report: "+error_string(error))
	return error==OK
