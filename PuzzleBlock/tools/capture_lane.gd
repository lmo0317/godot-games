extends Node
# Lane battle capture — 영웅 위치, 보스 인트로, 버프 배너를 눈으로 확인하기 위한 스크린샷.
# Run (needs a real window):
#   Godot_console.exe --path . --resolution 720x1280 res://tools/capture_lane.tscn

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
	var b: LaneBattle = main.battle

	for path in [LaneStages.PROGRESS_PATH, LaneUnits.ARMY_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	main._start_battle()
	await _wait(1.0)
	main._start_lane_stage(1)
	# Boss intro overlay fades in over ~0.3s and auto-closes at 2.2s
	await _wait(1.2)
	await _shot("lane_03_boss_intro")
	# Wait for the overlay to auto-close
	await _wait(2.2)
	# Now hero should be clearly visible on top of the lane, no overlay
	await _shot("lane_01_hero")
	# Trigger the hero skill to see the compact buff banner
	b.activate_hero_skill()
	await _wait(0.4)
	await _shot("lane_02_buff_banner")
	# 쫄몹이 전진해 영웅 근처까지 올 때까지 더 기다렸다 비교 캡처
	await _wait(5.0)
	await _shot("lane_04_hero_vs_mobs")
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
