# 이 게임을 스팀에 출시하려면

Godot 게임을 Steam에 올리는 전체 경로입니다. 순서대로 읽으면 됩니다.

> ⚠️ 수수료·규격·정책은 밸브가 종종 바꿉니다. 실제 작업 직전에
> [Steamworks 문서](https://partner.steamgames.com/doc/home)에서 최신 수치를 다시 확인하세요.
> (예: 캡슐 이미지 규격은 2024년 8월에 전부 2배 해상도로 상향됐고, 구 규격은 신규 등록에 더 이상 받지 않습니다.)

---

## 0. 먼저: 이 게임은 지금 상태로 출시하면 안 됩니다

두 가지 이유입니다.

### 법적 체크 (클론 특유의 리스크)

- **게임 규칙·메커닉 자체는 저작권 보호 대상이 아닙니다.** "같은 걸 합쳐서 큰 걸
  만든다"는 아이디어는 자유롭게 쓸 수 있습니다.
- **보호되는 건 표현입니다.** 원작 *Suika Game* (Aladdin X)의 **이름, 과일
  캐릭터 디자인, UI 레이아웃, 사운드, 폰트**를 가져오면 문제가 됩니다.
  이 프로젝트가 코드로 도형을 그리는 이유이기도 합니다 — 원작 에셋이 한 톨도 없습니다.
- 상표: 제목에 "Suika" / "수박게임"을 쓰는 건 피하세요. 독자적인 제목이 필요합니다.
- Valve는 저품질 클론·에셋 플립에 대한 심사를 합니다. 스팀에는 이미 수박게임류가
  많아서, **차별화 요소 없이는 심사에서도 시장에서도 불리합니다.**

### 제품 완성도

지금은 "메커닉이 도는 프로토타입"입니다. 유료로 팔 수 있는 상태와의 갭:

| 항목 | 현재 | 필요 |
| --- | --- | --- |
| 아트 | 코드로 그린 원 | 실제 아트, 배경, 일관된 아트 디렉션 |
| 사운드 | 없음 | 병합 SFX, BGM, UI 사운드 |
| 이펙트 | 없음 | 병합 파티클, 화면 흔들림, 점수 팝업 |
| 메뉴 | 없음 | 타이틀, 설정(볼륨/창모드), 크레딧 |
| 모드 | 무한 1종 | 타임어택/챌린지 등 최소 2~3개 |
| 로컬라이즈 | 영어 UI | 최소 영/한, 가능하면 중/일 |
| 저장 | 최고점만 | 설정·통계·(스팀 클라우드) |

---

## 1. Steamworks 계정 만들기

1. [partner.steamgames.com](https://partner.steamgames.com) 에서 파트너 등록
2. 개인/법인 정보, **세금 정보** 제출
   - 한국 거주 개인은 보통 **W-8BEN** 작성 → 한미 조세조약으로 원천징수 경감
3. **은행 계좌** 등록 (수익 지급용)
4. **Steam Direct 수수료 $100 (앱 1개당)** 결제
   - 이 돈은 **환급됩니다.** 게임이 누적 조정총수익 $1,000을 넘기면 자동 크레딧
5. 결제 후 **30일 대기 기간**이 있습니다. 이 기간에는 출시할 수 없습니다

→ 완료되면 **App ID**가 나옵니다. 이후 모든 작업은 이 숫자를 씁니다.

## 2. 게임 빌드 준비 (Godot)

### 2-1. 익스포트 템플릿 설치

에디터 → **Editor → Manage Export Templates** → Download.
**에디터와 정확히 같은 버전**이어야 합니다 (4.4.1 에디터 = 4.4.1 템플릿).

### 2-2. 익스포트 프리셋 만들기

**Project → Export → Add...**

| 플랫폼 | 비고 |
| --- | --- |
| Windows Desktop | 스팀 매출의 대부분. `rcedit` 경로를 설정하면 exe 아이콘/버전정보가 박힙니다 |
| Linux | Steam Deck(Proton으로도 돌지만 네이티브가 더 안전) |
| macOS | **Apple Developer 계정($99/년) + 코드사인 + 공증**이 사실상 필수 |

명령줄로도 뽑을 수 있어 CI에 걸기 좋습니다:

```bash
godot --headless --path . --export-release "Windows Desktop" build/windows/suika.exe
godot --headless --path . --export-release "Linux"           build/linux/suika.x86_64
```

> 스팀 빌드는 **자동 업데이트가 스팀 쪽에서 되므로**, Godot 자체 업데이터는 필요 없습니다.

## 3. Steam 기능 붙이기 (업적 / 리더보드 / 클라우드)

스팀에 단순히 실행파일만 올려도 팔리긴 하지만, 업적·리더보드는 사실상 기대치입니다.
수박게임류는 **최고점 리더보드**가 특히 잘 맞습니다.

### 3-1. GodotSteam GDExtension

Godot 4는 [GodotSteam GDExtension](https://godotsteam.com/)을 쓰면 **엔진 재컴파일 없이**
붙습니다. (Godot Asset Store 또는 GitHub 릴리스에서 받아 `addons/`에 넣습니다.)

1. [Steamworks SDK](https://partner.steamgames.com/downloads/list) 다운로드
2. `steam_api64.dll` / `libsteam_api.so` / `libsteam_api.dylib` 를 빌드에 동봉
3. 개발 중에는 프로젝트 폴더에 `steam_appid.txt` 파일을 만들고 App ID만 한 줄 적어둡니다
   (스팀 클라이언트 없이 테스트하기 위한 것 — **출시 빌드에는 절대 포함하지 마세요**)

### 3-2. 초기화 + 리더보드 스케치

```gdscript
# autoload/steam_service.gd  (Project Settings → Autoload 에 등록)
extends Node

const APP_ID: int = 480  # 480 = Spacewar (테스트용). 실제 App ID로 교체
var enabled: bool = false

func _ready() -> void:
    if not ClassDB.class_exists("Steam"):
        return  # 스팀 없이도 게임은 돌아야 합니다
    var result: Dictionary = Steam.steamInitEx(APP_ID, true)
    enabled = result.get("status", -1) == 0
    if not enabled:
        push_warning("Steam init failed: %s" % result)
        return
    Steam.leaderboard_score_uploaded.connect(_on_score_uploaded)

func _process(_delta: float) -> void:
    if enabled:
        Steam.runCallbacks()

func submit_score(score: int) -> void:
    if not enabled:
        return
    Steam.findLeaderboard("HIGH_SCORE")  # Steamworks에서 미리 만들어 둔 이름
    await Steam.leaderboard_find_result
    Steam.uploadLeaderboardScore(score, true)

func unlock(achievement: String) -> void:
    if not enabled:
        return
    Steam.setAchievement(achievement)
    Steam.storeStats()

func _on_score_uploaded(success: bool, _score: int, _data: Dictionary) -> void:
    print("leaderboard upload: ", success)
```

그리고 `game.gd`의 `_end_game()`에서 `SteamService.submit_score(_score)` 한 줄.

> **중요:** 스팀 API가 없어도 게임이 멈추지 않게 짜야 합니다. 위 코드가 매 함수마다
> `enabled`를 확인하는 이유입니다. 에디터에서 F5로 돌릴 때도 그대로 돌아가야 합니다.

업적은 Steamworks 웹 대시보드에서 먼저 정의합니다. 이 게임이라면:
`FIRST_MERGE`, `MAKE_MELON`, `MAKE_WATERMELON`, `SCORE_3000`, `DOUBLE_WATERMELON` 정도.

## 4. 빌드 업로드 (SteamPipe)

Steamworks SDK 안의 `tools/ContentBuilder` 를 씁니다.

```
ContentBuilder/
├── content/            ← 여기에 익스포트한 빌드를 OS별로 넣습니다
│   ├── windows/
│   └── linux/
└── scripts/
    ├── app_build_1234567.vdf
    ├── depot_build_1234568.vdf   (windows)
    └── depot_build_1234569.vdf   (linux)
```

`app_build_1234567.vdf`:

```
"appbuild"
{
    "appid"       "1234567"
    "desc"        "0.1.0 first build"
    "buildoutput" "../output/"
    "contentroot" "../content/"
    "setlive"     ""            // 빈 값 = 자동 배포 안 함. 웹에서 수동 배포
    "depots"
    {
        "1234568" "depot_build_1234568.vdf"
        "1234569" "depot_build_1234569.vdf"
    }
}
```

업로드:

```bash
steamcmd +login <파트너계정> +run_app_build ../scripts/app_build_1234567.vdf +quit
```

이후 Steamworks 웹 → **SteamPipe → Builds** 에서 그 빌드를 `default` 브랜치에 배포합니다.
런치 옵션(어느 실행파일을 어느 OS에서 띄울지)은 **Installation → General** 에서 설정합니다.

패치도 똑같습니다: 새로 익스포트 → 업로드 → 배포. 스팀이 **차분(delta) 패치**를
자동으로 계산하므로 유저는 바뀐 부분만 받습니다.

## 5. 스토어 페이지

여기가 실제로 매출을 좌우합니다. 게임 만드는 시간만큼 쓰세요.

### 필수 그래픽 자산 (2024년 8월 상향된 현행 규격)

| 자산 | 크기 | 쓰이는 곳 |
| --- | --- | --- |
| Small Capsule | **462 × 174** | 검색 결과, 목록 |
| Header Capsule | **920 × 430** | 스토어 페이지 상단, 위시리스트 메일 |
| Main Capsule | **1232 × 706** | 프론트페이지 캐러셀, 세일 |
| Vertical Capsule | **748 × 896** | 프론트페이지 세로 배너 |
| Library Capsule | **600 × 900** | 구매자의 라이브러리 |
| Library Hero | **3840 × 1240** | 라이브러리 상세 배경 |
| Library Logo | 투명 PNG | 위 배경 위에 얹히는 로고 |
| Page Background | 1438 × 810 | 스토어 페이지 배경 |

JPG/PNG, 각 2MB 이하. **작은 캡슐에서도 제목이 읽히는지**가 가장 중요합니다 —
Small Capsule은 실제로 아주 작게 표시됩니다.

### 그 외

- **스크린샷 최소 5장** (1920×1080 권장). 로고·홍보문구를 얹지 말고 실제 플레이 화면으로
- **트레일러** 1개 이상. 첫 5초 안에 "합쳐진다"는 핵심이 보여야 합니다
- 짧은 설명 / 상세 설명 / 시스템 요구사항
- **Content Survey** (폭력·성적 콘텐츠 등 설문) — 필수
- 연령 등급: 유럽 PEGI, 독일 USK, 브라질 등 일부 지역은 등급 정보가 필요합니다
- 태그, 카테고리, 언어 목록
- **가격 설정** → 밸브 승인 필요. 지역별 권장가가 자동 제시됩니다

> **한국 유통 관련:** 국내에 유통되는 게임물은 원칙적으로 게임물관리위원회
> 등급분류 대상입니다. 스팀 유통 게임에 대한 실제 적용 범위는 계속 논의·변경되어
> 왔으니, 상업 출시라면 출시 직전에 현행 기준을 직접 확인하는 걸 권합니다.

## 6. 출시까지의 시간표

```
Steamworks 가입 + $100 결제
        │
        ├─ 30일 의무 대기
        │
스토어 페이지 작성 → 밸브 검토 (보통 수 영업일)
        │
"Coming Soon" 페이지 공개  ←── 여기서부터 위시리스트 수집 시작
        │
        ├─ 최소 2주 공개 유지 (밸브 규정)
        │
빌드 업로드 + 검토 → 출시일 확정 → 🚀 출시
```

**현실적으로 가입부터 출시까지 최소 4~6주**입니다. 그리고 위시리스트를 모으려면
"Coming Soon"을 2주보다 훨씬 길게(보통 2~6개월) 열어두는 게 일반적입니다.
출시일 첫날 순위가 위시리스트 수에 크게 좌우되기 때문입니다.

출시 버튼은 Steamworks의 **Release Checklist**가 전부 초록불이 되어야 눌립니다.

## 7. 출시 후

- **리뷰에 답글 달기** — 초반 리뷰 10개가 전환율을 크게 좌우합니다
- **패치**는 SteamPipe로 동일하게. 급하면 `beta` 브랜치로 먼저 테스트
- **Steam 세일** 참여 (여름/겨울/장르별 페스티벌). 페스티벌은 신청 마감이 있습니다
- **Next Fest** — 출시 전 데모를 내는 이벤트. 출시 전에 한 번만 참여 가능하니 타이밍을 아껴두세요

---

## 요약 체크리스트

- [ ] 원작 에셋·이름·상표 미사용 확인
- [ ] 아트/사운드/메뉴/모드까지 상품 수준으로 완성
- [ ] Steamworks 가입, 세금·은행 정보, $100 결제, 30일 대기
- [ ] Godot 익스포트 템플릿 설치 + Windows/Linux(/macOS) 프리셋
- [ ] GodotSteam으로 업적·리더보드·클라우드 연동 (스팀 없어도 돌아가게)
- [ ] SteamPipe로 빌드 업로드, 런치 옵션 설정
- [ ] 캡슐 8종 + 스크린샷 5장 + 트레일러
- [ ] Content Survey, 연령 등급, 가격, 태그
- [ ] Coming Soon 2주+ 공개 → Release Checklist 전부 통과 → 출시
