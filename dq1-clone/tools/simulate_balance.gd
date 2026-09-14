## Balance report generator.
##
##   godot --headless --path . --script res://tools/simulate_balance.gd
##
## Fights every monster at every level a few hundred times and writes
## docs/07-BALANCE_REPORT.md. This is what replaces tuning the game by feel:
## when a number in core/data changes, re-run this and read the difference.
extends SceneTree

const BATTLES_PER_MATCHUP := 120
const TURN_CAP := 200
const HEAL_THRESHOLD := 0.35
const OUT_PATH := "res://docs/07-BALANCE_REPORT.md"
const BASE_SEED := 20260914

## Assumed shopping schedule — the simulated hero buys roughly when a real one
## could afford to. Change this and the whole report shifts, so it is stated
## here rather than buried.
const EQUIPMENT_SCHEDULE := [
	[3, "w_club", "a_clothes", ""],
	[7, "w_sword", "a_leather", ""],
	[12, "w_sword", "a_leather", "s_small"],
	[16, "w_blade", "a_plate", "s_small"],
	[22, "w_blade", "a_plate", "s_large"],
]

var _db: GameDatabase
var _timeouts := 0


func _initialize() -> void:
	_db = GameDatabase.load_default()
	if _db == null:
		printerr("[balance] cannot load database")
		quit(1)
		return

	var started := Time.get_ticks_msec()
	var roster := _roster()
	var matrix := _run_matrix(roster)
	var boss := _db.monster(&"m_dragonlord")
	var boss_50 := _first_level_at(matrix, boss.id, 0.5)
	var boss_90 := _first_level_at(matrix, boss.id, 0.9)
	var grind := _grind_estimate(matrix, boss_90)
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0

	var report := _render(roster, matrix, boss_50, boss_90, grind, elapsed)
	var file := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if file == null:
		printerr("[balance] cannot write %s" % OUT_PATH)
		quit(1)
		return
	file.store_string(report)
	file.close()

	print("[balance] %d matchups x %d battles in %.1fs" % [
		roster.size() * _db.level_curve.max_level(), BATTLES_PER_MATCHUP, elapsed])
	print("[balance] boss beatable from level %s (50%%) / %s (90%%)" % [
		str(boss_50) if boss_50 > 0 else "never",
		str(boss_90) if boss_90 > 0 else "never"])
	print("[balance] turn-cap timeouts: %d" % _timeouts)
	print("[balance] wrote %s" % OUT_PATH)
	quit(1 if _timeouts > 0 else 0)


func _roster() -> Array[MonsterData]:
	var out: Array[MonsterData] = []
	for monster in _db.monsters:
		out.append(monster)
	return out


# --- 시뮬레이션 -----------------------------------------------------------

func _equip(hero: Hero, level: int) -> void:
	hero.weapon_id = &""
	hero.armor_id = &""
	hero.shield_id = &""
	for row in EQUIPMENT_SCHEDULE:
		if level >= int(row[0]):
			hero.weapon_id = StringName(row[1])
			hero.armor_id = StringName(row[2])
			hero.shield_id = StringName(row[3])


## Returns { monster_id: { level: {win_rate, turns, hp_left} } }
func _run_matrix(roster: Array[MonsterData]) -> Dictionary:
	var matrix := {}
	var max_level := _db.level_curve.max_level()
	for monster in roster:
		var by_level := {}
		for level in range(1, max_level + 1):
			by_level[level] = _run_matchup(monster, level)
		matrix[monster.id] = by_level
	return matrix


