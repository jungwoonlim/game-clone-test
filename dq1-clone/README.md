# Dragon Quest 1 Clone (Godot 4)

초대 드래곤 퀘스트(1986, NES)의 **시스템 클론**. 2D로 먼저 만들고, 이후 2.5D 리메이크로 이어집니다.

> **현재 상태: M0~M2 완료.** 마을·필드·던전을 걸어다니고, 랜덤 인카운터가 발생하고,
> 전투가 실제로 해결되며 레벨이 오릅니다. 전투 화면은 아직 텍스트입니다 (M3에서 교체).

| 필드 | 전투 (텍스트 단계) |
| --- | --- |
| ![field](docs/screenshot-field.png) | ![battle](docs/screenshot-battle.png) |

## 실행

1. [Godot 4.4 이상](https://godotengine.org/download) 설치
2. **Import** → 이 폴더의 `project.godot`
3. **F5**

| 동작 | 키 |
| --- | --- |
| 이동 | 방향키 |
| 전투: 공격 | Space |
| 전투: Heal / Hurt | H / J |
| 전투: 도망 | F |

## 지금 되는 것 / 아직 아닌 것

| | 상태 |
| --- | --- |
| 그리드 이동, 지형 통행, 늪 데미지 | ✅ |
| 마을 ↔ 필드 ↔ 던전 워프 | ✅ |
| 랜덤 인카운터, 지형별 조우율, Repel | ✅ |
| 턴제 전투 (공격/크리티컬/선공/도망) | ✅ |
| 주문 10종, 수면·주문봉인 | ✅ |
| 몬스터 행동 테이블 (HP 비율 조건 포함) | ✅ |
| EXP·골드·레벨업·주문 습득 | ✅ |
| 사망 → 골드 절반 상실 → 부활 | ✅ |
| 전투 연출, 커맨드 UI | ❌ M3 |
| NPC 대화, 상점, 여관, 세이브 | ❌ M4 |
| 던전 시야 제한, 보물상자, 보스전 | ❌ M5 |

## 구조

핵심 규칙은 두 개입니다. 이게 지켜지는 한 2.5D 리메이크는 **뷰 교체**로 끝납니다.

> 1. **`core/`는 `view_2d/`를 절대 참조하지 않는다.** 통신은 시그널로 단방향.
> 2. **`core/`에는 `Node2D`/`Node3D`/`Control`이 없다.** 순수 GDScript 클래스와 `Resource`만.

`core/`가 한 턴을 즉시 해결해 **이벤트 목록**으로 돌려주고, 뷰가 그걸 천천히 재생합니다.
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
$G --headless --path . --script res://tools/validate_data.gd     # 509 checks
$G --headless --path . --script res://tools/test_core.gd         # 106 checks
$G --headless --path . --script res://tools/smoke_view.gd        #   9 checks

# 밸런스 리포트 생성 → docs/07-BALANCE_REPORT.md
$G --headless --path . --script res://tools/simulate_balance.gd
```

`build_*.gd`는 **덮어씁니다.** 시딩 이후에는 `core/data/*.tres`가 진실이고, 인스펙터에서 편집하면 됩니다.

## 밸런스는 눈이 아니라 시뮬레이션으로

`simulate_balance.gd`가 30레벨 × 8몬스터 × 120전투를 약 3초에 돌려 승률표, 보스 격파 가능 레벨,
필요 전투/걸음 수를 뽑습니다. 실제로 이게 첫 데이터셋의 **보스까지 8,900전투** 문제를 잡아냈습니다.
현재 수치는 [docs/07-BALANCE_REPORT.md](docs/07-BALANCE_REPORT.md).

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
아트와 타일은 전부 `tools/build_tiles.gd`와 `_draw()`로 생성한 플레이스홀더입니다.
