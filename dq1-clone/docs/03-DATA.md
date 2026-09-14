# 03. 데이터 스키마 및 테이블

모든 게임 데이터는 Godot `Resource`로 정의합니다. 이유:

- 에디터에서 인스펙터로 편집 가능
- `.tres` 텍스트 포맷이라 **git diff가 읽힙니다**
- `core/`가 파일 포맷을 몰라도 됩니다

> ⚠️ **이 문서의 수치는 대부분 플레이스홀더입니다.** 구조는 확정이지만 값은 ROM/디스어셈블 대조 전까지 임시입니다. 라벨 규칙은 `02-SYSTEMS.md` 참조.

---

## 1. 스키마

### MonsterData

```gdscript
class_name MonsterData extends Resource

@export var id: StringName
@export var display_name: String
@export var max_hp: int
@export var strength: int          # 공격력으로 직접 사용
@export var agility: int           # 방어·선공·회피에 사용
@export var exp_reward: int
@export var gold_reward_min: int
@export var gold_reward_max: int

# 행동 패턴: 가중치 기반 추첨
@export var actions: Array[MonsterAction]

# 저항 (0=무저항, 255=완전저항)
@export var resist_sleep: int
@export var resist_stopspell: int
@export var resist_hurt: int

@export var can_flee_from: bool = true    # 보스는 false
@export var can_be_critical: bool = true  # 보스는 false
```

### MonsterAction

```gdscript
class_name MonsterAction extends Resource

@export_enum("attack", "spell", "breath", "flee") var kind: String
@export var spell_id: StringName        # kind == "spell"일 때
@export var weight: int = 1             # 추첨 가중치
@export var hp_threshold: float = 1.0   # HP 비율이 이 값 이하일 때만 후보
```

### SpellData

```gdscript
class_name SpellData extends Resource

@export var id: StringName
@export var display_name: String
@export var mp_cost: int
@export_enum("damage", "heal", "status", "field") var kind: String
@export var learn_level: int

# 시전자별 위력이 다르므로 분리해서 보관
@export var power_min_by_hero: int
@export var power_max_by_hero: int
@export var power_min_by_monster: int
@export var power_max_by_monster: int

@export var usable_in_battle: bool = true
@export var usable_in_field: bool = false
```

### ItemData

```gdscript
class_name ItemData extends Resource

@export var id: StringName
@export var display_name: String
@export_enum("weapon", "armor", "shield", "consumable", "key") var kind: String
@export var buy_price: int
@export var sell_price: int            # 통상 buy_price / 2
@export var attack_bonus: int
@export var defense_bonus: int
@export var hurt_reduction: float      # 0.0 ~ 1.0
@export var effect_id: StringName      # 소모품 효과
```

### LevelCurve

```gdscript
class_name LevelCurve extends Resource

@export var required_exp: Array[int]   # index = level-2 → 해당 레벨 도달 누적 EXP
@export var strength: Array[int]       # index = level-1
@export var agility: Array[int]
@export var max_hp: Array[int]
@export var max_mp: Array[int]
```

> 성장을 "증가량"이 아니라 **레벨별 절대값 테이블**로 둡니다. 원작이 그렇고, 이쪽이 검증도 쉽습니다.

### MapData

```gdscript
class_name MapData extends Resource

@export var id: StringName
@export var width: int
@export var height: int
@export var tiles: PackedByteArray          # width*height, 지형 타입 ID
@export var elevation: PackedByteArray      # width*height. 2D에서는 전부 0
@export var encounter_table_id: StringName
@export var encounter_rate: int             # 0..255
@export var is_dungeon: bool
@export var base_sight_radius: int          # 던전 기본 시야
@export var warps: Array[WarpPoint]
@export var npcs: Array[NpcPlacement]
```

> **`elevation`은 2D 단계에서 전혀 쓰이지 않습니다.** 나중에 2.5D로 갈 때 맵을 다시 그리지 않기 위한 싼 보험입니다. (→ `04-ARCHITECTURE.md`)

### EncounterTable

```gdscript
class_name EncounterTable extends Resource

@export var id: StringName
@export var entries: Array[EncounterEntry]  # { monster_id, weight, min_level_for_repel }
```

---

## 2. 초기 테이블 (플레이스홀더)

### 2-1. EXP 테이블 ⚠️

레벨 2~30 도달 누적치. 복수 출처 일치하나 ROM 대조 전까지 검증 대상.

