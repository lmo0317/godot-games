# 아트 가이드 — 퍼즐블록

아트와 UI를 수정하기 전에 확인하는 기준입니다. 바뀌면 이 문서와 생성기를 함께 고칩니다.

## 스타일 한 줄

짙은 네이비 바탕 위에 선명한 각진 블록을 올린, 차분하고 또렷한 모바일 퍼즐 UI.

## 팔레트

| 이름 | hex | 쓰는 곳 |
|---|---|---|
| 배경 | `#0B0F19` | 전체 화면 |
| 표면 | `#131A2A` | 팝업·카드 |
| 높은 표면 | `#1C253B` | 목록 행·선택 전 컨트롤 |
| 테두리 | `#334566` | 카드·버튼 테두리 |
| 본문 | `#EDF2FC` | 제목·본문 |
| 보조 | `#99ABC7` | 설명·비활성 상태 |
| 파랑 | `#2E7AF5` | 주요 버튼·선택 상태 |
| 청록 | `#21D4ED` | 어드벤처·정보 강조 |
| 금색 | `#FCD14D` | 최고 점수·랭킹 |
| 보라 | `#BF85FC` | 오늘의 챌린지 |
| 위험 | `#ED5C5C` | 초기화·경고 |

## 규칙

- 화면 기준: 세로 720×1280. 터치 영역은 최소 48px, 주요 버튼은 56px 이상.
- 글자: 표시 60~68px, 팝업 제목 34~38px, 섹션 제목 20~24px, 본문 20px, 보조 18px, 캡션 16px. 실제 UI는 15px 미만을 사용하지 않음.
- 패널: 팝업 28px, 카드 20~24px, 행·작은 버튼 12~16px 반경. 2px 테두리와 짧은 아래쪽 깊이를 공통으로 사용.
- 블록: 74px 기준, 왼쪽 위 광원, 평평한 중앙 면과 4방향 베벨. 과한 광택과 그라디언트는 사용하지 않음.
- 아이콘: 투명 PNG, 64px 기준, 둥근 끝의 굵은 실루엣. 본문색·파랑·금색만 사용하고 문자 기호를 아이콘처럼 쓰지 않음.
- 아바타: 블록 팔레트와 같은 베벨 몸체, 진한 남색 얼굴선. 36px 랭킹 표시에서도 표정이 구분되어야 함.
- 글자: 그림 안에 넣지 않음. 예외는 줄 클리어 연출 글자(`Combo`, 숫자, 칭찬 문구)로, Block Blast처럼 글자마다 그라데이션·윗부분 광택·흰 안쪽 테두리·두꺼운 진한 바깥 테두리를 넣은 그림을 코드로 그림. 메뉴와 버튼은 한국어. 점수·플레이 연출의 `SCORE`, `BEST`, `COMBO`, `FEVER`, 칭찬 문구, `GAME OVER`, `STAGE` 결과는 영어 유지.
- 게임 안 그림은 차분하게 유지하고 플레이 영역보다 눈에 띄는 배경이나 홍보 이미지 같은 구성을 피함.

## 만드는 방법

| 종류 | 방법 | 위치 |
|---|---|---|
| 블록·칸·고스트 | Pillow 코드 | `tools/generate_original_blocks.py`, `tools/generate_faceted_assets.py` |
| 내비게이션·상태 아이콘 | Pillow 코드 | `tools/generate_ui_assets.py` |
| 아바타 | Pillow 코드 | `tools/generate_avatars.py` |
| 스킨 | Pillow 코드 | `tools/generate_skins.py` |
| 로고·스토어 이미지 | Pillow 코드 + 실제 캡처 | `tools/generate_store_assets.py`, `store/` |
| 테마 배경 | 기존 생성 이미지 유지 | `assets/art/` |
| 블록 기사단 캐릭터·성·전장 | Codex 픽셀 아트(캐릭터는 **한 장 시트**) → `tools/import_lane_art.py`로 도트 복원 | `assets/art/lane/` |
| 스토어 스크린샷 | 실제 게임 캡처 | `store/` |
| 콤보 연출 글자·빛줄기 | Pillow 코드 | `tools/generate_combo_text.py` |

## 생성 이미지 스타일 문구

```text
subtle dark navy mobile puzzle-game backdrop, low contrast, soft depth, empty center for gameplay, restrained lighting, no text, no letters, no watermark, no logos
```

