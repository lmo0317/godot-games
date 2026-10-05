# 앱인토스 출시 가이드

퍼즐블록을 토스 미니앱(게임)으로 내보내고 검수받는 방법입니다. 조사 근거와 체크리스트는 앱인토스 개발자센터 문서(SDK 3.6.0 기준, 2026-09-30)입니다.

## 1. 구조

```
Godot "Toss" 프리셋 (기능 태그 toss) → build/toss/        웹 빌드
tools/patch_web.py build/toss                              오디오 패치, 백그라운드 소리 정지
toss/  (npm 프로젝트)
  src/bridge.js      앱인토스 SDK를 window.TossBridge로 노출 (esbuild로 번들)
  build.mjs          build/toss → dist/ 복사, ait-bridge.js 번들, index.html에 삽입
  apps-in-toss.config.ts   appName, 색, 투명 게임 바
  npm run build      → toss/puzzleblock.ait
scripts/toss.gd      게임 쪽 연결 (Toss.active() 등)
```

## 2. 빌드

```bash
Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Toss" build/toss/index.html
python tools/patch_web.py build/toss
cd toss && npm install && npm run build
```

결과물은 `toss/puzzleblock.ait`(압축 약 20MB, 해제 약 48MB, 한도 100MB)입니다. `@apps-in-toss/ait-format`이 Node 24 이상을 요구한다는 경고가 나오지만 Node 22에서도 빌드됩니다.

## 3. 토스 버전에서 달라지는 점

| 항목 | 동작 |
|---|---|
| 랭킹 | 우리 서버 대신 토스 게임 리더보드. 클래식 점수만 게임 오버 때 제출, 랭킹 버튼은 토스 리더보드 열기. 홈의 "클래식 랭킹 N위"는 숨김 |
| 첫 실행 | 닉네임 입력 창을 띄우지 않음(진입 즉시 팝업 금지). 토스 게임 프로필 닉네임이 있으면 그걸 씀 |
| 사용자 식별 | `getUserKeyForGame` 해시를 `toss_<hash>`로 저장 |
| 오른쪽 위 | 토스 게임 바(더보기·X)가 떠 있어서 우리 버튼을 왼쪽으로 옮김 |
| 뒤로가기 | 안드로이드 뒤로가기를 게임이 받음. 창 닫기 → 게임 중이면 홈 → 홈에서는 "게임을 종료할까요?" 확인 후 종료 |
| 진동 | 토스 햅틱(`generateHapticFeedback`) 사용. 아이폰에서도 동작 |
| 소리 | 앱이 백그라운드로 가면 즉시 정지, 돌아오면 재개(웹 공통) |
| `eval` | 게임 코드는 쓰지 않음. 엔진이 넣는 `JavaScriptBridge.eval`용 JS 함수(`_godot_js_eval`, 안에서 `eval()` 호출)도 `tools/patch_web.py`가 아무것도 실행하지 않는 함수로 바꾸고, `eval(`·`new Function`·`Function(`이 남아 있으면 빌드를 실패시킴 |

## 4. 콘솔에서 할 일 (직접)

1. [앱인토스 콘솔](https://apps-in-toss.toss.im) 워크스페이스 → 앱 등록
   - 앱 유형 **게임**, appName **`puzzleblock`** (다르게 정했다면 `toss/apps-in-toss.config.ts`도 같이 바꿔야 함, 등록 후 변경 불가)
   - 로고, 앱 이름 "퍼즐블록", 문의 이메일, 카테고리, 설명, 썸네일
   - **등급 정보: 원스토어 앱 링크**
   - **리더보드 설정**(점수 높은 순)
2. 앱 정보 검토 승인(영업일 1~2일). 승인 전에는 리더보드가 `LEADERBOARD_NOT_FOUND`
3. `toss/puzzleblock.ait` 업로드 → "테스트하기" QR을 토스 앱으로 스캔해 확인 (로그인, 워크스페이스 멤버, 만 19세 이상)
4. 테스트 1회 이상 후 "검토 요청하기"(영업일 최대 3일) → 승인 메일 → "출시하기"

## 5. QR 테스트 때 꼭 볼 것

- [ ] 첫 화면까지 10초 이내 (엔진 39MB. 넘으면 경량 엔진 빌드 필요)
- [ ] 오른쪽 위 더보기·X 버튼이 우리 버튼·BEST 칸과 겹치지 않음 (16:9 같은 낮은 화면에서 특히)
- [ ] X 버튼 → 토스 종료 확인이 뜸
- [ ] 안드로이드 뒤로가기: 게임 중 → 홈, 홈 → 종료 확인
- [ ] 홈 버튼·앱 전환 시 소리가 바로 멈추고 돌아오면 다시 남
- [ ] 게임 오버 후 "토스 랭킹에 기록했어요", 랭킹 버튼으로 리더보드 열림 (앱 정보 승인 후)
- [ ] 진동(햅틱) 동작, 설정에서 끄면 멈춤
- [ ] 앱을 완전히 닫았다 다시 열어도 최고 점수·어드벤처 진행이 남아 있음

## 6. 검토 반려 기록

| 날짜 | 반려 사유 | 원인 | 조치 |
|---|---|---|---|
| 2026-10-05 | "eval과 같이 외부에서 코드를 받아와 실행시킬 수 있는 코드는 보안상 허용되지 않아요" | Godot 웹 엔진 `index.js`의 `_godot_js_eval`(JavaScriptBridge.eval 구현)에 `eval()` 2곳. 게임은 쓰지 않지만 번들에 남아 있었음 | `patch_web.py`에서 함수 본문을 실행 없는 함수로 교체, 남은 `eval`/`Function` 검사 추가. 토스 번들(`index.js`, `ait-bridge.js`, worklet, `index.html`)에서 `eval`, `new Function`, 동적 `script`/`import` 없음 확인 |
