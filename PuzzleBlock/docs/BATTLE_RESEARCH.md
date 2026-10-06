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