## 블록 기사단 픽셀 아트 (Codex, 2026-10-06 승인)

여러 번 거절된 끝에 처음 통과한 방법입니다(공통 방법은 `art-director` 스킬 3b).

- **스타일**: 옆에서 본 레트로 16비트 도트, 약 2.5등신(큰 눈 꼬마 그림 아님), 1px 어두운 외곽선, 명암 2단계, 빛은 왼쪽 위.
- **한 장 시트**: 캐릭터 8종을 한 그림에 같이 그려 픽셀 크기·색·그림체를 맞춤. 아군은 오른쪽, 몬스터는 왼쪽을 봄.
- **도트 복원**: `python tools/import_lane_art.py <원본 폴더>` — 시트 하나에 블록 크기 하나로 줄이고 붙은 덩어리별로 자름.
- **게임 표시**: 처음엔 유닛·성 모두 2배였으나 2026-10-07부터 **1배**(아래 "크기"), 배경 3배, nearest.
- 생성: `bash ~/.claude/skills/art-director/scripts/codex_image.sh <폴더> <이름> "<주제> <스타일 문구>"`

스타일 문구(주제 뒤에 붙임, 배경은 첫 문장 대신 "Fully opaque"):

```text
TRANSPARENT background (PNG with alpha). Wide canvas. Retro 16-bit PIXEL ART like a classic side-scrolling defense game: every art pixel is a crisp perfectly square block of the same size (no anti-aliasing, no blur, no gradients), one shared limited palette, 1-pixel dark outline, simple 2-tone shading with light from the top-left, cute simple tiny proportions (about 2.5 heads tall, NOT big-eyed chibi), readable silhouettes. No text, no letters, no numbers, no watermark, no logo.
```

| 원본 | 주제 |
|---|---|
| `sheet.png` | a SPRITE SHEET of 8 tiny game characters standing in ONE horizontal row, evenly spaced with clear gaps, all the same height (each about 24x24 art pixels), all standing on the same baseline, full body side view. From left to right: 1 a knight with sword and round shield, 2 an archer with a bow, 3 a mage with a staff and pointed hat, 4 a spearman with a long spear — these four FACE RIGHT; then 5 a green slime, 6 a goblin with a wooden club, 7 a skeleton warrior with a rusty sword, 8 a big orc with an axe — these four FACE LEFT. |
| `bases.png` | two tiny pixel-art buildings side by side, same scale, same baseline, clear gap: LEFT a small friendly stone castle tower with a blue flag and a wooden door facing right; RIGHT a small dark spiky enemy fortress of purple-black stone with a red banner, door facing left. Each about 48x56 art pixels. |
| `foes.png` (2026-10-07, `-i sheet.png --`로 원래 시트를 참고 이미지로 넘김) | a SPRITE SHEET of 2 tiny game monsters standing in ONE horizontal row with a clear gap, drawn in EXACTLY the same style, pixel size, outline and palette as the attached reference sheet (each about 24x24 art pixels). 1 a purple bat flying with wings spread wide, small fangs, FACING LEFT; 2 an armored skeleton warrior wearing a dented iron helmet and holding a big iron shield and a short sword, FACING LEFT. |
| `fx.png` (2026-10-07, 같은 참고 방식, 2장 뽑아 작은 쪽 선택) | a SPRITE SHEET of 6 separate pixel-art game pieces in ONE horizontal row, each clearly separated by wide empty gaps, same style as the reference sheet: 1 a chunky black iron castle cannon on a small wooden carriage with two wheels, barrel pointing RIGHT (about 28x18 art pixels); 2 a round black cannonball with a short orange fire trail, flying RIGHT; 3 a muzzle flash burst pointing RIGHT; 4 a small explosion puff; 5 a big explosion; 6 a fading grey smoke cloud. |
| `allies2.png` (2026-10-07, 원래 시트 참고, 2장 중 A) | 8 tiny game hero characters in ONE row, ALL FACING RIGHT, same style as the reference sheet: shield bearer with a huge tower shield, crossbowman, cleric in white and gold robe with a glowing staff, cavalry knight on a horse, ice mage, cannoneer with a hand cannon, golden paladin, hero swordsman. 게임에는 방패병·석궁병·사제·대포병만 씀. **도트 크기를 6으로 강제**(`--block 6`, 자동 측정은 5로 나와 1.2배 크게 됨) |
| `foes2.png` (같은 날, 2장 중 A) | 5 tiny monsters in ONE row, ALL FACING LEFT, same style: grey wolf running, goblin archer, dark cultist priest with a skull staff, big stone golem with glowing cracks, demon lord boss with horns and a flaming sword |
| `fx2.png` (같은 날, 2장 중 B) | 10 small battle effects in ONE row, same style: hit spark, sword slash arc, arrow, crossbow bolt, fireball, holy orb, green heal plus, dust puff, gold coin(안 씀), white impact ring |
| `lane.png` | a WIDE side-view battle lane background (about 2:1): soft blue sky with a few chunky pixel clouds, distant layered hills, a tree line, and in the lower third a flat strip of grass with a dirt path running left to right. Calm and slightly muted so small characters stand out. No characters, no buildings. |

