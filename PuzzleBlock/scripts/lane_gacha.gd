class_name LaneGacha
extends Control
# 블록 기사단 soldier gacha as a card pack (docs/GACHA_RESEARCH.md, docs/LANE_UNITS.md "뽑기"),
# in the pixel-art UI (LaneUI):
#   1 the pack floats on slow light rays; the rates on parchment, 1 pull (100) or 10 pulls (900, one
#     레어 or better promised)
#   2 after paying, the pack shakes with an aura in the colour of the best card inside (white / blue
#     레어 / purple 유니크 / gold 레전더리; sometimes it turns up a step, the moment players remember).
#     Swipe across it (or tap) to rip the top off (포켓몬 카드 게임 Pocket)
#   3 the cards fly out face down; each back glows in its rarity's colour (하스스톤), so the player picks
#     the order. Tapping one flips it in place; 유니크 and 레전더리 also get the big full-screen show.
#     [모두 뒤집기] turns the rest
#   4 the flipped cards stay as the result: NEW! or the copies toward the next merge, how many are
#     new, which soldiers can merge now ([합성하러 가기]), and [확인] / [다시 뽑기]
# Pieces: assets/art/lane/card_back, card_pack(_top/_body), summon_* (Codex sheets, docs/ART_GUIDE.md),
# sounds g_* (tools/generate_sfx.py).

signal closed
signal deck_requested
signal deck_requested_kind(kind: String)

const PACK_AT: Vector2 = Vector2(360, 430)
const PACK_K: float = 4.0
# Light colour by the base tier of a card (노멀, 레어, 유니크, 레전더리)
const LIGHT: Array[Color] = [Color(0.92, 0.96, 1.0), Color(0.4, 0.68, 1.0), Color(0.82, 0.5, 1.0), Color(1.0, 0.68, 0.22)]
const SHOW_CARD: Vector2 = Vector2(300, 360)
const CARD_10: Vector2 = Vector2(114, 150)   # card back (38x50) x3
const CARD_1: Vector2 = Vector2(152, 200)    # card back x4
const SUM_CARD: Vector2 = Vector2(110, 150)

var rng := RandomNumberGenerator.new()
var gem_bar: Panel
var pity_bar: Panel
var pity_u_label: Label
var pity_l_label: Label
var note: Label
var pull1: Button
var pull10: Button
var back: Button
var rates: Panel
var _busy: bool = false
var _clock: float = 0.0

# 1 the pack
var _stage: Node2D
var _rays: Sprite2D
var _aura: Sprite2D
var _pack: Control
var _pack_top: TextureRect
var _pack_body: TextureRect
var _pack_hint: Label
var _press_x: float = -1.0
var _pack_open: bool = false

# 3 the cards
var _table: Control
var _cards: Array = []            # {"node", "res", "open", "glow", "size"}
var _results: Array = []
var _table_line: Label
var _table_merge: Label
var _flip_all: Button
var _sum_ok: Button
var _sum_deck: Button
var _again: Button
# Summary bar at the top of the result screen (3 counters) + mini-thumbnail strip for mergeables
var _sum_bar: Control
var _sum_new: Label
var _sum_merge_count: Label
var _sum_shard: Label
var _sum_strip: HBoxContainer

# The big show for a rare card
var _show: Control
var _show_rays: Sprite2D
var _show_burst: Sprite2D
var _show_box: Control
var _flash: ColorRect
var _advance: bool = false