func _run_matchup(monster: MonsterData, level: int) -> Dictionary:
	var wins := 0
	var total_turns := 0
	var total_hp_left := 0

	for battle_index in BATTLES_PER_MATCHUP:
		var rng := Rng.new(BASE_SEED + level * 10007 + battle_index * 31 + monster.id.hash())
		var hero := Hero.create_new(_db)
		hero.apply_level(_db.level_curve, level, true)
		_equip(hero, level)

		var hero_actor := hero.to_battle_actor(_db)
		var battle := BattleState.new(
				hero_actor, BattleActor.from_monster(monster), rng, _db)
		battle.start()

		var turns := 0
		while not battle.is_over() and turns < TURN_CAP:
			turns += 1
			var choice := _choose_command(hero_actor)
			battle.resolve_turn(choice[0], choice[1])
		if turns >= TURN_CAP:
			_timeouts += 1

		total_turns += turns
		if battle.result == BattleState.Result.HERO_WON:
			wins += 1
			total_hp_left += hero_actor.hp

	return {
		"win_rate": float(wins) / float(BATTLES_PER_MATCHUP),
		"turns": float(total_turns) / float(BATTLES_PER_MATCHUP),
		"hp_left": float(total_hp_left) / float(maxi(wins, 1)),
	}


## A competent-but-not-clairvoyant player: heal when badly hurt, otherwise swing.
func _choose_command(hero: BattleActor) -> Array:
	if hero.hp_ratio() < HEAL_THRESHOLD:
		var missing := hero.max_hp - hero.hp
		var healmore := hero.spell_by_id(&"healmore")
		if healmore != null and hero.mp >= healmore.mp_cost and missing >= 60:
			return [BattleState.Command.SPELL, &"healmore"]
		var heal := hero.spell_by_id(&"heal")
		if heal != null and hero.mp >= heal.mp_cost:
			return [BattleState.Command.SPELL, &"heal"]
	return [BattleState.Command.ATTACK, &""]


func _first_level_at(matrix: Dictionary, monster_id: StringName, threshold: float) -> int:
	var by_level: Dictionary = matrix[monster_id]
	for level in range(1, _db.level_curve.max_level() + 1):
		if by_level[level]["win_rate"] >= threshold:
			return level
	return -1


# --- 그라인드 추정 --------------------------------------------------------

func _table_stats(table_id: StringName, map_id: StringName) -> Dictionary:
	var table := _db.encounter_table(table_id)
	var weight_total := 0
	var exp_total := 0
	var gold_total := 0.0
	for entry in table.entries:
		var monster := _db.monster(entry.monster_id)
		weight_total += entry.weight
		exp_total += entry.weight * monster.exp_reward
		gold_total += entry.weight * (monster.gold_reward_min + monster.gold_reward_max) / 2.0

	# Average chance that any one step on this map starts a fight.
	var map := _db.map(map_id)
	var walkable := 0
	var chance_sum := 0.0
	for index in map.tiles.size():
		var terrain := map.tiles[index]
		if not Terrain.is_passable(terrain):
			continue
		walkable += 1
		chance_sum += float(int(map.encounter_rate * Terrain.encounter_multiplier(terrain))) / 256.0
	var per_step := chance_sum / float(maxi(walkable, 1))

	return {
		"exp_per_battle": float(exp_total) / float(weight_total),
		"gold_per_battle": gold_total / float(weight_total),
		"chance_per_step": per_step,
		"steps_per_battle": 1.0 / maxf(per_step, 0.0001),
	}


## Lowest level at which every monster in `table_id` is a safe fight.
func _clear_level(matrix: Dictionary, table_id: StringName, threshold: float) -> int:
	var table := _db.encounter_table(table_id)
	for level in range(1, _db.level_curve.max_level() + 1):
		var all_safe := true
		for entry in table.entries:
			if matrix[entry.monster_id][level]["win_rate"] < threshold:
				all_safe = false
				break
		if all_safe:
			return level
	return -1


