# 퍼즐 + 전투 게임 조사와 대전 아이디어 (2026-10-06)

블록 기사단(8×8 퍼즐 + 실시간 냥코식 레인 전투)을 만든 뒤 "비슷한 게임은 뭐가 있고, 대전은 어떻게 재밌게 만들 수 있나"를 조사했습니다. 아직 정해진 것은 없고, 고를 거리입니다.

## 한 줄 결론

- **8×8 블록퍼즐 + 실시간 횡스크롤 소환을 같이 하는 유명 게임은 없습니다.** 가장 가까운 것은 Puzzle TD: Pixel Battle(퍼즐로 골드 → 소환, 실시간)과 Block Battler(8×8, 턴제 RPG) 정도이고, 둘 다 작은 게임입니다. 빈자리라 차별점이 될 수 있습니다.
- 다만 "줄 = 공격"만 있는 작은 블록 RPG들은 대부분 조용히 사라졌습니다. **성장(판 사이 강화)과 다양성(병종 상성·보스 기믹)**이 있어야 오래 갑니다.
- 대전은 **내 퍼즐판을 건드리지 않고**, 공격은 위쪽 전장에서만 부딪히게 하는 방식이 우리 게임과 사용자 취향에 맞습니다. 접속자가 적으니 상대는 **다른 사람의 기록(고스트)**이 현실적입니다.

## 1. 비슷한 게임

| 게임 | 퍼즐이 전투에 주는 것 | 진행 | 핵심 재미·반응 |
|---|---|---|---|
| Puzzle TD: Pixel Battle | 퍼즐로 골드 → 유닛 소환, 적 기지 파괴 | 실시간 | 우리와 구조가 가장 비슷. 중간 업그레이드 카드("골드 즉시", "콤보 시간 +1초") |
| Block Battler: Puzzle RPG | 8×8에 블록, 줄 지우면 공격, 배수 블록 | 턴제 | "시간 압박 없음"을 내세움, 레벨업 때 스킬 고르기(로그라이트), 평점 4.4 |
| Block Battle: Blast Puzzle RPG | 블록 색마다 영웅 4명, 지운 색이 그 영웅 충전 | 실시간 PvP 있음 | 색 = 병종 |
| Battledoku, Block Deck 등 | 줄 = 공격, 던전 | 턴제 | 다운로드 수천에서 사라짐 → 줄 = 공격만으로는 부족 |
| 10000000 / You Must Build A Boat | 위는 캐릭터가 자동으로 달리고 아래는 퍼즐 | 실시간 | 위험을 **위치**(화면 밖으로 밀려남)로 보여 줌, 판 사이 업그레이드 |
| 퍼즐앤드래곤 | 콤보만큼 같은 색 몬스터가 공격 | 턴제 | 수집·가챠, 매출 10억 달러 첫 모바일 게임 |
| Empires & Puzzles | 지운 타일이 그 열의 적에게 날아감, 같은 색 영웅 마나 | 턴제 | 지운 타일이 위로 날아가는 연출로 위아래를 이음 |
| Puzzle Quest, Gems of War, Hero Emblems | 보석 색 = 마나·공격·방어 | 턴제 | 장르의 원조. Hero Emblems는 "운에 좌우" 불만 |
| Legend of Solgard | 유닛 자체를 맞춤(세로 = 공격, 가로 = 벽) | 턴제 | 깊이 있다는 평, 2020년 종료 |
| Dungeon Raid | 칼·해골·방패·물약 잇기 | 턴제 | 층마다 업그레이드 고르기 |
| Puyo Puyo / Tetris 99 / 퍼즐파이터 | 상대 판에 방해 블록 | 실시간 | 대전 퍼즐의 대표. 아래 2장 참고 |
| 냥코대전쟁 | (퍼즐 없음) 시간으로 돈, 일꾼 레벨, 소환 쿨다운, 충전식 대포 | 실시간 | 싸고 많은 벽 + 비싼 딜러, "저축할까 쓸까" 결정. 1억 2천만 다운로드 |
| 운빨존많겜 | (퍼즐 없음) 무작위 소환 + 합성 | 실시간 | 운 + 성장, 두 달 매출 1,100만 달러 이상 |