func _ready() -> void:
	rng.randomize()
	visible = false
	z_index = 160
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	LaneUI.backdrop(self)

	# Row 1: small [본부로] on the left, "병사 뽑기" ribbon centred, gems on the right
	var top_back := Button.new()
	top_back.text = "◀"
	LaneUI.button(top_back, "grey", 20)
	top_back.position = Vector2(18, 18)
	top_back.size = Vector2(74, 54)
	top_back.pressed.connect(close)
	add_child(top_back)
	var title := LaneUI.ribbon("병사 뽑기", 360, 30)
	title.position = Vector2(180, 22)
	add_child(title)
	gem_bar = LaneUI.gem_bar(160)
	gem_bar.position = Vector2(542, 18)
	add_child(gem_bar)
	_build_pity_bar()

	_stage = Node2D.new()
	add_child(_stage)
	_rays = _sprite("summon_rays", PACK_AT, 5.0)
	_rays.modulate = Color(LIGHT[0], 0.16)
	_aura = _sprite("summon_burst", PACK_AT, 6.0)
	_aura.modulate = Color(1, 1, 1, 0)
	_build_pack()

	# Rates, always visible, on parchment
	rates = Panel.new()
	LaneUI.dress(rates, "panel_paper")
	rates.position = Vector2(30, 698)
	rates.size = Vector2(660, 140)
	add_child(rates)
	var y := 10
	for t in [3, 2, 1, 0]:
		var kinds: Array = LaneUnits.ORDER.filter(func(k): return LaneUnits.UNITS[k]["tier"] == t)
		var col: Color = LaneUnits.tier_color(t).darkened(0.45) if t > 0 else LaneUI.INK
		var pct: String = ("%.1f%%" % (LaneUnits.BASE_RATE[t] * 100.0)).replace(".0%", "%")
		var line := LaneUI.label("%s %s  ·  %s" % [LaneUnits.TIER_NAME[t], pct, ", ".join(kinds.map(func(k): return LaneUnits.UNITS[k]["name"]))], 16, col, HORIZONTAL_ALIGNMENT_LEFT, false)
		line.position = Vector2(20, y)
		line.size = Vector2(620, 24)
		rates.add_child(line)
		y += 26
	var promise := LaneUI.label("같은 병사는 복제가 되어 합성(성급 올리기)에 써요", 15, Color(0.36, 0.25, 0.15), HORIZONTAL_ALIGNMENT_LEFT, false)
	promise.position = Vector2(20, y)
	promise.size = Vector2(590, 22)
	rates.add_child(promise)

	pull1 = Button.new()
	LaneUI.button(pull1, "green", 24)
	pull1.position = Vector2(20, 852)
	pull1.size = Vector2(334, 100)
	pull1.pressed.connect(func(): pull(1))
	add_child(pull1)
	pull10 = Button.new()
	LaneUI.button(pull10, "red", 24)
	pull10.position = Vector2(366, 852)
	pull10.size = Vector2(334, 100)
	pull10.pressed.connect(func(): pull(10))
	add_child(pull10)
	for b in [pull1, pull10]:
		var gi := LaneUI.icon("icon_gem", Vector2(26, 30))
		gi.position = Vector2(24, 35)
		b.add_child(gi)
	note = LaneUI.label("", 21, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	note.position = Vector2(0, 964)
	note.size = Vector2(720, 34)
	add_child(note)
	# Back is up in row 1 now; keep a hidden handle so _refresh() still works
	back = top_back

	_build_table()
	_build_show()
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

# Pity bar: one slim strip with both pities side by side (유니크 보장 / 레전더리 보장)
func _build_pity_bar() -> void:
	pity_bar = Panel.new()
	LaneUI.dress(pity_bar, "panel_paper")
	pity_bar.position = Vector2(20, 92)
	pity_bar.size = Vector2(680, 50)
	add_child(pity_bar)
	pity_u_label = LaneUI.label("", 18, Color(0.4, 0.2, 0.55), HORIZONTAL_ALIGNMENT_CENTER, false)
	pity_u_label.position = Vector2(10, 12)
	pity_u_label.size = Vector2(330, 26)
	pity_bar.add_child(pity_u_label)
	pity_l_label = LaneUI.label("", 18, Color(0.65, 0.42, 0.08), HORIZONTAL_ALIGNMENT_CENTER, false)
	pity_l_label.position = Vector2(340, 12)
	pity_l_label.size = Vector2(330, 26)
	pity_bar.add_child(pity_l_label)

func _refresh_pity() -> void:
	var army := LaneUnits.load_army()
	var since_u: int = int(army.get("pulls_since_unique", 0))
	var since_l: int = int(army.get("pulls_since_legendary", 0))
	var left_u: int = maxi(0, LaneUnits.PITY_UNIQUE - since_u)
	var left_l: int = maxi(0, LaneUnits.PITY_LEGENDARY - since_l)
	if left_u == 0:
		pity_u_label.text = "유니크 10연 보장!"
	else:
		pity_u_label.text = "유니크 보장까지 %d뽑" % left_u
	if left_l == 0:
		pity_l_label.text = "레전더리 10연 보장!"
	else:
		pity_l_label.text = "레전더리 보장까지 %d뽑" % left_l

func _sprite(name: String, at: Vector2, k: float, parent: Node = null) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load("res://assets/art/lane/%s.png" % name)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = at
	s.scale = Vector2(k, k)
	(parent if parent else _stage).add_child(s)
	return s

func _tex_rect(name: String, k: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load("res://assets/art/lane/%s.png" % name)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.size = Vector2(r.texture.get_width(), r.texture.get_height()) * k
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

# The pack: its body and its top strip (cut along the tear line by the importer), one control that
# takes the swipe
func _build_pack() -> void:
	_pack = Control.new()
	_pack.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_pack)
	_pack_body = _tex_rect("card_pack_body", PACK_K)
	_pack_top = _tex_rect("card_pack_top", PACK_K)
	_pack.size = _pack_body.size
	_pack.position = PACK_AT - _pack.size * 0.5
	_pack.pivot_offset = _pack.size * 0.5
	_pack.add_child(_pack_body)
	_pack.add_child(_pack_top)
	_pack_top.pivot_offset = _pack_top.size * 0.5
	_pack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pack_hint = LaneUI.label("", 22, LaneUI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_pack_hint.position = Vector2(0, PACK_AT.y + _pack.size.y * 0.5 + 18)
	_pack_hint.size = Vector2(720, 32)
	add_child(_pack_hint)

func open() -> void:
	SoundManager.play_click()
	_show.visible = false
	_table.visible = false
	_busy = false
	_reset_pack()
	note.text = "보석은 스테이지를 깨면 받아요"
	_refresh()
	visible = true

func close() -> void:
	SoundManager.play_click()
	_show.visible = false
	_table.visible = false
	visible = false
	closed.emit()

func _refresh() -> void:
	LaneUI.set_gem_bar(gem_bar)
	var gems: int = LaneUnits.load_army()["gems"]
	pull1.text = "1회 뽑기\n%d" % LaneUnits.PULL_COST
	pull10.text = "10회 뽑기 %d\n레어 이상 1명 보장" % LaneUnits.PULL10_COST
	pull1.disabled = gems < LaneUnits.PULL_COST or _busy
	pull10.disabled = gems < LaneUnits.PULL10_COST or _busy
	back.disabled = _busy
	if _again:
		_again.disabled = gems < (LaneUnits.PULL10_COST if _results.size() >= 10 else LaneUnits.PULL_COST)
	_refresh_pity()

func _reset_pack() -> void:
	_pack_open = false
	_pack.visible = true
	_pack.modulate = Color.WHITE
	_pack.scale = Vector2.ONE
	_pack.rotation = 0.0
	_pack.position = PACK_AT - _pack.size * 0.5
	_pack_top.position = Vector2.ZERO
	_pack_top.rotation = 0.0
	_pack_top.modulate.a = 1.0
	_pack_hint.text = ""
	_aura.modulate.a = 0.0
	_rays.modulate = Color(LIGHT[0], 0.16)
	_rays.scale = Vector2(5.0, 5.0)

func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	_rays.rotation += delta * 0.12
	_aura.rotation -= delta * 0.4
	if _show.visible:
		_show_rays.rotation += delta * 0.35
	# The sealed pack floats; once paid for, it trembles harder the better the card inside
	if _pack.visible and not _pack_open:
		var base: Vector2 = PACK_AT - _pack.size * 0.5
		if _busy:
			var k: float = 1.5 + 2.5 * _best_rarity()
			_pack.position = base + Vector2(rng.randf_range(-k, k), rng.randf_range(-k, k) * 0.5)
			_aura.scale = Vector2.ONE * (6.0 + 0.4 * sin(_clock * 6.0))
		else:
			_pack.position = base + Vector2(0, sin(_clock * 1.6) * 6.0)
	for c in _cards:
		if not c["open"] and c["glow"] != null:
			var g: Sprite2D = c["glow"]
			g.rotation += delta * 0.8
			g.modulate.a = 0.55 + 0.35 * sin(_clock * 5.0 + c["node"].position.x * 0.02)

func _best_rarity() -> int:
	var best := 0
	for r in _results:
		best = maxi(best, int(LaneUnits.UNITS[r["kind"]]["tier"]))
	return best

# Pays and puts the sealed pack in play; returns the results at once (empty if gems ran short)
func pull(count: int) -> Array:
	if _busy:
		return []
	var results: Array = LaneUnits.pull(count, rng)
	if results.is_empty():
		note.text = "보석이 모자라요 · 스테이지를 깨서 모아요"
		SoundManager.play_invalid()
		return []
	SoundManager.play_click()
	_results = results
	_busy = true
	_table.visible = false
	_reset_pack()
	note.text = ""
	_refresh()
	var ladder_time: float = _charge_pack()
	# Auto flow: once the lucky-roll ladder settles, the pack bursts and the cards deal + auto-flip
	get_tree().create_timer(ladder_time + 0.15).timeout.connect(func():
		if _busy and not _pack_open and visible:
			open_pack(1.0))
	return results

# Lucky-roll "ladder": the aura climbs white → blue → purple → gold and stops at the best tier
# inside, with a 50% fakeout where it hesitates one step below first (docs/GACHA_RESEARCH.md 럭키 롤)
func _charge_pack() -> float:
	var best := _best_rarity()
	SoundManager.play_battle("g_charge", -6.0)
	_pack_hint.text = ""
	_aura.modulate = Color(LIGHT[0], 0.0)
	_rays.modulate = Color(LIGHT[0], 0.4)
	var fakeout: bool = best >= 1 and rng.randf() < 0.5
	# Climb one step every ~0.35 s, pausing a touch at the fakeout tier
	var step_dur: float = 0.35
	var at: float = 0.0
	for step in range(best + 1):
		var col: Color = LIGHT[step]
		var dur: float = step_dur
		if fakeout and step == best - 1:
			dur = step_dur + 0.55 # hesitate below
		var t := create_tween().set_parallel(true)
		t.tween_interval(at)
		t.chain().tween_callback(func():
			if _busy and not _pack_open:
				SoundManager.play_battle("g_promote", -5.0)
				_flash_screen(0.35 + 0.15 * step, 0.22, col))
		t.chain().tween_property(_aura, "modulate", Color(col, 0.5 + 0.15 * step), 0.18)
		t.tween_property(_rays, "modulate", Color(col, 0.3 + 0.08 * step), 0.18)
		at += dur
	if best >= 1:
		# Final pound at the best tier
		get_tree().create_timer(at).timeout.connect(func():
			if not _busy or _pack_open:
				return
			SoundManager.play_battle("g_shift", -3.0)
			_flash_screen(0.75, 0.35, LIGHT[best])
			_shake(_stage, 6.0 + 4.0 * best, 0.3)
			var t2 := create_tween().set_parallel(true)
			t2.tween_property(_aura, "modulate", Color(LIGHT[best], 0.95), 0.12)
			t2.tween_property(_rays, "modulate", Color(LIGHT[best], 0.5), 0.12))
	return at + (0.4 if best >= 1 else 0.0)

# Rips the top off and deals the cards face down (called automatically after lucky roll)
func open_pack(dir: float = 1.0) -> void:
	if not _busy or _pack_open:
		return
	_pack_open = true
	_press_x = -1.0
	_pack_hint.text = ""
	SoundManager.play_battle("g_tear", -2.0)
	SettingsManager.vibrate(40)
	var tt := _pack_top.create_tween().set_parallel(true)
	tt.tween_property(_pack_top, "position", Vector2(dir * 260.0, -140.0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tt.tween_property(_pack_top, "rotation", dir * 1.4, 0.45)
	tt.tween_property(_pack_top, "modulate:a", 0.0, 0.45).set_delay(0.15)
	_flash_screen(0.7, 0.35, _aura.modulate)
	_shake(_stage, 8.0 + 4.0 * _best_rarity(), 0.25)
	var pt := _pack.create_tween()
	pt.tween_interval(0.25)
	pt.tween_property(_pack, "position:y", _pack.position.y + 420.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	pt.parallel().tween_property(_pack, "modulate:a", 0.0, 0.35)
	pt.tween_callback(func(): _pack.visible = false)
	var at := create_tween().set_parallel(true)
	at.tween_property(_aura, "modulate:a", 0.0, 0.4)
	at.tween_property(_rays, "modulate:a", 0.16, 0.4)
	get_tree().create_timer(0.3).timeout.connect(_deal_cards)

# ---------------------------------------------------------------------------
# The table: cards face down, tap to flip, the result stays

func _build_table() -> void:
	_table = Control.new()
	_table.visible = false
	_table.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_table.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_table)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.06, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_table.add_child(shade)
	# The gem count stays visible over the shade
	var gems := LaneUI.gem_bar(680)
	gems.name = "Gems"
	gems.position = Vector2(20, 18)
	_table.add_child(gems)
	var ttl := LaneUI.ribbon("뽑기 결과", 400, 32)
	ttl.position = Vector2(160, 92)
	_table.add_child(ttl)
	_build_sum_bar()
	_table_line = LaneUI.label("", 24, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_table_line.position = Vector2(0, 740)
	_table_line.size = Vector2(720, 34)
	_table.add_child(_table_line)
	_table_merge = LaneUI.label("", 21, LaneUI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_table_merge.position = Vector2(40, 776)
	_table_merge.size = Vector2(640, 60)
	_table_merge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_table.add_child(_table_merge)
	_flip_all = Button.new()
	_flip_all.text = "모두 뒤집기"
	LaneUI.button(_flip_all, "blue", 24)
	_flip_all.position = Vector2(190, 860)
	_flip_all.size = Vector2(340, 84)
	_flip_all.pressed.connect(flip_all)
	_table.add_child(_flip_all)
	# Result buttons: [다시 10회] [1회 뽑기] [본부로]
	_again = Button.new()
	LaneUI.button(_again, "red", 20)
	_again.size = Vector2(216, 84)
	_again.pressed.connect(func():
		SoundManager.play_click()
		_finish_table()
		pull(10))
	_table.add_child(_again)
	_sum_ok = Button.new()
	LaneUI.button(_sum_ok, "green", 20)
	_sum_ok.size = Vector2(216, 84)
	_sum_ok.pressed.connect(func():
		SoundManager.play_click()
		_finish_table()
		pull(1))
	_table.add_child(_sum_ok)
	_sum_deck = Button.new()
	_sum_deck.text = "본부로"
	LaneUI.button(_sum_deck, "blue", 22)
	_sum_deck.size = Vector2(216, 84)
	_sum_deck.pressed.connect(func():
		SoundManager.play_click()
		_finish_table()
		close())
	_table.add_child(_sum_deck)

func _build_sum_bar() -> void:
	_sum_bar = Control.new()
	_sum_bar.position = Vector2(20, 164)
	_sum_bar.size = Vector2(680, 148)
	_sum_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	_sum_bar.visible = false
	_table.add_child(_sum_bar)
	var bar := Panel.new()
	LaneUI.dress(bar, "panel_wood")
	bar.size = Vector2(680, 76)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sum_bar.add_child(bar)
	# Three cells: 🆕 new / ⬆ mergeable / 💎 shards
	var cell_w: float = 680.0 / 3.0
	_sum_new = LaneUI.label("", 20, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_sum_new.position = Vector2(0, 20)
	_sum_new.size = Vector2(cell_w, 40)
	bar.add_child(_sum_new)
	_sum_merge_count = LaneUI.label("", 20, LaneUI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_sum_merge_count.position = Vector2(cell_w, 20)
	_sum_merge_count.size = Vector2(cell_w, 40)
	bar.add_child(_sum_merge_count)
	_sum_shard = LaneUI.label("", 20, Color(0.7, 0.95, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_sum_shard.position = Vector2(cell_w * 2, 20)
	_sum_shard.size = Vector2(cell_w, 40)
	bar.add_child(_sum_shard)
	# Mini-thumbnail horizontal strip under the bar: 4 fit, drag/scroll for more
	var strip_wrap := ScrollContainer.new()
	strip_wrap.position = Vector2(0, 82)
	strip_wrap.size = Vector2(680, 66)
	strip_wrap.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	strip_wrap.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	strip_wrap.mouse_filter = Control.MOUSE_FILTER_PASS
	_sum_bar.add_child(strip_wrap)
	_sum_strip = HBoxContainer.new()
	_sum_strip.add_theme_constant_override("separation", 8)
	strip_wrap.add_child(_sum_strip)

func _fill_sum_strip(merge_kinds: Array) -> void:
	for c in _sum_strip.get_children():
		c.queue_free()
	for k in merge_kinds:
		var u: Dictionary = LaneUnits.UNITS[k]
		var army := LaneUnits.load_army()
		var tier: int = int(army["owned"][k]["tier"]) if army["owned"].has(k) else int(u["tier"])
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(60, 60)
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		var card := LaneTierCard.new(tier, Vector2(60, 60))
		btn.add_child(card)
		var tex: Texture2D = load("res://assets/art/lane/%s.png" % k)
		var art := TextureRect.new()
		art.texture = tex
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.size = Vector2(50, 50)
		art.position = Vector2(5, 5)
		card.add_child(art)
		btn.pressed.connect(func():
			SoundManager.play_click()
			_finish_table()
			visible = false
			deck_requested_kind.emit(k))
		_sum_strip.add_child(btn)

func _finish_table() -> void:
	_table.visible = false
	_busy = false
	_reset_pack()
	_refresh()

func _deal_cards() -> void:
	for c in _cards:
		c["node"].queue_free()
	_cards.clear()
	LaneUI.set_gem_bar(_table.get_node("Gems"))
	_table.visible = true
	_table_line.text = "카드를 눌러 뒤집어요"
	_table_merge.text = ""
	_flip_all.visible = true
	_sum_ok.visible = false
	_again.visible = false
	_sum_deck.visible = false
	if _sum_bar != null:
		_sum_bar.visible = false
	# Put the best-rarity card at the last position (so the manual-flip climax is biggest).
	# For a 1-pull nothing changes. The _results array is reordered too so the big show runs last
	var n: int = _results.size()
	if n > 1:
		var best_i: int = 0
		for i in range(1, n):
			if int(LaneUnits.UNITS[_results[i]["kind"]]["tier"]) > int(LaneUnits.UNITS[_results[best_i]["kind"]]["tier"]):
				best_i = i
		if best_i != n - 1:
			var tmp = _results[n - 1]
			_results[n - 1] = _results[best_i]
			_results[best_i] = tmp
	var sz: Vector2 = CARD_10 if n > 1 else CARD_1
	for i in range(n):
		var at: Vector2
		if n == 1:
			at = Vector2(360, 470) - sz * 0.5
		else:
			at = Vector2((720.0 - (sz.x * 5 + 12 * 4)) * 0.5 + (i % 5) * (sz.x + 12), 300 + (i / 5) * (sz.y + 26))
		var card := _card_back(_results[i], sz)
		card.position = PACK_AT - sz * 0.5
		card.scale = Vector2(0.3, 0.3)
		card.modulate.a = 0.0
		_table.add_child(card)
		var tw := card.create_tween()
		tw.tween_interval(0.06 * i)
		tw.tween_callback(func(): SoundManager.play_deal())
		tw.set_parallel(true)
		tw.tween_property(card, "position", at, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", Vector2.ONE, 0.3)
		tw.tween_property(card, "modulate:a", 1.0, 0.15)
	# Auto flow: always auto-flip after the deal animation. 유니크/레전더리는 flip() 안에서 큰 등장을 띄움
	get_tree().create_timer(0.3 + 0.06 * n).timeout.connect(flip_all)

# A face-down card that glows in its rarity's colour; tap to flip
func _card_back(res: Dictionary, sz: Vector2) -> Control:
	var rarity: int = int(LaneUnits.UNITS[res["kind"]]["tier"])
	var holder := Control.new()
	holder.size = sz
	holder.pivot_offset = sz * 0.5
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	var glow: Sprite2D = null
	if rarity >= 1:
		glow = Sprite2D.new()
		glow.texture = load("res://assets/art/lane/summon_burst.png")
		glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		glow.position = sz * 0.5
		glow.scale = Vector2.ONE * (sz.x / 30.0) * (1.0 + 0.15 * rarity)
		glow.modulate = Color(LIGHT[rarity], 0.8)
		holder.add_child(glow)
	var face := _tex_rect("card_back", 1.0)
	face.size = sz
	face.name = "Back"
	holder.add_child(face)
	var entry := {"node": holder, "res": res, "open": false, "glow": glow, "size": sz}
	_cards.append(entry)
	holder.gui_input.connect(func(ev: InputEvent):
		if (ev is InputEventMouseButton or ev is InputEventScreenTouch) and ev.pressed:
			flip(entry))
	# Rarer backs tremble now and then (유니크+)
	if rarity >= 2:
		var tw := holder.create_tween().set_loops()
		entry["wobble"] = tw
		tw.tween_interval(0.8 + rng.randf() * 0.6)
		tw.tween_property(holder, "rotation", 0.06, 0.05)
		tw.tween_property(holder, "rotation", -0.06, 0.08)
		tw.tween_property(holder, "rotation", 0.0, 0.05)
	return holder

# Turns one card over: in place for 노멀 and 레어, with the big show for 유니크 and 레전더리
func flip(entry: Dictionary, quiet: bool = false) -> void:
	if entry["open"]:
		return
	entry["open"] = true
	if entry.has("wobble"):
		entry["wobble"].kill()
	var holder: Control = entry["node"]
	var res: Dictionary = entry["res"]
	var rarity: int = int(LaneUnits.UNITS[res["kind"]]["tier"])
	var sz: Vector2 = entry["size"]
	SoundManager.play_battle("g_flip", -4.0)
	var tw := holder.create_tween()
	tw.tween_property(holder, "scale", Vector2(0.0, 1.06), 0.1)
	tw.tween_callback(func():
		holder.rotation = 0.0
		for c in holder.get_children():
			c.queue_free()
		entry["glow"] = null
		var front := _card(res, sz)
		holder.add_child(front)
		if not quiet:
			SoundManager.play_battle("g_reveal_%d" % mini(rarity, 1), -8.0 if rarity == 0 else -5.0)
			if res["new"] and rarity < 2:
				SoundManager.play_battle("g_new", -8.0)
			if int(res.get("shard", 0)) > 0:
				SoundManager.play_battle("g_shard", -5.0)
		if rarity >= 1:
			front.burst())
	tw.tween_property(holder, "scale", Vector2(1.1, 1.1), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(holder, "scale", Vector2.ONE, 0.08)
	if rarity >= 2 and not quiet:
		tw.tween_callback(func(): _big_show(res))
	tw.tween_callback(_check_done)

func flip_all() -> void:
	SoundManager.play_click()
	var i := 0
	for c in _cards:
		if c["open"]:
			continue
		var entry: Dictionary = c
		var rarity: int = int(LaneUnits.UNITS[entry["res"]["kind"]]["tier"])
		get_tree().create_timer(0.07 * i).timeout.connect(func(): flip(entry, rarity < 2))
		i += 1

func _check_done() -> void:
	if _cards.any(func(c): return not c["open"]) or _show.visible:
		return
	var fresh := 0
	var shards := 0
	var merge_kinds: Array = []
	var army: Dictionary = LaneUnits.load_army()
	for r in _results:
		if r["new"]:
			fresh += 1
		shards += int(r.get("shard", 0))
		var k: String = r["kind"]
		if LaneUnits.has_copies(k, army) and not merge_kinds.has(k):
			merge_kinds.append(k)
	_sum_new.text = "🆕 새 %d" % fresh
	_sum_merge_count.text = "⬆ 합성 가능 %d" % merge_kinds.size()
	_sum_shard.text = "💎 파편 %d" % shards
	_sum_bar.visible = true
	_fill_sum_strip(merge_kinds)
	_table_line.text = "새 병사 %d명 · 복제 %d개" % [fresh, _results.size() - fresh - shards]
	var mnames: Array = merge_kinds.map(func(k): return LaneUnits.UNITS[k]["name"])
	_table_merge.text = ("합성할 수 있어요: " + ", ".join(mnames)) if not mnames.is_empty() else ""
	LaneUI.set_gem_bar(_table.get_node("Gems"))
	_flip_all.visible = false
	var gems_now: int = int(LaneUnits.load_army()["gems"])
	_again.visible = true
	_again.text = "다시 10회\n💎 %d" % LaneUnits.PULL10_COST
	_again.disabled = gems_now < LaneUnits.PULL10_COST
	_sum_ok.visible = true
	_sum_ok.text = "1회 뽑기\n💎 %d" % LaneUnits.PULL_COST
	_sum_ok.disabled = gems_now < LaneUnits.PULL_COST
	_sum_deck.visible = true
	_sum_deck.text = "본부로"
	var buttons: Array = [_again, _sum_ok, _sum_deck]
	var bw: float = 216.0
	var total: float = bw * buttons.size() + 12.0 * (buttons.size() - 1)
	for i in range(buttons.size()):
		buttons[i].position = Vector2((720.0 - total) * 0.5 + i * (bw + 12.0), 860)
	_refresh()

# The front of a card: tier card, the soldier, its name and NEW! / the copies toward a merge
func _card(res: Dictionary, sz: Vector2 = SUM_CARD) -> LaneTierCard:
	var kind: String = res["kind"]
	var u: Dictionary = LaneUnits.UNITS[kind]
	var t: int = int(res["tier"])
	var c := LaneTierCard.new(t, sz)
	var tex: Texture2D = load("res://assets/art/lane/%s.png" % kind)
	var art := TextureRect.new()
	art.texture = tex
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The soldier as big as fits (x2 for most); the frame colour shows the tier, so no tier text
	var area := Vector2(sz.x - 14, sz.y * 0.63)
	# Rounded, so a tall soldier still gets x2 and stands a little over the frame top
	var k: float = clampf(roundf(minf(area.x / tex.get_width(), area.y / tex.get_height())), 1.0, 2.0)
	art.size = Vector2(tex.get_width(), tex.get_height()) * k
	art.position = Vector2((sz.x - art.size.x) * 0.5, 8 + area.y - art.size.y)
	c.add_child(art)
	var fs: int = 18 if sz.x >= 140 else 16
	var n := LaneUI.label(u["name"], fs, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	n.position = Vector2(0, sz.y * 0.67)
	n.size = Vector2(sz.x, 24)
	c.add_child(n)
	var tag_text: String = "NEW!" if res["new"] else ("💎 파편 +1" if int(res.get("shard", 0)) > 0 else _copies_short(int(res["copies"]), t))
	var ready: bool = not res["new"] and LaneUnits.merge_need(t) > 0 and int(res["copies"]) >= LaneUnits.merge_need(t)
	var tag := LaneUI.label(tag_text, 15, LaneUI.GOLD if res["new"] or ready else Color(0.7, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	tag.position = Vector2(0, sz.y - 30)
	tag.size = Vector2(sz.x, 22)
	c.add_child(tag)
	return c

func _copies_short(copies: int, tier: int) -> String:
	var need: int = LaneUnits.merge_need(tier)
	if need <= 0:
		return "+1"
	return "합성!" if copies >= need else "+1  %d/%d" % [copies, need]

# ---------------------------------------------------------------------------
# The big show for 유니크 and 레전더리: the soldier big on turning rays, tap to close

func _build_show() -> void:
	_show = Control.new()
	_show.visible = false
	_show.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_show.mouse_filter = Control.MOUSE_FILTER_STOP
	_show.gui_input.connect(func(ev: InputEvent):
		if (ev is InputEventMouseButton or ev is InputEventScreenTouch) and ev.pressed:
			_advance = true)
	add_child(_show)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.06, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_show.add_child(shade)
	var layer := Node2D.new()
	_show.add_child(layer)
	_show_rays = _sprite("summon_rays", Vector2(360, 540), 6.0, layer)
	_show_burst = _sprite("summon_burst", Vector2(360, 540), 6.0, layer)
	_show_box = Control.new()
	_show_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_show_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_show.add_child(_show_box)
	var hint := LaneUI.label("화면을 누르면 닫혀요", 18, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	hint.position = Vector2(0, 1040)
	hint.size = Vector2(720, 26)
	_show.add_child(hint)

func _big_show(res: Dictionary) -> void:
	var kind: String = res["kind"]
	var u: Dictionary = LaneUnits.UNITS[kind]
	var rarity: int = int(u["tier"])
	var tier: int = int(res["tier"])
	var col: Color = LIGHT[rarity]
	for c in _show_box.get_children():
		c.queue_free()
	_show.visible = true
	_show_rays.modulate = Color(col, 0.0)
	_show_rays.scale = Vector2(4.0, 4.0)
	var rt := _show_rays.create_tween().set_parallel(true)
	rt.tween_property(_show_rays, "modulate:a", 0.3 + 0.2 * rarity, 0.25)
	rt.tween_property(_show_rays, "scale", Vector2(6.0, 6.0) + Vector2.ONE * rarity, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_show_burst.modulate = Color(col, 0.0)
	_show_burst.scale = Vector2(2.0, 2.0)
	var bt := _show_burst.create_tween().set_parallel(true)
	bt.tween_property(_show_burst, "modulate:a", 1.0, 0.08)
	bt.tween_property(_show_burst, "scale", Vector2(7.0, 7.0) + Vector2.ONE * 2.0 * (rarity - 1), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bt.chain().tween_property(_show_burst, "modulate:a", 0.0, 0.35)

	var card := LaneTierCard.new(tier, SHOW_CARD)
	card.position = Vector2(360, 540) - SHOW_CARD * 0.5
	card.pivot_offset = SHOW_CARD * 0.5
	_show_box.add_child(card)
	var art := TextureRect.new()
	art.texture = load("res://assets/art/lane/%s.png" % kind)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.size = Vector2(art.texture.get_width(), art.texture.get_height())
	# Whole-number scale, x5 for a soldier; big ones (the dragon rider) get less
	var k: float = clampf(roundf(minf(330.0 / art.size.x, 230.0 / art.size.y)), 2.0, 5.0)
	art.scale = Vector2(k, k)
	art.position = Vector2((SHOW_CARD.x - art.size.x * k) * 0.5, 40 + (230 - art.size.y * k) * 0.5)
	card.add_child(art)
	var role := LaneUI.label(u["role"], 20, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	role.position = Vector2(0, SHOW_CARD.y - 74)
	role.size = Vector2(SHOW_CARD.x, 28)
	card.add_child(role)
	var name_l := LaneUI.label(u["name"], 44, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	name_l.position = Vector2(0, 190)
	name_l.size = Vector2(720, 56)
	_show_box.add_child(name_l)
	var tier_l := LaneUI.label(LaneUnits.TIER_NAME[tier], 26, LaneUnits.tier_color(tier).lightened(0.35), HORIZONTAL_ALIGNMENT_CENTER)
	tier_l.position = Vector2(0, 246)
	tier_l.size = Vector2(720, 34)
	_show_box.add_child(tier_l)
	var desc := LaneUI.label(u["desc"], 19, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	desc.position = Vector2(60, 736)
	desc.size = Vector2(600, 30)
	_show_box.add_child(desc)
	var tag: Control
	if res["new"]:
		tag = LaneUI.ribbon("NEW!", 220, 30)
		tag.position = Vector2(250, 790)
	else:
		tag = LaneUI.label("💎 파편 +1" if int(res.get("shard", 0)) > 0 else _copies_text(int(res["copies"]), tier), 26, LaneUI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		tag.position = Vector2(0, 796)
		tag.size = Vector2(720, 40)
	tag.pivot_offset = tag.size * 0.5
	tag.modulate.a = 0.0
	_show_box.add_child(tag)

	card.scale = Vector2(0.05, 1.0)
	var ct := card.create_tween()
	ct.tween_property(card, "scale", Vector2(1.12, 1.12), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ct.tween_property(card, "scale", Vector2.ONE, 0.1)
	SoundManager.play_battle("g_reveal_2", -2.0)
	_flash_screen(0.9, 0.4 + 0.15 * (rarity - 2), col)
	_shake(_show_box, 12.0 + 8.0 * (rarity - 2), 0.35 + 0.25 * (rarity - 2))
	card.burst()
	_burst_sparkles(col, 6 + 8 * rarity)
	if rarity >= 3:
		get_tree().create_timer(0.35).timeout.connect(func():
			SoundManager.play_battle("g_reveal_2", -4.0)
			_flash_screen(0.7, 0.4, Color(1, 0.95, 0.7))
			_burst_sparkles(col, 24))
	var tt := tag.create_tween()
	tt.tween_interval(0.35)
	tt.tween_callback(func():
		tag.modulate.a = 1.0
		if res["new"]:
			SoundManager.play_battle("g_new", -4.0))
	tag.scale = Vector2(2.2, 2.2)
	tt.tween_property(tag, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Stays until a tap (after a moment), or closes by itself
	await get_tree().create_timer(0.5).timeout
	_advance = false
	var t := 0.0
	while t < 4.0 and not _advance and visible and _show.visible:
		await get_tree().process_frame
		t += get_process_delta_time()
	_show.visible = false
	_check_done()

func _copies_text(copies: int, tier: int) -> String:
	var need: int = LaneUnits.merge_need(tier)
	if need <= 0:
		return "+1 복제"
	if copies >= need:
		return "+1 복제 · 합성할 수 있어요!"
	return "+1 복제 · 합성까지 %d / %d" % [copies, need]

func _burst_sparkles(col: Color, count: int) -> void:
	for i in range(count):
		var s := _sprite("summon_sparkle", Vector2(360, 540), rng.randf_range(1.5, 3.5), _show_rays.get_parent())
		s.modulate = col.lightened(0.3)
		var to: Vector2 = Vector2(360, 540) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(160, 330)
		var tw := s.create_tween().set_parallel(true)
		tw.tween_property(s, "position", to, rng.randf_range(0.45, 0.8)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "rotation", rng.randf_range(-3, 3), 0.8)
		tw.chain().tween_property(s, "modulate:a", 0.0, 0.3)
		tw.chain().tween_callback(s.queue_free)

func _flash_screen(a: float, dur: float, col: Color = Color.WHITE) -> void:
	_flash.color = Color(col, a)
	var tw := _flash.create_tween()
	tw.tween_property(_flash, "color:a", 0.0, dur)

func _shake(node: CanvasItem, power: float, dur: float) -> void:
	var base: Vector2 = node.position
	var tw := node.create_tween()
	var steps := int(dur / 0.04)
	for i in range(steps):
		var k: float = power * (1.0 - float(i) / steps)
		tw.tween_property(node, "position", base + Vector2(rng.randf_range(-k, k), rng.randf_range(-k, k)), 0.04)
	tw.tween_property(node, "position", base, 0.04)
