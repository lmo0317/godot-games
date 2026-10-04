extends Node
# Captures the clear feedback (flying blocks, rays, praise, "Combo N", points, the rolling
# score at the top) frame by frame, including a perfect clear.
#   Godot_console.exe --path . --resolution 720x1280 res://tools/capture_combo.tscn
# Output folder: CAPTURE_DIR environment variable, default user://captures.
# Local save files are backed up first and restored at the end (the clears set new records).

const MainScene: PackedScene = preload("res://scenes/main.tscn")
const CASES: Array = [
	# [name, combo before the clear, layout]
	["small", 0, ["........", "........", "........", "........", "........", "rrbbyygg", "........", "........"]],
	["combo", 7, ["...o....", "...o....", "...o....", "ppkkccbb", "rrbbyygg", "...o....", "...o....", "...o...."]],
	["perfect", 2, ["........", "........", "........", "........", "ggbbyyrr", "........", "........", "........"]],
	["fever", 11, ["..y.o...", "..y.o...", "ggbbyyrr", "ppkkccbb", "rrbbyygg", "..y.o...", "..y.o...", "..y.o...."]],
]
const TIMES: Array = [0.1, 0.3, 0.7]
const USER_FILES: Array[String] = [
	"user://block_blast_save.cfg",
	"user://game_settings.json",
	"user://player_profile.json",
	"user://adventure_progress.json",
	"user://achievements.json",
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
	SoundManager.is_muted = true
	main.profile_setup_modal.visible = false
	main._on_start_play_pressed()
	await _wait(1.5)
	for c in CASES:
		main.board.load_layout(c[2])
		main.combo_count = c[1]
		main.board.clear_combo = c[1]
		await _wait(0.2)
		var info: Dictionary = main.board.check_and_clear_lines()
		main.combo_count += 1
		main._process_line_clears(info["lines"], info["cells"], info["center"])
		if info["perfect"]:
			main._process_perfect_clear()
		var t := 0.0
		for at in TIMES:
			await _wait(at - t)
			t = at
			await _save("combo_%s_%03d" % [c[0], int(at * 1000)])
		await _wait(1.6)
	for p in USER_FILES:
		if backups.has(p):
			var f := FileAccess.open(p, FileAccess.WRITE)
			f.store_buffer(backups[p])
			f.close()
		elif FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	get_tree().quit()

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("captured ", name)