### 블록 기사단에 쓸 만한 교훈

1. **퍼즐 실력이 배수로 보상되게**: 2~3줄 동시, 콤보를 이으면 골드가 확 늘거나 무료 소환·"돌격" 같은 특별 효과.
2. **한 번에 한 곳만 보게**: 병사는 자동, 성이 위험하면 화면 테두리 경고처럼 크게. 골드가 차면 버튼이 반짝임. 지운 줄에서 금화가 골드 표시로 **날아가는 연출**로 퍼즐과 전투를 이음.
3. **병종 상성**: 기사(싸고 빠른 벽) / 궁수(사거리) / 마법사(광역) / 창병(대형 특효). 몬스터도 빠름·방어·원거리·대형으로 나눠 맞는 병사가 필요하게.
4. **보스가 퍼즐에도 느껴지게**: 보스가 판에 방해 블록을 떨어뜨리고 그 줄을 지우면 막아 냄(단, 판 방해는 사용자가 싫어했던 방향이라 보스 한정·약하게만).
5. **판 사이 성장**: 병사 강화, 스테이지 사이 카드 3장 중 1장, 일꾼(금화 속도) 강화, 충전식 대포.
6. **색 = 병종(선택지)**: 지운 블록 색이 해당 병사를 충전 → "어디에 놓을까"가 "누구를 키울까"가 됨. 규칙이 커지므로 신중히.

## 2. 대전을 재밌게 만드는 방법

### 잘 된 대전 퍼즐의 핵심

- **뿌요뿌요의 상쇄**: 날아오는 방해를 내 연쇄로 지우고 남는 만큼 되돌림 → "막고 되받아치는" 재미.
- **퍼즐파이터**: 보낼 방해 모양이 미리 정해져 있어 예측·역이용 가능, 역전이 잦음.
- **테트리스 99**: 쓰러뜨리면 배지로 공격력 최대 2배, 인원이 줄수록 빨라지고 음악이 고조.
- **방해를 싫어하는 이유**: "판을 밀어 올려 죽이기만 하고 할 수 있는 게 없다", "몰매 맞으면 끝" → 사용자가 느낀 "내 퍼즐을 망친다"와 같음.
- **서로 건드리지 않는 대결**: Skillz 블록퍼즐은 1:1에서 **같은 블록을 같은 순서로** 받고 점수로 겨룸. 동시에 할 필요 없이 앞사람 조건을 저장해 두었다가 다음 사람이 같은 조건으로 함. 단 "봇인데 속인다"는 불만이 많음 → 기록 상대면 **솔직히 표시**.
- **리그**: 듀오링고는 20~30명 한 그룹, 1주일 순위, 승급·강등(레슨 완료율 +25%로 분석). 로열매치 Royal League도 20명이 각자 편한 시간에.
- **랜덤다이스 PvP**: 판은 각자, 몬스터를 잡으면 게이지가 차고 차면 상대 쪽에 몬스터·보스를 보냄. 상대 칸은 건드리지 않음.
- **적은 접속자**: 모바일은 "실시간처럼 보이지만 상대는 기록이나 봇"이 흔함. 서로 기다려야 하는 비동기는 오래 못 감.

### 우리 게임에 맞는 대전 아이디어

공통 기반: 판마다 시드(블록 순서)를 정하고 `시드 + 시간별 소환 기록 + 지운 줄`을 서버에 저장. 같은 시드로 다른 사람이 하면 그 기록이 상대가 됨. 기록이 없으면 지금 AI가 대신.