## Two-phase estimate: grind the field until the dungeon is survivable, then
## grind the dungeon. A single flat average badly misrepresents a game where
## you are supposed to move to richer hunting grounds.
func _grind_estimate(matrix: Dictionary, boss_level: int) -> Dictionary:
	var field := _table_stats(&"et_field", &"field")
	var dungeon := _table_stats(&"et_dungeon", &"dungeon")
	var switch_level := _clear_level(matrix, &"et_dungeon", 0.8)
	if switch_level < 0 or (boss_level > 0 and switch_level > boss_level):
		switch_level = boss_level

	var exp_at_switch := _exp_for_level(switch_level)
	var exp_at_boss := _exp_for_level(boss_level)
	var field_battles := int(ceil(exp_at_switch / maxf(field["exp_per_battle"], 0.0001)))
	var dungeon_battles := int(ceil(
			maxf(0.0, exp_at_boss - exp_at_switch) / maxf(dungeon["exp_per_battle"], 0.0001)))

	return {
		"field": field,
		"dungeon": dungeon,
		"switch_level": switch_level,
		"field_battles": field_battles,
		"dungeon_battles": dungeon_battles,
		"total_battles": field_battles + dungeon_battles,
		"total_steps": int(field_battles * field["steps_per_battle"]
				+ dungeon_battles * dungeon["steps_per_battle"]),
		"gold_earned": int(field_battles * field["gold_per_battle"]
				+ dungeon_battles * dungeon["gold_per_battle"]),
	}


func _exp_for_level(level: int) -> float:
	if level <= 1:
		return 0.0
	return float(_db.level_curve.required_exp[level - 2])


func _battles_to_reach(level: int, exp_per_battle: float) -> int:
	if level <= 1:
		return 0
	var needed: int = _db.level_curve.required_exp[level - 2]
	return int(ceil(float(needed) / maxf(exp_per_battle, 0.0001)))


# --- 리포트 ---------------------------------------------------------------

