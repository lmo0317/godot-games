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
| 블록·칸·고스트·방해 돌 | Pillow 코드 | `tools/generate_original_blocks.py`, `tools/generate_faceted_assets.py` |
| 내비게이션·상태 아이콘 | Pillow 코드 | `tools/generate_ui_assets.py` |
| 아바타 | Pillow 코드 | `tools/generate_avatars.py` |
| 스킨 | Pillow 코드 | `tools/generate_skins.py` |
| 로고·스토어 이미지 | Pillow 코드 + 실제 캡처 | `tools/generate_store_assets.py`, `store/` |
| 테마 배경 | 기존 생성 이미지 유지 | `assets/art/` |
| 스토어 스크린샷 | 실제 게임 캡처 | `store/` |
| 콤보 연출 글자·빛줄기 | Pillow 코드 | `tools/generate_combo_text.py` |

## 생성 이미지 스타일 문구

```text
subtle dark navy mobile puzzle-game backdrop, low contrast, soft depth, empty center for gameplay, restrained lighting, no text, no letters, no watermark, no logos
```

## 사용자가 거절한 것

- 2026-09: 홍보 이미지처럼 화려하고 시선을 빼앗는 게임 배경. 배경은 플레이 영역보다 조용해야 함.

## 에셋 목록

| 이름 | 파일 | 방법 | 출처 | 쓰는 곳 | 상태 |
|---|---|---|---|---|---|
| 클래식 블록 8색 | `assets/sprites/block_*.png` | 코드 | `generate_original_blocks.py` | 보드·홈 로고 | 유지 |
| 방해 돌(회색 블록) | `assets/sprites/block_stone.png` | 코드 | `generate_original_blocks.py` `stone` | 대결 공격 | 완료 |
| 빈 칸·고스트 | `assets/sprites/cell_slot.png`, `cell_ghost.png` | 코드 | `generate_faceted_assets.py` | 보드 | 유지 |
| 홈·설정·사운드·왕관·닫기·잠금 | `assets/sprites/*_icon.png`, `sound_*.png` | 코드 | `generate_ui_assets.py` | 헤더·팝업·스테이지 | 완료 |
| 손가락(첫 판 안내) | `assets/sprites/tap_hand.png` (128px) | 코드 | `generate_ui_assets.py` `tap_hand()` | 첫 판 안내 | 완료 |
| 아바타 8종 | `assets/avatars/avatar_*.png` | 코드 | `generate_avatars.py` | 프로필·랭킹 | 유지 |
| 스킨 3종 | `assets/sprites/skins/` | 코드 | `generate_skins.py` | 보드·설정 | 유지 |
| 홈 로고 | `assets/sprites/logo.png` | 코드 | `generate_store_assets.py` | 홈 | 유지 |
| 콤보 연출 글자 | `assets/sprites/combo/combo_word.png`, `gold_0~9`, `score_0~9`, `score_plus`, `praise_1~5` | 코드 | `generate_combo_text.py` | 줄 클리어 팝업 | 완료 |
| 큰 점수 숫자 | `assets/sprites/combo/big_0~9.png`, `big_comma.png` | 코드 | `generate_combo_text.py` | 게임 화면 위 점수 | 완료 |
| 빛줄기 | `assets/sprites/combo/rays.png` | 코드 | `generate_combo_text.py` | 줄 클리어 팝업 뒤 | 완료 |
| 테마 배경 7종 | `assets/art/*.jpg` | 생성 이미지 | 기존 원본 | 게임 화면 | 유지 |