| 안 | 방법 | 재미 | 위험 | 작업 |
|---|---|---|---|---|
| ① **기록 대전 레인** (추천) | 지금 블록 기사단 그대로, 적 요새 쪽 소환을 AI 대신 **같은 시드로 한 다른 사람의 기록**(그 사람이 몇 초에 무엇을 뽑았는지)으로 재생 | 괜찮다고 한 모드가 그대로 사람 상대 대전이 됨. 공격은 전장에서만 부딪히고 퍼즐판은 안 건드림. 내 병사가 상대 병사를 막는 게 뿌요의 상쇄 역할 | 서버에 기록 저장·불러오기 필요. 처음엔 기록이 적어 AI 비중이 큼 | 중 |
| ② 고스트 점수 레이스 | 같은 블록 순서로 정해진 수만큼, 위쪽에 상대 점수 막대·작은 미니판 | 완전히 공정, 생각할 시간 그대로, 끝나고 같은 블록을 어디 뒀는지 비교 | 혼자 하는 것과 비슷하게 느낄 수 있음 | 중 |
| ③ 주간 리그 | 20~30명 그룹, 그 주 최고 기록으로 순위, 승급·강등, 사람이 모자라면 봇(표시) | 지금 리더보드 서버를 거의 그대로 씀, 오래 붙잡는 힘 | 직접 겨루는 느낌은 약함 → ①②와 같이 | 소 |
| ④ 고스트 서바이벌 20인 | 같은 시드 기록 19개와 시작, 일정 시간마다 꼴찌 탈락 | 테트리스 99의 긴장감을 방해 없이 | 초반 탈락이 반복되면 실망 → 쉬운 기록과 먼저 매칭 | 중 |
| ⑤ 협동 보스전 | 기록·봇 동료와 같이 줄을 지워 보스 체력 깎기 | 지는 스트레스 없음 | "대전"과는 거리 | 중~대 |

조사한 에이전트는 ①을 "수마다 진행"으로 되돌려야 기록 재생이 정확하다고 제안했지만, 실시간 그대로도 **"몇 초에 무엇을 소환했는지"**를 기록해 같은 시각에 재생하면 됩니다. 실시간을 유지합니다.

### 지킬 원칙

- 퍼즐판은 상대가 절대 건드리지 않음
- 생각할 시간을 억지로 빼앗지 않음
- 상대가 기록이면 그렇다고 표시
- 한 판 3~5분
- 앱인토스: 진입 즉시 팝업 금지, 닉네임은 리더보드 이름 재사용

## 출처

- Block Battler https://play.google.com/store/apps/details?id=com.tn.blockbattler
- Block Battle https://play.google.com/store/apps/details?id=com.ep.blockbattle
- Battledoku https://www.appbrain.com/app/battledoku-block-puzzle-rpg/com.malina.battledoku.puzzle.rpg
- Puzzle TD: Pixel Battle https://play.google.com/store/apps/details?id=com.DefaultCompany.PixelSort
- 10000000 https://en.wikipedia.org/wiki/10000000_(video_game) · YMBAB 개발 https://www.gamedeveloper.com/business/designing-i-you-must-build-a-boat-i-amid-the-rising-tide-of-game-releases
- 퍼즐앤드래곤 https://en.wikipedia.org/wiki/Puzzle_%26_Dragons
- Empires & Puzzles https://sensortower.com/blog/empires-and-puzzles-revenue-500-million · https://empiresandpuzzles.fandom.com/wiki/Battle
- Legend of Solgard https://toucharcade.com/2018/08/16/legend-of-solgard-review/ · Hero Emblems https://toucharcade.com/2015/01/14/hero-emblems-review/
- 냥코 대포 https://battlecats.miraheze.org/wiki/Cat_Cannon · 1억 2천만 https://www.animenewsnetwork.com/press-release/2026-10-06/the-battle-cats-celebrates-120-million-downloads/.242493
- 팔라독 https://www.gamezebo.com/reviews/paladog-review/
- 뿌요 상쇄 https://puyonexus.com/wiki/Offset_rule · 퍼즐파이터 https://www.sirlin.net/articles/balancing-puzzle-fighter
- 테트리스 99 https://harddrop.com/wiki/Tetris_99 · 방해 줄 비판 https://harddrop.com/forums/index.php?topic=7883
- Skillz Block Puzzle https://games.skillz.com/games/board/block-puzzle-cash-prizes-22797 · 매칭 https://support.skillz.com/hc/en-us/articles/211525983-How-does-Skillz-player-matching-work
- 듀오링고 리그 https://duolingo.deconstructoroffun.com/mechanics/leagues · Royal League https://oldcynic.com/royal-match-royal-league-guide-tips
- 운빨존많겜 https://www.gamigion.com/lucky/ · 랜덤다이스 PvP https://en.namu.wiki/w/%EB%9E%9C%EB%8D%A4%20%EB%8B%A4%EC%9D%B4%EC%8A%A4(Random%20Dice):%20PvP%20%EB%94%94%ED%8E%9C%EC%8A%A4
- 모바일 멀티플레이 방식 https://mobilefreetoplay.com/multiplayer-on-mobile-3-approaches/