```
7, 23, 47, 110, 220, 450, 800, 1300, 2000, 2900,
4000, 5500, 7500, 10000, 13000, 16000, 19000, 22000, 26000, 30000,
34000, 38000, 42000, 46000, 50000, 54000, 58000, 62000, 65535
```

### 2-2. 주문 ⚠️

`02-SYSTEMS.md` 3절 표 참조. 습득 레벨 ✅ / MP 및 위력 ⚠️❓.

### 2-3. 세로 슬라이스 몬스터 8종 ❓

**전부 미검증 플레이스홀더입니다.** 헤드리스 시뮬레이션(→ M0)으로 난이도 곡선을 먼저 맞추고, 이후 원작 수치로 교체합니다.

| # | 역할 | HP | 힘 | 민첩 | EXP | 골드 | 행동 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 최약체 (첫 전투용) | 3 | 5 | 3 | 1 | 2 | 공격만 |
| 2 | 약체 변형 | 4 | 7 | 3 | 1 | 4 | 공격만 |
| 3 | 비행형 | 6 | 9 | 6 | 2 | 6 | 공격만 |
| 4 | 유령형 | 7 | 11 | 8 | 3 | 12 | 공격 / 회피 높음 |
| 5 | 주문형 | 13 | 11 | 12 | 4 | 20 | 공격 / Hurt |
| 6 | 상태이상형 | 20 | 18 | 16 | 6 | 25 | 공격 / Sleep |
| 7 | 던전 상급 | 35 | 28 | 22 | 15 | 60 | 공격 / Hurt / 회복 |
| 8 | **보스** | 100 | 45 | 40 | 0 | 0 | 공격 / Hurtmore / 2페이즈 |

보스는 `can_flee_from = false`, `can_be_critical = false`.

### 2-4. 장비 ❓

| 종류 | 이름 | 가격 | 보정 |
| --- | --- | --- | --- |
| 무기 | 티어1 | 10 | 공격 +2 |
| 무기 | 티어2 | 60 | 공격 +7 |
| 무기 | 티어3 | 180 | 공격 +15 |
| 갑옷 | 티어1 | 20 | 방어 +2 |
| 갑옷 | 티어2 | 70 | 방어 +4 |
| 갑옷 | 티어3 | 300 | 방어 +10, Hurt 1/3 경감 |
| 방패 | 티어1 | 90 | 방어 +4 |
| 방패 | 티어2 | 800 | 방어 +10 |

> 고유명사는 개발 단계에서 티어 번호로 둡니다. 공개 시 교체 부담을 없애기 위해서입니다.

---

## 3. 데이터 검증 방침

수치를 넣는 것과 **맞는지 아는 것**은 다릅니다. 두 층으로 검증합니다.

1. **정합성 테스트** (자동, 상시)
   - 모든 `learn_level`이 1~30 범위인가
   - EXP 테이블이 단조 증가인가
   - 모든 `EncounterEntry.monster_id`가 실재하는가
   - 모든 상점 품목이 `ItemData`에 있는가
   - 레벨 커브 배열 길이가 30인가

2. **밸런스 시뮬레이션** (자동, 데이터 변경 시)
   - 레벨별 대 몬스터 승률
   - 보스 격파 가능 최소 레벨
   - 해당 레벨까지 필요한 평균 전투 횟수 / 소요 걸음 수

두 번째가 이 프로젝트에서 **눈으로 하는 밸런싱을 대체합니다.** 상세는 `04-ARCHITECTURE.md`.

---

## 출처

원작 수치 조사에 사용한 출처. 서로 충돌하는 부분이 있어 **ROM 대조 전까지 확정하지 않습니다.**

- [Dragon Warrior - Formula Guide (GameFAQs, Ryan8bit)](https://gamefaqs.gamespot.com/nes/563408-dragon-warrior/faqs/61640)
- [Game Systems - Dragon Warrior (gamercorner guides)](https://guides.gamercorner.net/dw/walkthrough/game-systems)
- [Mike's RPG Center - Dragon Warrior Experience Levels](https://mikesrpgcenter.com/dw1/levels.html)
- [TheAnsarya/dragon-warrior-info — GAME_FORMULAS.md](https://github.com/TheAnsarya/dragon-warrior-info/blob/master/docs/technical/GAME_FORMULAS.md)
- [Dragon Warrior/Enemies (StrategyWiki)](https://strategywiki.org/wiki/Dragon_Warrior/Enemies)
