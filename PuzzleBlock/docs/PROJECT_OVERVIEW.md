# 퍼즐블록 (PuzzleBlock) — 프로젝트 개요

> 코드 구조와 시스템을 정리한 문서입니다. 이 게임은 저장소의 `PuzzleBlock/` 폴더에 있고, 저장소 공통 지침은 루트의 `CLAUDE.md`에 있습니다. 게임 기획은 [GAME_DESIGN.md](GAME_DESIGN.md), 작업 목록은 [TASKS.md](TASKS.md), 어드벤처 사양은 [ADVENTURE_MODE.md](ADVENTURE_MODE.md), 점수 검증은 [SCORING_RULES.md](SCORING_RULES.md)를 참고하세요.

## 1. 한눈에 보기

| 항목 | 내용 |
|---|---|
| 장르 | 8×8 블록 퍼즐 (구글 플레이 *Block Blast!* `com.block.juggle` 참고) |
| 엔진 | Godot 4.7 (GDScript), 렌더러 `GL Compatibility` |
| 해상도 | 720×1280 세로 고정, `canvas_items` 스트레치 + `keep` 비율 |
| 모드 | 클래식(무한), 오늘의 챌린지(날짜 시드), 어드벤처(스테이지 20개) |
| 주 배포 대상 | Web (HTML5/WASM, 스레드 미사용) |
| 백엔드 | Node.js + Express 라우터 (JSON 파일 DB): 랭킹, 프로필, 이벤트 로그, 점수 재연산 검증 |
| 배포처 | 사내 112 서버 `http://192.168.219.112/block-game/` (`/block-blast/` 심볼릭 링크) |
| 코드 규모 | GDScript 약 4,300줄 + 테스트 850줄, Python 도구 1,400줄, JS 서버 770줄 |

## 2. 디렉터리 구조

```
PuzzleBlock/                 # 저장소 루트의 게임 폴더. 모든 명령은 이 폴더에서 실행
├── project.godot            # 엔진 설정, Autoload 5개
├── export_presets.cfg       # Web 내보내기 프리셋 → build/web/ (tests/, tools/ 제외)
├── run_game.bat             # 로컬 Godot 에디터로 프로젝트 실행
├── scenes/                  # main, board, block_piece, 이펙트, 모달 씬
├── scripts/                 # 게임 스크립트 (3장)
├── tests/                   # 헤드리스 테스트 씬 (8장)
├── assets/
│   ├── sprites/             # 클래식 블록 8색, 슬롯/고스트, UI 아이콘
│   │   └── skins/           # candy / neon / jewel 스킨
│   ├── avatars/             # 프로필 아바타 8종 (블록 캐릭터, tools/generate_avatars.py)
│   ├── art/                 # 게임 화면 테마 배경 7종 (Gemini 생성, 손실 압축으로 가져옴)
│   ├── sfx/                 # 효과음 WAV
│   └── fonts/font.ttf       # 한글 폰트
├── tools/                   # 서버 코드, 규칙 내보내기, 에셋 생성, 배포, 로그 분석
├── docs/                    # 기획·사양 문서
└── build/web/               # Web 내보내기 결과물 (커밋되어 있음)
```

## 3. 아키텍처

### 3.1 씬 구성 (`main.tscn`)

```
MainGame (Control, main.gd)
├── Background, Camera2D (화면 흔들림), ComboAura
├── BoardBackground, Board (board.tscn)
├── TrayPlates (트레이 받침 3개)
├── [런타임] BlockPiece × 3
└── UI
    ├── Header (홈/설정/랭킹/사운드, SCORE, BEST 또는 어드벤처 목표)
    ├── ComboBanner
    ├── GameOverModal (어드벤처 결과 창으로 재사용)
    ├── LeaderboardModal, SettingsModal, ProfileSetupModal, ReviveModal
    └── [런타임] HomeScreen(홈), AdventureSelect, 업적 알림
```

화면 전환은 씬을 바꾸지 않고 오버레이의 `visible`을 토글합니다.

UI 문구 규칙: 메뉴와 버튼은 한국어만 씁니다(영어 병기 없음). 점수·플레이 연출 용어(SCORE, BEST, COMBO, FEVER, 영어 칭찬 문구, GAME OVER, STAGE 결과)는 게임 관례대로 영어를 씁니다. 폰트(맑은 고딕 Bold)에 없는 기호(✕, ⚡ 등)는 쓰지 않고 아이콘으로 그립니다.

### 3.2 Autoload