---

# 위쪽 라인 전투를 재밌게 만드는 법 (2026-10-07 조사)

"퍼즐 말고 위쪽 팔라독 같은 전투가 재미가 하나도 없다"는 피드백으로, 라인 디펜스 게임(냥코 대전쟁, 팔라독, 카툰워즈, Age of War, 스틱 워, 그로우 캐슬, 식물 vs 좀비, 클래시 로얄)을 조사했습니다.

## 지금 재미없는 이유

1. **고를 게 없음**: 쿨다운·지갑 한도가 없어 "돈 모이면 제일 좋은 유닛"이 늘 정답.
2. **적이 똑같이 하나씩**: 6초마다 1마리, 긴장의 오르내림이 없음.
3. **손맛이 없음**: 넉백·타격 이펙트·소리가 없음.
4. **소환 말고 할 일이 없음**: 영웅·대포·명령이 없음.

## 게임별 핵심

| 게임 | 핵심 장치 |
|---|---|
| 냥코 대전쟁 | 지갑 한도 + 전투 중 일꾼 레벨업(수입·한도 증가) → 저축 vs 투자. 유닛별 쿨다운(벽 유닛은 싸고 짧게). 넉백 횟수(체력이 1/N 줄 때마다 튕김)로 전선이 밀고 당겨짐. 한 탭 냥코 대포(충전식). 적 성 체력이 떨어지면 보스가 충격파와 함께 등장. 적 속성(빨강·떠있음·검정)과 전용 유닛 |
| 팔라독 | 고기(소환)·마나(마법) 두 자원. 직접 움직이는 영웅의 오라 안 아군만 강해짐 → 영웅 위치가 전략. 적 성 체력 절반에 포효와 특수 웨이브 |
| 카툰워즈 | 성에서 화살 직접 조준. 마나 부스터(지금 마나 절반으로 최대치 증가). 불만: 화살·마법사만 올리면 되는 정답 조합, 긴 노가다 |
| Age of War | 경험치로 시대 진화(유닛·포탑 교체), 쿨다운 있는 화면 전체 필살기 |
| 스틱 워 | 공격·방어·수비대 버튼 3개로 전군 명령, 유닛 하나 직접 조종 |
| 그로우 캐슬 | 웨이브 사이 성장. "전투는 반복적이지만 성장 때문에 붙잡힘", "중후반 노가다" |
| 식물 vs 좀비 | 카드 쿨다운 3단계(7.5/30/50초), 중간·끝 깃발 대웨이브. 해바라기(투자) 값을 내려 저축 고민을 살림 |
| 클래시 로얄 | 엘릭서 최대 10(넘치면 샘, 낭비 표시), 막판 생산 2~3배 |
| 손맛(GDC "Juice it or Lose it") | 같은 규칙에 번쩍임·흔들림·숫자·소리·파티클만 더해도 체감이 크게 바뀜. 강타에 40~80ms 멈춤(히트스톱) |

## 우리 전투에 넣을 변경 (재미 대비 수고 순)