func _render(roster: Array[MonsterData], matrix: Dictionary, boss_50: int,
		boss_90: int, grind: Dictionary, elapsed: float) -> String:
	var lines: Array[String] = []
	lines.append("# 07. 밸런스 리포트 (자동 생성)")
	lines.append("")
	lines.append("> `godot --headless --path . --script res://tools/simulate_balance.gd` 로 재생성합니다.")
	lines.append("> 손으로 고치지 마세요 — `core/data/`의 수치를 고치고 다시 돌리세요.")
	lines.append("")
	lines.append("- 매치업당 전투 수: **%d**" % BATTLES_PER_MATCHUP)
	lines.append("- 플레이어 정책: HP가 %d%% 미만이면 회복 주문, 아니면 통상 공격"
			% int(HEAL_THRESHOLD * 100))
	lines.append("- 장비 가정: %s" % _equipment_summary())
	lines.append("- 소요 시간: %.1fs" % elapsed)
	lines.append("")

	lines.append("## 보스 격파 가능 레벨")
	lines.append("")
	lines.append("| 기준 | 레벨 |")
	lines.append("| --- | --- |")
	lines.append("| 승률 50%% | %s |" % (str(boss_50) if boss_50 > 0 else "도달 불가"))
	lines.append("| 승률 90%% | %s |" % (str(boss_90) if boss_90 > 0 else "도달 불가"))
	lines.append("")

	lines.append("## 그라인드 추정")
	lines.append("")
	lines.append("필드에서 던전이 안전해질 때까지(전 몬스터 승률 80%%) 키운 뒤, 던전에서 보스 레벨까지 키운다고 가정합니다.")
	lines.append("")
	lines.append("| 항목 | 필드 | 던전 |")
	lines.append("| --- | --- | --- |")
	lines.append("| 전투 1회 평균 EXP | %.1f | %.1f |"
			% [grind["field"]["exp_per_battle"], grind["dungeon"]["exp_per_battle"]])
	lines.append("| 전투 1회 평균 골드 | %.1f | %.1f |"
			% [grind["field"]["gold_per_battle"], grind["dungeon"]["gold_per_battle"]])
	lines.append("| 전투 1회당 평균 걸음 | %.1f | %.1f |"
			% [grind["field"]["steps_per_battle"], grind["dungeon"]["steps_per_battle"]])
	lines.append("")
	lines.append("| 구간 | 값 |")
	lines.append("| --- | --- |")
	lines.append("| 던전 진입 권장 레벨 | %s |" % (str(grind["switch_level"]) if grind["switch_level"] > 0 else "-"))
	lines.append("| 필드 구간 전투 | 약 %d회 |" % grind["field_battles"])
	lines.append("| 던전 구간 전투 | 약 %d회 |" % grind["dungeon_battles"])
	lines.append("| **총 전투** | **약 %d회** |" % grind["total_battles"])
	lines.append("| **총 걸음** | **약 %s보** |" % _thousands(grind["total_steps"]))
	lines.append("| 그동안 버는 골드 | 약 %s G |" % _thousands(grind["gold_earned"]))
	lines.append("| 장비 풀세트 가격 | %s G |" % _thousands(_full_kit_cost()))
	lines.append("| 골드 여유 배수 | %.1fx |"
			% (float(grind["gold_earned"]) / maxf(float(_full_kit_cost()), 1.0)))
	lines.append("")
	lines.append("> 전투 사이에 완전 회복된다고 가정한 **낙관적 하한**입니다. 실제로는 마을 왕복이 더 붙습니다.")
	lines.append("")
	lines.append("## 레벨 × 몬스터 승률")
	lines.append("")
	var header := "| Lv |"
	var divider := "| --- |"
	for monster in roster:
		header += " %s |" % monster.display_name
		divider += " --- |"
	lines.append(header)
	lines.append(divider)
	for level in range(1, _db.level_curve.max_level() + 1):
		var row := "| %d |" % level
		for monster in roster:
			var rate: float = matrix[monster.id][level]["win_rate"]
			row += " %s |" % _rate_cell(rate)
		lines.append(row)
	lines.append("")
	lines.append("표기: `-` 0% · `%` 승률 · **볼드**는 90% 이상")
	lines.append("")

	lines.append("## 위험 구간")
	lines.append("")
	lines.append("필드 조우 테이블에 있는데 해당 레벨에서 승률 60% 미만인 조합입니다.")
	lines.append("")
	var danger: Array[String] = []
	var field_ids := {}
	for entry in _db.encounter_table(&"et_field").entries:
		field_ids[entry.monster_id] = true
	for monster in roster:
		if not field_ids.has(monster.id):
			continue
		for level in range(1, 13):
			var rate: float = matrix[monster.id][level]["win_rate"]
			if rate < 0.6:
				danger.append("- Lv%d vs %s — 승률 %d%%"
						% [level, monster.display_name, int(round(rate * 100))])
	if danger.is_empty():
		lines.append("없음.")
	else:
		lines.append_array(danger)
	lines.append("")
	lines.append("## 데드락")
	lines.append("")
	lines.append("- 턴 상한(%d턴) 초과 전투: **%d건**" % [TURN_CAP, _timeouts])
	lines.append("")
	return "\n".join(lines) + "\n"


## What it costs to buy one of every weapon, armour and shield. If the grind
## hands out many times this, money has stopped being a decision (M4 shops).
func _full_kit_cost() -> int:
	var total := 0
	for item in _db.items:
		if item.kind == "weapon" or item.kind == "armor" or item.kind == "shield":
			total += item.buy_price
	return total


func _equipment_summary() -> String:
	var parts: Array[String] = []
	for row in EQUIPMENT_SCHEDULE:
		var names: Array[String] = []
		for index in [1, 2, 3]:
			if row[index] != "":
				var item := _db.item(StringName(row[index]))
				if item != null:
					names.append(item.display_name)
		parts.append("Lv%d %s" % [row[0], "+".join(names)])
	return ", ".join(parts)


func _rate_cell(rate: float) -> String:
	if rate <= 0.0:
		return "-"
	var percent := int(round(rate * 100))
	if rate >= 0.9:
		return "**%d**" % percent
	return str(percent)


func _thousands(value: int) -> String:
	var text := str(value)
	var out := ""
	var count := 0
	for i in range(text.length() - 1, -1, -1):
		out = text[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out