| 이름 | 스크립트 | 역할 |
|---|---|---|
| `SoundManager` | `sound_manager.gd` | 12채널 효과음 풀, 줄 수별 화음, 콤보 음정 상승 |
| `LeaderboardManager` | `leaderboard_manager.gd` | 프로필(ID·닉네임·아바타), 랭킹/점수 API 통신 |
| `Analytics` | `analytics_manager.gd` | 플레이 이벤트를 모아 `/events`로 전송 |
| `Achievements` | `achievement_manager.gd` | 누적 통계와 업적 17개 |

`SettingsManager`, `BlockData`, `BlockSkins`, `AdventureData`는 정적 클래스입니다.

### 3.3 스크립트 역할

| 스크립트 | 역할 |
|---|---|
| `main.gd` (`MainGame`) | 입력, 트레이 지급, 점수·콤보, 게임오버·부활, 세 가지 모드 흐름, 배치 기록(replay log), 업적 알림 |
| `board.gd` (`Board`) | 8×8 상태, 배치 판정, 고스트·줄 예고, 줄 클리어 연출, 부활 폭탄, 어드벤처 시작 보드·보석, 생성기용 보드 분석 |
| `block_data.gd` (`BlockData`) | 블록 32종, 적응형 생성기, 순차 배치 검증기, 챌린지용 시드 생성기 |
| `block_piece.gd` (`BlockPiece`) | 조각 표시, 트레이 축소, 드래그(손가락 위 110px) |
| `block_skins.gd` (`BlockSkins`) | 스킨별 블록 텍스처 조회·캐시 |
| `adventure_data.gd` (`AdventureData`) | 스테이지 정의, 목표 문구, 별 계산, 진행 저장 |
| `home_screen.gd` (`HomeScreen`) | 홈 화면 (코드로 UI 구성): 프로필, 로고, 최고 점수, 게임 시작, 모드 카드, 랭킹 |
| `ui_kit.gd` (`UIKit`) | 공통 색·버튼(주요/보조/고스트/위험)·팝업 카드 스타일. 모든 화면이 이 모듈로 스타일을 맞춤 |
| `adventure_select.gd` | 스테이지 선택 화면 (코드로 UI 구성) |
| `settings_manager.gd` | 사운드·흔들림·가이드라인·진동·스킨 설정 저장, 진동 호출 |
| `leaderboard_modal.gd` | 전체/주간/오늘 탭, 내 순위, 끌어서 스크롤 (닉네임은 설정의 프로필 탭에서만 변경) |
| `settings_modal.gd` | 게임/프로필/업적 탭: 옵션 토글·스킨, 프로필 편집·초기화, 업적 목록 |
| `drag_scroll.gd` (`DragScroll`) | 버튼이 가득한 스크롤 영역을 끌어서 스크롤. 일정 거리 이상 끌면 눌린 버튼을 취소해 클릭으로 처리되지 않음 |
| `profile_setup_modal.gd`, `revive_modal.gd` | 첫 실행 프로필 설정, 5초 부활 팝업 |
| `combo_popup.gd` (`ComboPopup`) | 줄을 지울 때 뜨는 칭찬 문구·`Combo N`·점수. `assets/sprites/combo/`의 글자 그림을 조합하고 빛줄기·반짝이를 뒤에 깔아 차례로 튀어나옴 |
| `cell_blast.gd`, `floating_text.gd` | 단발성 이펙트. 지운 블록은 클리어 중심에서 바깥으로 회전하며 커지면서 날아감(줄 수·콤보가 클수록 멀리) |

### 3.4 로컬 저장 파일 (`user://`)

저장 폴더는 이름을 바꿔도 유지되도록 `project.godot`에서 옛 경로로 고정했습니다(`use_custom_user_dir`, `custom_user_dir_name="godot/app_userdata/블록 블라스트 (Block Blast)"`). Web은 `/userfs/<이 경로>`에 저장하므로, 이 값을 바꾸면 기존 플레이어의 프로필 ID·최고 점수·진행 기록이 모두 초기화됩니다.

| 파일 | 내용 |
|---|---|
| `block_blast_save.cfg` | 클래식 최고 점수, 오늘의 챌린지 최고 점수(`[daily]`) |
| `game_settings.json` | 사운드, 흔들림, 가이드라인, 진동, 스킨 |
| `player_profile.json` | `user_id`, 닉네임, 아바타, 마지막 순위 |
| `adventure_progress.json` | 해금된 스테이지, 스테이지별 별 |
| `achievements.json` | 누적 통계, 달성한 업적, 챌린지 참여일 |

## 4. 게임 흐름

