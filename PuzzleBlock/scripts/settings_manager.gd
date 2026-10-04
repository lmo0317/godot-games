class_name SettingsManager
extends RefCounted

const SETTINGS_PATH: String = "user://game_settings.json"

static var sound_enabled: bool = true
static var screen_shake_enabled: bool = true
static var ghost_piece_enabled: bool = true
static var vibration_enabled: bool = true
static var block_skin: String = "classic"
# First-game hint: "" never decided (first-time players get it), "pending" show it, "done" seen
static var tutorial_state: String = ""
# -1 unknown, 0 no, 1 yes. Browsers without the Vibration API (Safari, Firefox for Android)
# make Godot log a message on every call, so support is checked once.
static var _vibration_supported: int = -1

static func init_settings() -> void:
	load_settings()
	SoundManager.is_muted = not sound_enabled

static func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.get_data()
			if data is Dictionary:
				sound_enabled = bool(data.get("sound_enabled", true))
				screen_shake_enabled = bool(data.get("screen_shake_enabled", true))
				ghost_piece_enabled = bool(data.get("ghost_piece_enabled", true))
				vibration_enabled = bool(data.get("vibration_enabled", true))
				var skin := str(data.get("block_skin", "classic"))
				block_skin = skin if BlockSkins.is_valid(skin) else "classic"
				tutorial_state = str(data.get("tutorial", ""))

static func save_settings() -> void:
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		var data = {
			"sound_enabled": sound_enabled,
			"screen_shake_enabled": screen_shake_enabled,
			"ghost_piece_enabled": ghost_piece_enabled,
			"vibration_enabled": vibration_enabled,
			"block_skin": block_skin,
			"tutorial": tutorial_state
		}
		file.store_string(JSON.stringify(data))

static func set_sound(enabled: bool) -> void:
	sound_enabled = enabled
	SoundManager.is_muted = not enabled
	save_settings()

static func set_shake(enabled: bool) -> void:
	screen_shake_enabled = enabled
	save_settings()

static func set_ghost(enabled: bool) -> void:
	ghost_piece_enabled = enabled
	save_settings()

static func set_vibration(enabled: bool) -> void:
	vibration_enabled = enabled
	save_settings()

static func set_tutorial(state: String) -> void:
	tutorial_state = state
	save_settings()

static func set_skin(skin: String) -> void:
	if not BlockSkins.is_valid(skin):
		return
	block_skin = skin
	BlockSkins.preload_skin(skin)
	save_settings()

static func vibrate(duration_ms: int) -> void:
	# Android/iOS/Web only; no-op elsewhere. Web ignores amplitude, so strength is expressed by duration.
	if not vibration_enabled:
		return
	if Toss.active():
		# navigator.vibrate does nothing on iPhone; Toss's haptics work on both
		Toss.haptic(duration_ms)
		return
	if _vibration_supported < 0:
		_vibration_supported = 1
		if OS.has_feature("web"):
			# Stay off unless the browser has navigator.vibrate (no eval: Apps in Toss forbids it)
			_vibration_supported = 0
			var nav = JavaScriptBridge.get_interface("navigator")
			if nav != null and nav.vibrate != null:
				_vibration_supported = 1
	if _vibration_supported == 1:
		Input.vibrate_handheld(duration_ms)
