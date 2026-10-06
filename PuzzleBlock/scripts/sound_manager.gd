extends Node

var is_muted: bool = false
var sounds: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
const POOL_SIZE: int = 12
const COMBO_SOUNDS: int = 12
# Headroom for sounds that start together on a clear (clear + combo + fever or perfect)
const CLEAR_DB: float = -4.0
const COMBO_DB: float = -4.0
const EVENT_DB: float = -3.0

func _ready() -> void:
	# Create pool of AudioStreamPlayers
	for i in range(POOL_SIZE):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		players.append(p)
	
	# Load sound assets
	_load_sound("pickup", "res://assets/sfx/pickup.wav")
	_load_sound("place", "res://assets/sfx/place.wav")
	_load_sound("invalid", "res://assets/sfx/invalid.wav")
	_load_sound("gameover", "res://assets/sfx/gameover.wav")
	_load_sound("record", "res://assets/sfx/record.wav")
	_load_sound("click", "res://assets/sfx/click.wav")
	_load_sound("deal", "res://assets/sfx/deal.wav")
	
	# Clear, combo, fever and perfect sounds come from tools/generate_sfx.py: every pitch is its own
	# file and every file peaks at -6 dBFS, so they can overlap without clipping
	for i in range(1, 5):
		_load_sound("clear_%d" % i, "res://assets/sfx/clear_%d.wav" % i)
	for i in range(1, COMBO_SOUNDS + 1):
		_load_sound("combo_%d" % i, "res://assets/sfx/combo_%d.wav" % i)
	_load_sound("fever", "res://assets/sfx/fever.wav")
	_load_sound("perfect", "res://assets/sfx/perfect.wav")
	for k in ["b_hit", "b_arrow", "b_magic", "b_death", "b_cannon", "b_horn", "b_roar", "b_summon", "b_castle"]:
		_load_sound(k, "res://assets/sfx/%s.wav" % k)

func _load_sound(key: String, path: String) -> void:
	if ResourceLoader.exists(path):
		var stream = load(path)
		sounds[key] = stream

func play(key: String, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	if is_muted:
		return
	if not sounds.has(key):
		return
	
	var player = _get_available_player()
	if player:
		player.stream = sounds[key]
		player.pitch_scale = pitch_scale
		player.volume_db = volume_db
		player.play()

# Battle sounds never cut off a puzzle sound: they play only when a player is free, and keep
# BATTLE_SPARE players free for the puzzle
const BATTLE_SPARE: int = 4
func play_battle(key: String, volume_db: float = -8.0) -> void:
	if is_muted or not sounds.has(key):
		return
	var free: Array = players.filter(func(p): return not p.playing)
	if free.size() <= BATTLE_SPARE:
		return
	var p: AudioStreamPlayer = free[0]
	p.stream = sounds[key]
	p.pitch_scale = 1.0
	p.volume_db = volume_db
	p.play()

func _get_available_player() -> AudioStreamPlayer:
	for p in players:
		if not p.playing:
			return p
	return players[0]

func play_pickup() -> void:
	play("pickup", 1.0, -2.0)

func play_place() -> void:
	play("place", 1.0, 0.0)

func play_invalid() -> void:
	play("invalid", 1.0, -2.0)

func play_lines_clear(lines: int, combo_level: int = 0) -> void:
	play("clear_%d" % clampi(lines, 1, 4), 1.0, CLEAR_DB)
	if combo_level > 0:
		# One note higher per combo step, up the pentatonic scale
		play("combo_%d" % clampi(combo_level, 1, COMBO_SOUNDS), 1.0, COMBO_DB)

func play_fever() -> void:
	play("fever", 1.0, EVENT_DB)

func play_revive_bomb() -> void:
	play("clear_4", 0.8, CLEAR_DB)
	play("record", 1.0, -2.0)

func play_perfect_clear() -> void:
	play("perfect", 1.0, EVENT_DB)

func play_gameover() -> void:
	play("gameover", 1.0, 2.0)

func play_record() -> void:
	play("record", 1.0, 3.0)

func play_click() -> void:
	play("click", 1.0, -4.0)

func play_deal() -> void:
	play("deal", 1.0, -2.0)

func toggle_mute() -> bool:
	is_muted = not is_muted
	return is_muted