### 블록 기사단 UI (2026-10-07)

"UI 싹 다 갈아엎어" 요청으로 이 모드의 화면(본부·뽑기·덱·전투 아래 소환 줄·결과 창)을 평평한 남색 카드에서 **캐릭터 도트와 같은 그림체의 픽셀 판타지 UI**로 바꿈: 어두운 호두나무 판 + 금빛 테두리(큰 판), 양피지(설명), 초록·파랑·빨강 버튼(회색 = 못 누름), 돌 카드 테두리(병사 카드, 등급별 색 입힘: 일반 그대로 / 희귀 파랑 / 영웅 금색), 빨간 리본(제목), 동메달·해골 뿔 메달(스테이지·보스), 보석·금화·별·빈 별·자물쇠 아이콘. 배경은 전장 그림을 어둡게 깜.

- 키트 한 장(`ui.png`)을 Codex로 2장 뽑아 A 선택 → `tools/import_lane_ui.py`가 도트 크기 6으로 되돌리고 자리로 이름을 붙여 `assets/art/ui/`에 **2배로** 저장.
- 게임에서는 `LaneUI`(9-slice 여백은 `MARGINS`)로 씀. 글자는 게임 글꼴 + 진한 갈색 외곽선(양피지 위는 외곽선 없이 진한 갈색).

```text
Subject: a PIXEL-ART GAME UI KIT sheet for a cozy fantasy defense game, drawn in EXACTLY the same retro 16-bit pixel style, pixel size, outline and palette as the attached character reference sheet. All pieces laid out in a neat grid, each piece clearly separated from the others by wide empty transparent gaps, all flat front view. Pieces: 1 a large square PANEL: dark walnut wooden board with a thick golden brass rim and small rivets in the four corners (about 48x48 art pixels, plain center so it can be stretched); 2 a large square PARCHMENT panel ...; 3-6 GREEN / BLUE / RED-ORANGE / GREY wide BUTTONs ...; 7 GEM icon; 8 GOLD COIN icon; 9 filled GOLD STAR; 10 EMPTY STAR; 11 iron PADLOCK; 12 wide red cloth TITLE RIBBON ...; 13 round bronze STAGE MEDALLION ...; 14 round dark-red BOSS MEDALLION with a small skull and horns ...; 15 small square CARD FRAME: dark slate stone frame ... + 스타일 문구
```

### 병사 원화 스케치 (2026-10-07)

사용자 요청("각 캐릭터마다 아트 시안 원화 스케치 느낌으로")으로 병사 8종을 한 장씩 그렸습니다. 게임 도트 그림을 크게 키운 것을 `-i`로 넘겨 디자인을 맞췄습니다. 배경이 투명하거나 어둡게 나오면 다시 그림(기사·방패병 1번씩).

```text
Subject: a character CONCEPT ART SKETCH sheet for a game unit - <병사 설명>. Same character design as the attached pixel-art reference (same armor colors, gear and silhouette), redrawn as an artist's original concept drawing: loose pencil and graphite sketch lines with a light flat watercolor color wash, on plain OFF-WHITE PAPER (fully opaque light paper background, NOT transparent, NOT dark, NOT pixel art, no glow). Show the character three times: full body front view, full body side view facing right, and a small close-up of the weapon or gear. Stylized proportions about 3 heads tall (NOT big-eyed chibi), friendly fantasy look. No background scenery. No text, no letters, no labels, no watermark, no logo. Landscape canvas.
```

### 크기 (2026-10-07)