| # | 변경 | 근거 | 수고 |
|---|---|---|---|
| 1 | 손맛: 피격 번쩍, 죽을 때 튕겨 날아감, 성 피격·보스 등장 흔들림, 강타 50ms 멈춤, 전투 소리 3~4종(작게) | Juice 강연 | 소 |
| 2 | 넉백: 유닛마다 넉백 1~3회, 체력이 그만큼 줄 때마다 뒤로 튕김 | 냥코 | 소 |
| 3 | 유닛별 쿨다운(기사 2초·궁수 4·마법사 8·창병 12) + 버튼에 원형 표시 | PvZ, 냥코 | 소 |
| 4 | 정해진 웨이브(조용함 → 소규모 → 경고 배너 → 대웨이브), 적 요새 체력 50%에 보스 + 충격파 | 팔라독, 냥코, PvZ | 중 |
| 5 | 원탭 대포: 게이지는 **줄 지우기·콤보**로 참, 가득 차면 탭해 적 전체 넉백·피해 | 냥코 대포, Age of War | 소~중 |
| 6 | 지갑 한도 + "수입 UP" 버튼(비용 점점 오름) | 냥코 일꾼, 클래시 로얄 | 소 |
| 7 | 상성 필요한 적 2~3종(박쥐 = 원거리만, 갑옷 해골 = 창병 2배, 슬라임 떼 = 마법사 광역) | 냥코 속성 | 중 |
| 8 | 돌격/수비 토글 1개 | 스틱 워 | 소~중 |
| 9 | 깃발 오라: 전장 탭한 곳 주변 아군 강화(쿨다운) | 팔라독 영웅 | 중 |
| 10 | 스테이지 별 3개 + 스테이지 사이 유닛 강화·해금 | 팔라독, 그로우 캐슬 | 대 |
| 11 | (선택) 길게 눌러 자동 소환 예약 | — | 소 |

## 핵심 흐름 제안

퍼즐에서 줄을 지우면 금화와 대포 게이지가 오르고(콤보일수록 많이), 금화로 벽(기사)과 딜러를 쿨다운에 맞춰 섞어 뽑거나 수입을 올려 대웨이브에 대비합니다. 경고 배너가 뜨면 대웨이브·보스가 오고, 모아 둔 대포 한 방과 돌격으로 고비를 넘깁니다. 성을 부수면 다음 스테이지에서 새 적 속성이 나와 다른 조합을 요구합니다.

## 위험

- 버튼이 늘면 퍼즐에서 눈을 떼야 함 → 전투 조작은 "소환 4 + 대포 1 + 토글 1"까지, 대웨이브 전 경고 필수
- 웨이브·속성은 2~3스테이지만 손으로 만들어 재미 확인 후 확장
- 강화가 세면 노가다 게임이 됨(냥코·카툰워즈·그로우 캐슬 불만)
- 전투 소리·흔들림이 퍼즐 효과와 겹치지 않게 작게, 큰 사건에만

## 출처

- 냥코 일꾼 https://battlecats.miraheze.org/wiki/Worker_Cat · 탱크냥 https://battle-cats.fandom.com/wiki/Tank_Cat_(Normal_Cat) · 넉백 https://thanksfeanor.pythonanywhere.com/guides/documents/terminology.html · 적 유닛·보스 https://battlecats.miraheze.org/wiki/Enemy_Units · 속성 https://battle-cats.fandom.com/wiki/Red_Alert · 대포 https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/TheBattleCats
- 팔라독 https://ayumilove.net/paladog-walkthrough-guide/ · https://en.namu.wiki/w/%ED%8C%94%EB%9D%BC%EB%8F%85
- 카툰워즈 https://en.namu.wiki/w/%EC%B9%B4%ED%88%B0%EC%9B%8C%EC%A6%88
- Age of War https://ageofwar.pro/ · 스틱 워 https://www.pocketgamer.com/stick-war-legacy/beginners-guide/ · 그로우 캐슬 https://minireview.io/tower-defense/grow-castle-tower-defense
- PvZ 쿨다운 https://plantsvszombies.wiki.gg/wiki/Recharge · https://en.wikipedia.org/wiki/Plants_vs._Zombies_(video_game)
- 클래시 로얄 엘릭서 https://clashroyale.fandom.com/wiki/Elixir
- 손맛 https://eastondev.com/blog/en/posts/dev/20260521-game-feedback-feel/ · 냥코 리뷰 https://reviewsbysupersven.com/the-battle-cats/
