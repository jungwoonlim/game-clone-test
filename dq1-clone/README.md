# Dragon Quest 1 Clone (Godot 4)

초대 드래곤 퀘스트(1986, NES)의 **시스템 클론**. 2D로 먼저 만들고, 이후 2.5D 리메이크로 이어집니다.

> **현재 상태: M0~M5 완료 — 세로 슬라이스가 처음부터 끝까지 플레이됩니다.**
> 마을에서 장비를 사고, 여관에서 자고, 왕에게 세이브하고, 필드에서 레벨을 올려
> 던전 2층의 마왕을 쓰러뜨리는 것까지 전부 동작합니다.

| 마을 | 필드 |
| --- | --- |
| ![town](docs/screenshot-town.png) | ![field](docs/screenshot-field.png) |
| **던전 (시야 제한)** | **보스 2페이즈** |
| ![dungeon](docs/screenshot-dungeon.png) | ![boss](docs/screenshot-boss.png) |

## 실행

1. [Godot 4.4 이상](https://godotengine.org/download) 설치
2. **Import** → 이 폴더의 `project.godot`
3. **F5**

| 동작 | 키 |
| --- | --- |
| 이동 | 방향키 |
| 메뉴 열기 / 확인 | Space, Enter, Z |
| 취소 | Esc, X |
| 메시지 넘기기 | 아무 키 |

필드 메뉴: `TALK` `TAKE` `STATUS` `SPELL` `ITEM` `EQUIP` · 전투 메뉴: `FIGHT` `SPELL` `ITEM` `RUN`

## 구현 상태

| | |
| --- | --- |
| 그리드 이동, 지형 통행, 늪 데미지, NPC 충돌 | ✅ |
| 마을 ↔ 필드 ↔ 던전 B1 ↔ B2 워프 | ✅ |
| 랜덤 인카운터, 지형별 조우율, Repel | ✅ |
| 턴제 전투 (공격/회심의 일격/선공/도망) | ✅ |
| 주문 10종 (전투 6 + 필드 4), 수면·주문봉인 | ✅ |
| 몬스터 행동 테이블 (HP 비율 조건) | ✅ |
| EXP·골드·레벨업·주문 습득 | ✅ |
| 타자기 메시지 창, DQ식 커맨드 메뉴 | ✅ |
| NPC 대화 + 이벤트 플래그 분기 | ✅ |
| 상점 3종 (구입/판매), 여관, 장비 교체, 소지품 10칸 | ✅ |
| 왕에게 세이브 / 사망 → 골드 절반 → 부활 | ✅ |
| 던전 시야 제한, 횃불, Radiant | ✅ |
| 보물상자 (1회 한정, 세이브에 기록) | ✅ |
| 보스전 — 도망·회심 불가, **2페이즈 변신** | ✅ |
| 사운드, 아트 교체, 타이틀 화면 | ❌ M6 |
| 2.5D 리메이크 | ❌ M7 |

## 구조

핵심 규칙은 두 개뿐입니다. 이게 지켜지는 한 2.5D 리메이크는 **뷰 교체**로 끝납니다.

> 1. **`core/`는 `view_2d/`를 절대 참조하지 않는다.** 통신은 시그널로 단방향.
> 2. **`core/`에는 `Node2D`/`Node3D`/`Control`이 없다.** 순수 GDScript 클래스와 `Resource`만.

M3(전투 화면)은 이 규칙의 실전 검증이었습니다 — **`core/` 변경 0줄**로 완료했습니다.

`core/`가 한 턴을 즉시 해결해 **이벤트 목록**으로 돌려주고, 뷰가 그걸 타자기 속도로 재생합니다.
애니메이션을 기다리지 않으므로 같은 전투를 0초에 1000번 돌릴 수 있습니다.

자세한 건 [docs/04-ARCHITECTURE.md](docs/04-ARCHITECTURE.md).

## 툴 (전부 헤드리스)

```bash
G=godot   # 4.4+

# 데이터 시딩 — 최초 1회, 또는 데이터를 다시 만들 때만
$G --headless --path . --script res://tools/build_tiles.gd
$G --headless --path . --import
$G --headless --path . --script res://tools/build_data.gd
$G --headless --path . --import

# 상시 검증
$G --headless --path . --script res://tools/validate_data.gd   # 649 checks
$G --headless --path . --script res://tools/test_core.gd       # 223 checks
$G --headless --path . --script res://tools/smoke_view.gd      #  16 checks

# 밸런스 리포트 → docs/07-BALANCE_REPORT.md
$G --headless --path . --script res://tools/simulate_balance.gd
```

`smoke_view.gd`는 **실제 main 씬을 띄워 프레임 단위로 플레이합니다** — 상점에서 곤봉을 사고,
장비하고, 여관에서 자고, 왕에게 세이브하고, 마을을 나가 전투를 치르고, 던전에서 상자를 열고,
마왕을 쓰러뜨립니다. 메뉴를 눌러 진행하므로 **입력을 기다리다 멈추는 데드락**도 잡힙니다.

`build_*.gd`는 **덮어씁니다.** 시딩 이후에는 `core/data/*.tres`가 진실이고, 인스펙터에서 편집하면 됩니다.

## 밸런스는 눈이 아니라 시뮬레이션으로

`simulate_balance.gd`가 30레벨 × 9몬스터 × 120전투를 약 3초에 돌려 승률표, 보스 격파 가능 레벨,
필요 전투/걸음 수를 뽑습니다. 실제로 이게 첫 데이터셋의 **보스까지 8,900전투** 문제를 잡아냈습니다.
현재는 **약 672전투 / 6,922보, 보스 격파 Lv17~18** (원작 권장 18~20에 근접).
상세는 [docs/07-BALANCE_REPORT.md](docs/07-BALANCE_REPORT.md).

## 원작 수치에 대하여

전투 공식은 출처마다 충돌합니다. 값마다 검증 상태(✅/⚠️/❓)를 달고, 공식과 상수를
`core/battle/formulas.gd` 한 파일에 모아 나중에 데이터만 고칠 수 있게 했습니다.
판정 기록은 [docs/06-VERIFICATION.md](docs/06-VERIFICATION.md).

## 문서

| | 내용 |
| --- | --- |
| [00-ENGINE_DECISION.md](docs/00-ENGINE_DECISION.md) | 왜 Godot인가 |
| [01-GDD.md](docs/01-GDD.md) | 게임 개요, 클론 원칙, 범위, 비목표 |
| [02-SYSTEMS.md](docs/02-SYSTEMS.md) | 시스템 명세 + 원작 공식 |
| [03-DATA.md](docs/03-DATA.md) | Resource 스키마와 테이블 |
| [04-ARCHITECTURE.md](docs/04-ARCHITECTURE.md) | core/view 분리, 헤드리스 테스트 |
| [05-ROADMAP.md](docs/05-ROADMAP.md) | M0~M7 마일스톤 |
| [06-VERIFICATION.md](docs/06-VERIFICATION.md) | 원작 수치 검증 기록 |
| [07-BALANCE_REPORT.md](docs/07-BALANCE_REPORT.md) | 밸런스 리포트 (자동 생성) |

## 주의

학습용 클론입니다. 원작의 이름·캐릭터·아트·음악은 스퀘어에닉스의 자산이며 이 저장소에 포함되지 않습니다.
타일과 스프라이트는 전부 `tools/build_tiles.gd`와 `_draw()`로 생성한 플레이스홀더입니다.