"성과 유닛이 너무 커서 많아지면 재미가 없다" → 냥코 대전쟁식으로 줄임: 병사·몬스터는 **원래 도트 크기(×1, 약 45px = 띠 높이의 1/7)**, 보스만 약 2배, 성·요새도 ×1로 **반쯤 화면 밖**에 두어 싸울 공간을 330 → 580px로 넓힘. 효과도 ×1.

### (보관) 블록 디펜스 도트 (코드로 그림, 2026-10-05) — 모드 삭제로 지금은 쓰지 않음

**스타일 한 줄**: 레트로 저해상도 도트(참고: Google Play "도트 기사단: 픽셀 디펜스 전쟁" 풍). 작은 캐릭터, 단순한 실루엣, 적은 디테일, 따뜻하고 살짝 차분한 색.

| 규칙 | 내용 |
|---|---|
| 방법 | 전부 Pillow 코드로 한 칸씩 그림: `tools/generate_defense_sprites.py` (생성 이미지 쓰지 않음) |
| 배율 | 모든 그림을 **같은 4배**로 그림(`DefenseMode.PIXEL_SCALE`, nearest). 픽셀 크기가 섞이면 안 됨 |
| 크기(원본 칸) | 궁수 20×24, 마법사 20×24, 고블린 20×22, 슬라임 16×13, 보스 32×36, 화살 3×10, 화염구 9×9, 타격 별 7×7, 성벽 180×40, 전장 180×297 |
| 방향 | 아군 뒷모습(위쪽 몬스터를 봄), 몬스터 앞모습 |
| 외곽선·빛 | 1칸 외곽선 `#2B1D2E`, 왼쪽 위에서 빛(왼쪽 한 칸 밝게, 오른쪽 한두 칸 어둡게) |
| 팔레트 | 생성기의 `P` 하나만 씀. 주요: 외곽 `#2B1D2E`, 피부 `#F1C39A`, 초록 `#8CD06A/#5CA84A/#347034`, 파랑 `#7FA8F0/#4A7BD8/#34539E`, 보라 `#9C6CD6/#7A4AB8/#52308A`, 가죽 `#8B5A3C`, 나무 `#D08A45`, 금 `#F2B23A`, 주황 `#FF8A3A`, 돌 `#C4C0BA/#A4A09A/#7C7874`, 풀 `#7EBE5C/#68AC4E/#569642`, 길 `#E2C48C/#D2B076` |

Codex가 "Selected model is at capacity" 오류로 실패하면 같은 명령을 다시 실행합니다(2026-10-05 슬라임·고블린).

## 사용자가 거절한 것

- 2026-10-05: Codex로 그린 디펜스 픽셀 아트 — 그림마다 픽셀 크기가 달랐고(성벽 3배, 캐릭터 1~1.6배), 디테일이 많은 큰 머리 꼬마 그림이라 "구리다". 정면 아군도 거절(아군은 뒷모습). 디펜스는 코드 도트로 바꿈.
- 2026-10-05: 성문과 겹치는 유닛 배치.
- 2026-10-07: 대포 효과를 그림 없이 노란 사각형으로 낸 것 — "대포 이미지가 완전 구리다". 눈에 띄는 연출은 임시 도형으로 내보내지 말고 처음부터 그림(Codex 시트)으로.
- 2026-10-06: 몬스터 배틀의 카툰 그림(큰 머리 꼬마)과 코드 도트 캐릭터 — 블록 기사단에서 Codex 한 장 시트 픽셀 아트로 교체.

- 2026-09: 홍보 이미지처럼 화려하고 시선을 빼앗는 게임 배경. 배경은 플레이 영역보다 조용해야 함.

## 에셋 목록