```
앱 시작 → 홈 (최초 실행이면 프로필 설정)
  ├ [게임 시작]      클래식: 적응형 생성
  ├ [오늘의 챌린지]  날짜 시드 고정 순서
  └ [어드벤처]       스테이지 선택 → 시작 보드 로드
       └ start_new_game() → 트레이 지급 → 드래그·배치 → 줄 클리어·점수·콤보
            ├ 트레이가 비면 새 3개
            ├ 어드벤처: 목표 달성 → 클리어 / 이동 소진·막힘 → 실패
            └ 클래식·챌린지: 막힘 → 부활 1회 → 게임오버 → 점수 + 배치 기록 전송
```

- 점수 공식과 콤보 유예 규칙: [GAME_DESIGN.md](GAME_DESIGN.md) 9장, [SCORING_RULES.md](SCORING_RULES.md) 2장
- 블록 생성 알고리즘: [GAME_DESIGN.md](GAME_DESIGN.md) 10장. 지급 전에 `BlockData.can_place_all()`로 세 조각을 어떤 순서로든 모두 놓을 수 있는지 확인하고, 안 되면 다시 뽑습니다.

## 5. 서버 (`tools/server_block_leaderboard.js`)

112 서버의 기존 Node 앱에 마운트되는 Express 라우터입니다. 데이터는 `data/block_leaderboard.json`, 이벤트는 `data/events/YYYY-MM-DD.jsonl`에 저장하고, 쓰기는 Promise 큐로 직렬화합니다.

| 메서드 | 경로 | 설명 |
|---|---|---|
| GET | `/leaderboard?type=all\|weekly\|daily&limit=&user_id=` | 순위(최대 100), 내 순위 |
| POST | `/score` | 점수 등록. 배치 기록을 재연산해 검증. `mode=daily`는 일간 기록에만 반영 |
| POST | `/profile` | 닉네임·아바타 저장 |
| POST | `/nickname` | 닉네임만 변경 (구버전 호환) |
| POST | `/events` | 플레이 이벤트 일괄 저장 |

함께 배포할 파일: `tools/block_replay.js`, `tools/block_rules.json` ([SCORING_RULES.md](SCORING_RULES.md) 6장).

## 6. 빌드 · 배포

1. **로컬 실행**: `run_game.bat`
2. **Web 내보내기**: Godot `Web` 프리셋 → `build/web/index.html`
3. **웹 패치**: `python tools/patch_web.py` (비보안 컨텍스트 오디오, 페이지 제목, 전체화면 CSS)
4. **배포**: `python tools/deploy_112.py` (게임 파일 업로드, `block-blast` 링크, 허브 카드). 서버 라우터 파일은 이 스크립트가 올리지 않으므로 따로 반영합니다.

### 앱인토스 (토스 미니앱)

`Toss` 프리셋(기능 태그 `toss`) → `build/toss`를 `toss/` npm 프로젝트가 SDK 브리지와 함께 `toss/puzzleblock.ait`로 묶습니다. 자세한 절차와 토스 버전 차이는 [TOSS_RELEASE.md](TOSS_RELEASE.md)에 있습니다.

### Android (원스토어)

