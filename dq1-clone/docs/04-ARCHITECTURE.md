# 04. 아키텍처

## 대전제

**2.5D 리메이크를 "렌더러 교체"로 만들기 위한 구조입니다.**

RPG 작업량의 대부분(스탯, 전투, 성장, 인벤토리, 대화, 세이브)은 화면이 2D인지 3D인지 모릅니다. 그 부분을 렌더링에서 완전히 떼어내면, 나중에 뷰만 갈아끼우면 됩니다.

## 규칙 두 개

> **1. `core/`는 `view/`를 절대 참조하지 않는다.** 통신은 시그널로 단방향(core → view).
> **2. `core/`에는 `Node2D`/`Node3D`/`Control`이 없다.** 순수 GDScript 클래스와 `Resource`만.

이 두 줄이 지켜지는 한 2.5D 전환은 `view_2d/`를 `view_3d/`로 바꾸는 작업이 됩니다. 깨지는 순간 전면 재작성이 됩니다. **PR마다 이걸 먼저 봅니다.**

## 폴더 구조

```
dq1-clone/
├── project.godot
├── docs/
├── core/                      ← 렌더링 의존성 0
│   ├── data/                  Resource 정의 + .tres 데이터
│   │   ├── monsters/
│   │   ├── spells/
│   │   ├── items/
│   │   └── maps/
│   ├── battle/
│   │   ├── battle_state.gd    전투 상태머신 (순수 로직)
│   │   ├── formulas.gd        ★ 모든 전투 공식이 여기에만 존재
│   │   └── actor.gd           전투 참가자 (플레이어/몬스터 공통)
│   ├── world/
│   │   ├── world_state.gd     현재 맵, 논리 좌표, 걸음 수
│   │   ├── movement.gd        그리드 이동·통행 판정
│   │   └── encounter.gd       인카운터 추첨
│   ├── party/
│   │   ├── hero.gd            스탯, 레벨업, 장비, 인벤토리
│   │   └── progression.gd     EXP → 레벨, 주문 습득
│   ├── dialogue/              대화 트리, 이벤트 플래그
│   ├── save/
│   └── rng.gd                 ★ 시드 주입형 난수. 전역 randi() 금지
│
├── view_2d/                   ← 나중에 view_3d/ 로 교체되는 층
│   ├── field/                 TileMapLayer, 캐릭터 스프라이트, 카메라
│   ├── battle/                전투 화면 연출
│   └── ui/                    메시지 창, 커맨드 메뉴, 스테이터스
│
├── scenes/
│   └── main.tscn              core와 view를 조립하는 유일한 지점
│
└── tools/
    ├── validate_data.gd       데이터 정합성 검사
    └── simulate_balance.gd    전투 시뮬레이션
```

## 신호 흐름

```
        입력
         ↓
   view_2d (Input → 의도)
         ↓  메서드 호출
   ┌─────────────┐
   │    core     │   상태 변경
   └─────────────┘
         ↓  시그널 (hp_changed, damage_dealt, level_up, map_changed …)
   view_2d (애니메이션·사운드·메시지 출력)
```

view는 core의 메서드를 **부르고**, core는 시그널로 **알립니다.** core가 view의 존재를 아는 경로는 없습니다.

핵심 함의: **core는 애니메이션을 기다리지 않습니다.** 전투 한 턴은 core에서 즉시 해결되고, 그 결과가 이벤트 목록으로 나옵니다. view는 그 목록을 받아 천천히 재생합니다. 그래서 같은 전투를 0초에 1000번 돌릴 수 있습니다.

```gdscript
# core는 이렇게 반환한다
var events := battle.resolve_turn(PlayerCommand.ATTACK)
# → [ {type="attack", actor="hero", damage=7},
#      {type="message", key="monster_hurt"},
#      {type="attack", actor="monster", damage=3} ]

# view는 이걸 하나씩 연출한다 (await 가능)
```

## 난수 규칙

**`core/`에서 전역 `randi()` / `randf()`를 쓰지 않습니다.** 전부 주입된 `Rng` 인스턴스를 거칩니다.

이유는 하나입니다 — **시드를 고정하면 전투가 완전히 재현됩니다.** 밸런스 시뮬레이션도, 버그 재현도, 회귀 테스트도 전부 여기에 의존합니다. 이 규칙 하나가 RPG 디버깅의 난이도를 통째로 바꿉니다.

## 헤드리스 테스트 전략

`suika-game/`에서 검증한 방식을 그대로 가져옵니다. core가 렌더러와 분리되어 있으므로 에디터 없이 전부 돌아갑니다.

```bash
godot --headless --path . --script res://tools/validate_data.gd
godot --headless --path . --script res://tools/simulate_balance.gd
```

### 1. 데이터 정합성 (`validate_data.gd`)

참조 무결성과 범위 검사. 실패 시 exit 1. → `03-DATA.md` 3절

### 2. 밸런스 시뮬레이션 (`simulate_balance.gd`)

레벨 × 몬스터 조합마다 전투를 N번 돌려 통계를 냅니다.

```
Lv 1 vs 몬스터1 : 승률 94%  평균 2.3턴  평균 피해 4HP
Lv 1 vs 몬스터5 : 승률 11%  ← 위험 구간
...
보스 격파 가능 최소 레벨: 14 (승률 50% 기준) / 17 (승률 90% 기준)
Lv17까지 필요한 전투 횟수: 평균 210회
Lv17까지 필요한 걸음 수:   평균 약 5,400보
```

**이 숫자가 곧 기획입니다.** "보스까지 5,400보"가 너무 길다고 판단되면, 플레이해보고 감으로 고치는 게 아니라 EXP 테이블이나 인카운터율을 고치고 시뮬레이션을 다시 돌립니다.

### 3. 진행 가능성 검사

데드락 탐지 — 특정 레벨에서 골드가 부족해 장비를 못 사고, 장비가 없어 레벨을 못 올리는 구간이 생기는지. RPG 밸런싱에서 실제로 자주 나는 사고입니다.

## 2.5D 전환 대비

**지금 하는 것 — 딱 두 가지뿐입니다.**

1. **`core/`를 렌더러와 분리** (위 규칙 두 개)
2. **`MapData.elevation` 필드를 미리 둔다** — 2D 렌더러는 무시. 나중에 HD-2D로 갈 때 맵을 다시 그리지 않기 위한 보험. 필드 하나 값입니다

**지금 하지 않는 것.** 3D를 위한 추상 레이어를 미리 만들거나, 카메라를 미리 추상화하거나, 렌더러 인터페이스를 뽑아두는 일은 하지 않습니다. 아직 필요한 모양을 모르는 채로 추상화하면 나중에 두 번 고치게 됩니다.

전환 시점은 **세로 슬라이스가 끝까지 플레이되는 상태가 된 다음**입니다.