| 이름 | 파일 | 방법 | 출처 | 쓰는 곳 | 상태 |
|---|---|---|---|---|---|
| 클래식 블록 8색 | `assets/sprites/block_*.png` | 코드 | `generate_original_blocks.py` | 보드·홈 로고 | 유지 |
| 빈 칸·고스트 | `assets/sprites/cell_slot.png`, `cell_ghost.png` | 코드 | `generate_faceted_assets.py` | 보드 | 유지 |
| 홈·설정·사운드·왕관·닫기·잠금 | `assets/sprites/*_icon.png`, `sound_*.png` | 코드 | `generate_ui_assets.py` | 헤더·팝업·스테이지 | 완료 |
| 손가락(첫 판 안내) | `assets/sprites/tap_hand.png` (128px) | 코드 | `generate_ui_assets.py` `tap_hand()` | 첫 판 안내 | 완료 |
| 아바타 8종 | `assets/avatars/avatar_*.png` | 코드 | `generate_avatars.py` | 프로필·랭킹 | 유지 |
| 스킨 3종 | `assets/sprites/skins/` | 코드 | `generate_skins.py` | 보드·설정 | 유지 |
| 홈 로고 | `assets/sprites/logo.png` | 코드 | `generate_store_assets.py` | 홈 | 유지 |
| 콤보 연출 글자 | `assets/sprites/combo/combo_word.png`, `gold_0~9`, `score_0~9`, `score_plus`, `praise_1~5` | 코드 | `generate_combo_text.py` | 줄 클리어 팝업 | 완료 |
| 큰 점수 숫자 | `assets/sprites/combo/big_0~9.png`, `big_comma.png` | 코드 | `generate_combo_text.py` | 게임 화면 위 점수 | 완료 |
| 빛줄기 | `assets/sprites/combo/rays.png` | 코드 | `generate_combo_text.py` | 줄 클리어 팝업 뒤 | 완료 |
| 블록 기사단 병사 | `assets/art/lane/knight.png`, `archer.png`, `mage.png`, `spearman.png` | Codex 시트 | 위 `sheet.png` | 전장 유닛, 소환 버튼, 홈 카드(기사) | 완료 |
| 블록 기사단 몬스터 | `assets/art/lane/slime.png`, `goblin.png`, `skeleton.png`, `orc.png` | Codex 시트 | 위 `sheet.png` | 전장 유닛 | 완료 |
| 박쥐·갑옷 해골 | `assets/art/lane/bat.png` (66×29), `armored.png` (47×43) | Codex 시트(원래 시트 참고) | 위 `foes.png` | 전장 유닛(날아다님·갑옷) | 완료 |
| 성 대포·포탄·효과 | `assets/art/lane/cannon.png` (39×26), `cannonball.png`, `flash.png`, `boom_s.png`, `boom_l.png`, `smoke.png` | Codex 시트(원래 시트 참고) | 위 `fx.png` | 성 오른쪽 탑 위 대포, 대포 버튼 아이콘, 발사 연출(불꽃 → 포탄 → 연쇄 폭발 → 연기) | 완료 |
| 새 병사 4종 | `assets/art/lane/shield.png`, `crossbow.png`, `cleric.png`, `cannoneer.png` | Codex 시트 | 위 `allies2.png` | 전장, 소환 버튼, 뽑기·덱 화면 | 완료 |
| 새 몬스터 5종 | `assets/art/lane/wolf.png`, `gob_archer.png`, `priest.png`, `golem.png`, `demon.png` | Codex 시트 | 위 `foes2.png` | 전장(마왕은 24스테이지 보스) | 완료 |
| 전투 효과 | `assets/art/lane/spark.png`, `slash.png`, `arrow.png`, `bolt.png`, `fireball.png`, `holy.png`, `heal.png`, `dust.png`, `ring.png` | Codex 시트 | 위 `fx2.png` | 타격 불꽃·베기·투사체·회복·먼지·충격 고리 | 완료 |
| 병사 원화 스케치 8종 | `art/concept/units/*.jpg` | Codex (도트 그림을 참고로 연필·수채 원화) | 아래 "병사 원화" | 기획 참고용 (게임에 안 들어감) | 완료 |
| 블록 기사단 UI 키트 15종 | `assets/art/ui/panel_wood.png`, `panel_paper.png`, `btn_green/blue/red/grey.png`, `icon_gem/coin/star/star_empty/lock.png`, `ribbon.png`, `medal.png`, `medal_boss.png`, `card_frame.png` | Codex 시트 | 위 "블록 기사단 UI" | 본부·뽑기·덱·전투 소환 줄·결과 창 (`LaneUI`) | 완료 |
| 날개·방패 표시 | `LaneBattle._pixel_icon()` (7px) | 코드 | 문자열 도트 | 박쥐·갑옷 해골 머리 위 | 완료 |
| 내 성·적 요새 | `assets/art/lane/castle.png`, `fortress.png` | Codex | 위 `bases.png` | 전장 양 끝 | 완료 |
| 전장 배경 | `assets/art/lane/lane.png` (296×148) | Codex | 위 `lane.png` | 전장 | 완료 |
| 테마 배경 7종 | `assets/art/*.jpg` | 생성 이미지 | 기존 원본 | 게임 화면 | 유지 |
