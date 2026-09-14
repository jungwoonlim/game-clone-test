## Every player-facing string passes through here.
##
## Keys live in assets/i18n/strings.csv, which Godot imports into one
## .translation per language. Nothing in core/ knows any of this exists: core
## holds ids, numbers and event kinds, and the view decides what they read as.
##
## Static on purpose — headless tools and tests call it with no scene tree.
class_name Loc
extends RefCounted

## Korean postpositions pick their form from the sound the word ends on, so a
## sentence cannot be assembled from fixed pieces. Translators write the
## ambiguous form the language already has — "약초를", "슬라임이" — as
## `{item}#을(를)`, and this resolves the marker against whatever the
## placeholder turned out to be.
const JOSA_MARK := "#"

## Whether the Korean reading of each digit ends on a consonant: 영 일 삼 육
## 칠 팔 do, 이 사 오 구 do not. "레벨 3#이(가)" has to come out "3이".
const DIGIT_HAS_FINAL := [true, true, false, true, false, false, true, true, true, false]


## Autoloads are attached after _initialize, and GameSettings applies the
## saved language when it is ready — so the locale has to be set through the
## setting, on a later frame, or the setting just overwrites it. Going through
## GameSettings is also the honest path: it is what the player's choice does.
static func force_locale(root: Window, locale: String) -> void:
	var settings := root.get_node_or_null("/root/GameSettings")
	if settings == null:
		TranslationServer.set_locale(locale)
		return
	var index: int = settings.LOCALES.find(locale)
	settings.language = index if index >= 0 else 0
	settings.apply()


static func t(key: String, args: Dictionary = {}) -> String:
	var text := String(TranslationServer.translate(key))
	if not args.is_empty():
		text = text.format(args)
	return resolve_josa(text)


## The translated name of a data resource, falling back to the English that
## the .tres itself carries. Data stays language-neutral: the id is the key.
static func name_of(prefix: String, id: StringName, fallback: String) -> String:
	var key := prefix + String(id).to_upper()
	var text := String(TranslationServer.translate(key))
	return fallback if text == key else text


static func item_name(item: ItemData) -> String:
	return name_of("ITEM_", item.id, item.display_name) if item != null else ""


static func monster_name(monster: MonsterData) -> String:
	return name_of("MONSTER_", monster.id, monster.display_name) if monster != null else ""


static func spell_name(spell: SpellData) -> String:
	return name_of("SPELL_", spell.id, spell.display_name) if spell != null else ""


static func map_name(map: MapData) -> String:
	return name_of("MAP_", map.id, map.display_name) if map != null else ""


## Rewrites every `X#A(B)` into `XA` or `XB`. A marker whose alternatives we
## cannot choose between — an English word, a symbol — keeps both forms, which
## is exactly what Korean writing does when the reading is unknown.
static func resolve_josa(text: String) -> String:
	if not text.contains(JOSA_MARK):
		return text
	var out := ""
	var i := 0
	while i < text.length():
		var c := text[i]
		if c != JOSA_MARK:
			out += c
			i += 1
			continue
		var pair := _read_pair(text, i + 1)
		if pair.is_empty():
			# A bare marker is just a seam between two pieces of text.
			i += 1
			continue
		var final_state := _has_final(out)
		if final_state == 0:
			out += pair["both"]
		else:
			out += pair["with"] if final_state > 0 else pair["without"]
		i = int(pair["end"])
	return out


## Reads `A(B)` starting at `from`. Empty when the text there is not a pair.
static func _read_pair(text: String, from: int) -> Dictionary:
	var open := text.find("(", from)
	if open < 0 or open == from or open - from > 3:
		return {}
	var close := text.find(")", open)
	if close < 0 or close - open > 4:
		return {}
	var with_final := text.substr(from, open - from)
	var without := text.substr(open + 1, close - open - 1)
	if with_final.contains(" ") or without.contains(" "):
		return {}
	return {
		"with": with_final,
		"without": without,
		"both": "%s(%s)" % [with_final, without],
		"end": close + 1,
	}


## 1 = the word ends on a consonant, -1 = on a vowel, 0 = we cannot tell.
static func _has_final(text: String) -> int:
	if text.is_empty():
		return 0
	var code := text.unicode_at(text.length() - 1)
	if code >= 0xAC00 and code <= 0xD7A3:
		return 1 if (code - 0xAC00) % 28 != 0 else -1
	if code >= 0x30 and code <= 0x39:
		return 1 if DIGIT_HAS_FINAL[code - 0x30] else -1
	return 0
