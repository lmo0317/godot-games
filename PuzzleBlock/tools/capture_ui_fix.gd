extends Node
# 2026-10-10 UI 겹침 수정 검증용 캡처 — 덱(병사) 화면과 전투 화면.
# 실행: Godot_console.exe --path . --resolution 720x1280 res://tools/capture_ui_fix.tscn

const MainScene: PackedScene = preload("res://scenes/main.tscn")
const USER_FILES: Array[String] = [
	"user://game_settings.json",
	"user://block_blast_save.cfg",
	"user://achievements.json",
	"user://lane_progress.json",
	"user://lane_army.json",
]

var backups: Dictionary = {}
var out_dir: String = ""
var main: MainGame

func _ready() -> void:
	Analytics.enabled = false
	out_dir = OS.get_environment("CAPTURE_DIR")
	if out_dir.is_empty():
		out_dir = ProjectSettings.globalize_path("user://captures")
	DirAccess.make_dir_recursive_absolute(out_dir)
	for p in USER_FILES:
		if FileAccess.file_exists(p):
			backups[p] = FileAccess.get_file_as_bytes(p)
	_run.call_deferred()

func _run() -> void:
	main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	main.profile_setup_modal.visible = false
	SoundManager.is_muted = true
	SettingsManager.tutorial_state = "done"

	for path in [LaneStages.PROGRESS_PATH, LaneUnits.ARMY_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	# 1) 덱(병사) 화면
	main.lane_deck.open()
	await _wait(0.6)
	await _shot("ui_fix_deck")

	main.lane_deck.close()
	await _wait(0.3)

	# 2) 전투 화면 (스킬 버튼 보기)
	main._start_battle()
	await _wait(1.0)
	main._start_lane_stage(1)
	await _wait(3.6)  # 보스 인트로 지나감
	await _shot("ui_fix_battle")

	_finish()

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("captured ", name)

func _finish() -> void:
	for p in USER_FILES:
		if backups.has(p):
			var f := FileAccess.open(p, FileAccess.WRITE)
			f.store_buffer(backups[p])
			f.close()
		elif FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	get_tree().quit()