- 프리셋 `Android` → `build/android/puzzleblock.apk` (저장소에 올리지 않음). 패키지 `com.lmo0317.puzzleblock`, 이름 "퍼즐블록", 권한은 진동만 사용합니다.
- `offline` 기능 태그로 내보냅니다. 랭킹 서버가 아직 외부에 공개되지 않았기 때문에 랭킹 버튼·순위 표시를 숨기고 점수·이벤트를 보내지 않습니다(`LeaderboardManager.is_online()`).
- 안드로이드 뒤로가기: 열린 창 닫기 → 게임 중이면 홈 → 홈에서는 종료.
- 원스토어 등록 문구와 이미지는 `store/onestore/`(`listing.md`)에 있습니다. Godot이 가져오지 않도록 `store/.gdignore`를 둡니다.
- 필요한 도구: Android SDK(`%LOCALAPPDATA%\Android\Sdk`, build-tools 36.1.0), JDK 17, Godot Android 내보내기 템플릿.
- 릴리스 서명 키는 저장소 밖 `C:\Users\lmo03\.puzzleblock-keys\`에 있습니다. **잃어버리면 스토어에 업데이트를 올릴 수 없으니 반드시 따로 백업합니다.** 내보낼 때 환경 변수로 넘깁니다.

```bash
GODOT_ANDROID_KEYSTORE_RELEASE_PATH=<keystore> GODOT_ANDROID_KEYSTORE_RELEASE_USER=puzzleblock GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=<password> Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Android" build/android/puzzleblock.apk
```

## 7. 도구

| 도구 | 용도 |
|---|---|
| `capture_combo.tscn` | 줄 클리어 연출(작은 클리어·콤보 8·피버 콤보 12)을 0.1·0.3·0.7초 시점으로 캡처. 실행 방법은 `capture_screens`와 같음 |
| `capture_screens.tscn` | 주요 화면 12개를 PNG로 저장(UI 점검용). 창이 필요해 `--headless` 없이 `--resolution 720x1280`으로 실행, 저장 위치는 `CAPTURE_DIR` 환경 변수 |
| `export_rules.tscn` | 블록·점수 규칙과 엔진 검증 샘플을 `block_rules.json`으로 내보내기 |
| `block_replay.js` | 서버 점수 재연산, Godot RNG·해시 포팅 |
| `analyze_events.py` | 이벤트 로그에서 지표 계산 (`python tools/analyze_events.py <폴더>`) |
| `dev_server.js` | 테스트·로컬 확인용 서버 (랭킹 API + Web 빌드 제공) |
| `generate_original_blocks.py` | 클래식 블록 |
| `generate_skins.py` | 캔디·네온·보석 스킨 |
| `generate_avatars.py` | 프로필 아바타 8종(블록 색별 표정 캐릭터) |
| `generate_combo_text.py` | 콤보 연출 글자 그림: `Combo`, 금색 숫자, 점수 숫자, 칭찬 문구 5종, 빛줄기 (Arial Rounded MT Bold로 그림) |
| `generate_ui_assets.py` | 홈·설정·왕관·사운드·닫기·잠금 공통 UI 아이콘 |
| `generate_assets.py`, `generate_faceted_assets.py` | 효과음·초기 스프라이트·초기 블록 |
| `generate_sfx.py` | 줄 지우기·콤보·피버·퍼펙트 효과음 합성 (음정마다 파일, -6dBFS로 맞춰 겹쳐도 찢어지지 않게) |
| `generate_store_assets.py` | 로고(블록이 빈자리에 떨어지기 직전 모양)·앱 아이콘·안드로이드 적응형 아이콘, 원스토어 아이콘·그래픽 이미지·스크린샷(`store/onestore/`) |

## 8. 테스트

모두 헤드리스로 실행합니다. autoload가 필요하므로 `-s` 대신 씬 경로로 실행합니다. 로컬 저장 파일은 테스트 전에 백업하고 끝나면 복원합니다.

```bash
Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/test_solvability.tscn
```

| 테스트 | 확인 내용 | 로컬 서버 필요 |
|---|---|---|
| `test_solvability` | 보드 1,000개 이상에서 지급 세트가 항상 순차 배치 가능 | |
| `test_start_pattern` | 클래식 시작 보드 1,000개가 규칙을 지키고, 첫 세트가 항상 바로 줄을 지울 수 있음, 두 줄 구멍 보드에서 맞는 블록이 80% 이상 나옴, 같은 시드면 같은 보드 | |
| `test_daily` | 같은 날 같은 순서, 전역 난수 비간섭 | |
| `test_adventure` | 스테이지 데이터 검증, 봇이 20개 스테이지 모두 클리어 | |
| `test_skins` | 스킨 텍스처, 설정 저장, 보드·트레이 즉시 반영 | |
| `test_autoplay` | 실제 게임 자동 플레이, 이벤트 전송, 퍼펙트 클리어, 챌린지, 서버 재연산 통과 | ✅ |
| `test_magnet` | 자석 스냅: 미리보기가 0.9칸 안의 가장 가까운 빈자리에 붙음(보드 가장자리 밖에서 안으로, 먼 곳은 안 붙음), 들고 있는 블록은 손가락을 따라감, 놓으면 미리보기 자리에 배치·기록 | |
| `test_achievements` | 업적 해금·저장, 설정 탭 전환, 끌어서 스크롤 | |
| `test_offline` | 스토어 빌드 동작: 랭킹 UI 숨김, 점수·이벤트 미전송, 뒤로가기. `BLOCK_OFFLINE=1`로 실행 | |
| `bench_classic` | (측정 도구) 탐욕 봇 200판으로 클래식 판 길이·점수·콤보·긴장 구간, 처음 24수의 최대 콤보·콤보 끊김·퍼펙트 클리어 측정. `BENCH_NO_PRESSURE=1`이면 난이도 곡선 없이, `BENCH_EMPTY_START=1`이면 빈 보드로, `BENCH_NO_FUN=1`이면 초반 재미 세트 없이 측정 | |

로컬 서버가 필요한 테스트는 `tools/dev_server.js`를 띄우고(`npm install express` 후 `node tools/dev_server.js`) `BLOCK_API_HOST=http://127.0.0.1:3000`을 지정해 112 서버로 요청이 가지 않게 합니다.
