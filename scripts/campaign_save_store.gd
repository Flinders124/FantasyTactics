class_name CampaignSaveStore
extends RefCounted
## One active slot. Staged writes are validated before any existing file moves.
var path: String="user://campaign/active.json"
var last_message: String=""
var fail_stage: String="" # Isolated tests inject filesystem failures; never exposed in UI.

static func default_path() -> String:
	# Every existing --script res://tests harness gets a private slot automatically.
	for argument in OS.get_cmdline_args():
		if argument.begins_with("res://tests/"): return "user://test-runs/%d/active.json"%OS.get_process_id()
	return "user://campaign/active.json"

func read_file(file_path: String) -> CampaignSaveCodec.Decoded:
	var result := CampaignSaveCodec.Decoded.new()
	if not FileAccess.file_exists(file_path): result.error="No campaign save is present."; return result
	var file := FileAccess.open(file_path,FileAccess.READ)
	if file==null: result.error="Campaign file cannot be read. It has not been changed."; return result
	if file.get_length()>CampaignSaveCodec.MAX_BYTES: result.error="Campaign file is too large or damaged."; return result
	var text := file.get_as_text(); file.close()
	return CampaignSaveCodec.decode(text)

func inspect() -> Dictionary:
	var current := read_file(path)
	var backup := read_file(path+".bak") if current.state==null else CampaignSaveCodec.Decoded.new()
	var exists := FileAccess.file_exists(path) or FileAccess.file_exists(path+".bak")
	return {"current":current,"backup":backup,"exists":exists,"status":"valid" if current.state!=null else ("backup" if backup.state!=null else ("invalid" if exists else "empty"))}

func _rename(from: String,to: String) -> bool:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(from),ProjectSettings.globalize_path(to))==OK

func _remove(file_path: String) -> bool:
	return not FileAccess.file_exists(file_path) or DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))==OK

func write(state: CampaignState,phase: String,replace_invalid: bool=false,recovering: bool=false) -> bool:
	last_message="Saving campaign…"
	var text := CampaignSaveCodec.encode(state,phase)
	var candidate := CampaignSaveCodec.decode(text)
	if candidate.state==null:
		last_message="Save rejected: "+candidate.error; return false
	var previous := inspect()
	if previous.status in ["invalid","backup"] and not replace_invalid:
		last_message="Existing campaign cannot be overwritten. Recover its backup or explicitly replace it from New Campaign."
		return false
	if not path.begins_with("user://"):
		last_message="Campaign saves must use the game user-data folder."; return false
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))!=OK:
		last_message="Could not create the campaign folder. Previous progress is unchanged."; return false
	var temporary := path+".tmp"
	if fail_stage=="write": last_message="Campaign write failed. Previous progress is unchanged."; return false
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file==null: last_message="Could not write the campaign. Previous progress is unchanged."; return false
	file.store_string(text); file.flush()
	var write_error := file.get_error(); file.close()
	if write_error!=OK or FileAccess.get_file_as_string(temporary)!=text:
		last_message="Campaign verification failed. Previous progress is unchanged."; return false
	# Build a replacement backup while the main file remains untouched.
	if previous.current.state!=null and not recovering:
		if fail_stage=="backup" or DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(path+".bak.tmp"))!=OK or FileAccess.get_file_as_string(path+".bak.tmp")!=FileAccess.get_file_as_string(path):
			last_message="Could not back up the campaign. Previous progress is unchanged."; return false
		if not _remove(path+".bak.previous") or (FileAccess.file_exists(path+".bak") and not _rename(path+".bak",path+".bak.previous")):
			last_message="Backup replacement failed. The current campaign is unchanged."; return false
		if not _rename(path+".bak.tmp",path+".bak"):
			if FileAccess.file_exists(path+".bak.previous"): _rename(path+".bak.previous",path+".bak")
			last_message="Backup replacement failed. The current campaign is unchanged."; return false
	var displaced := path+".previous"
	if previous.current.state==null:
		displaced=path+".unreadable-%d"%Time.get_ticks_usec()
		# Explicit replacement/recovery preserves unreadable bytes for manual recovery.
	if FileAccess.file_exists(path):
		if not _remove(displaced) or not _rename(path,displaced):
			last_message="Campaign replacement failed. Previous progress is unchanged."; return false
	if fail_stage=="replace" or not _rename(temporary,path):
		if FileAccess.file_exists(displaced): _rename(displaced,path)
		last_message="Campaign replacement failed. Previous progress remains in the slot or its backup."; return false
	if FileAccess.get_file_as_string(path)!=text:
		_remove(path)
		if FileAccess.file_exists(displaced): _rename(displaced,path)
		last_message="Campaign verification failed. Previous progress was retained."; return false
	if previous.current.state!=null: _remove(displaced)
	_remove(path+".bak.previous")
	last_message="Campaign saved. Interrupted missions restart from their original deployment."
	return true

func recover_backup() -> CampaignSaveCodec.Decoded:
	var backup := read_file(path+".bak")
	if backup.state==null: last_message=backup.error; return backup
	if not write(backup.state,backup.phase,true,true): backup.state=null; backup.error=last_message; return backup
	last_message="Recovered backup progress. The damaged file was preserved."
	return backup

func discard() -> bool:
	# Only called after explicit confirmation; no recursive directory operations.
	for suffix in [".bak",".tmp",".bak.tmp",".bak.previous",".previous",""]:
		if not _remove(path+suffix): last_message="Could not remove the saved campaign. It has not been abandoned."; return false
	last_message="Saved campaign abandoned."
	return true


