class_name Defs
extends RefCounted
## Game data: map size, buildings, ranks, events and policy cards. No logic here.

const MAP := 32                 # full map is MAP x MAP; the playable square grows with the rank
const YEARS := 10               # one run
const WEEKS := 4                # sub-steps per month (growth runs weekly, money monthly)
const MONTH_SECONDS := 10.0     # real seconds per game month at 1x
const SPEEDS := [0.0, 1.0, 2.0, 4.0]
const START_MONEY := 3000

enum T { GRASS, WATER, FOREST }
enum Z { NONE, R, C, I }

const ROAD_COST := 10
const BRIDGE_COST := 40
const ZONE_COST := 5
const CLEAR_COST := 5           # extra when building on forest
const ROAD_UPKEEP := 0.25       # per road cell per month

const ZONE_NAMES := ["", "주거", "상업", "공업"]
const ZONE_COLORS := [Color(0, 0, 0, 0), Color(0.35, 0.85, 0.35), Color(0.35, 0.6, 1.0), Color(1.0, 0.8, 0.25)]
# people (R) or jobs (C, I) per building level 0..3
const CAP := [[0, 0, 0, 0], [0, 6, 16, 40], [0, 4, 10, 24], [0, 6, 14, 28]]
const LV_NEED := [0, 0, 35, 60]        # land value needed to reach a level
const BUILD_WEEKS := [0, 2, 3, 4]      # construction time per level

const SHOPS := ["bakery", "cafe", "restaurant", "clothes", "books", "flowers"]
const SHOP_NAMES := {"bakery": "빵집", "cafe": "카페", "restaurant": "식당", "clothes": "옷가게", "books": "서점", "flowers": "꽃집"}

# Object ids on a cell (obj array). 0 = nothing, 1 = road, 2.. = facilities below.
const ROAD := 1
const FAC := {
	2: {"key": "power", "name": "발전소", "cost": 400, "upkeep": 10, "radius": 6, "rank": 0, "desc": "둘레 가로세로 13칸 네모에 전기를 보내요"},
	3: {"key": "water_tower", "name": "급수탑", "cost": 300, "upkeep": 6, "radius": 5, "rank": 0, "desc": "둘레 가로세로 11칸 네모에 물을 보내요"},
	4: {"key": "park", "name": "공원", "cost": 80, "upkeep": 2, "radius": 2, "rank": 0, "desc": "주변 지가 +12, 행복 +"},
	5: {"key": "tree", "name": "나무", "cost": 10, "upkeep": 0, "radius": 1, "rank": 0, "desc": "주변 지가 +4"},
	6: {"key": "fountain", "name": "분수", "cost": 200, "upkeep": 3, "radius": 3, "rank": 1, "desc": "주변 지가 +10"},
	7: {"key": "police", "name": "경찰서", "cost": 350, "upkeep": 12, "radius": 6, "rank": 1, "desc": "치안: 지가 +6, 행복 +"},
	8: {"key": "fire", "name": "소방서", "cost": 350, "upkeep": 12, "radius": 6, "rank": 1, "desc": "화재를 막아요. 지가 +6"},
	9: {"key": "hospital", "name": "병원", "cost": 500, "upkeep": 18, "radius": 6, "rank": 2, "desc": "건강: 지가 +6, 행복 +"},
	10: {"key": "school", "name": "학교", "cost": 450, "upkeep": 15, "radius": 6, "rank": 2, "desc": "3단계 주거·공업에 필요"},
	11: {"key": "clock", "name": "시계탑", "cost": 1500, "upkeep": 10, "radius": 5, "rank": 2, "landmark": true, "desc": "명소: 관광 수입, 지가 +15"},
	12: {"key": "wheel", "name": "관람차", "cost": 2500, "upkeep": 15, "radius": 5, "rank": 3, "landmark": true, "desc": "명소: 관광 수입, 지가 +15"},
	13: {"key": "stadium", "name": "경기장", "cost": 4000, "upkeep": 20, "radius": 6, "rank": 4, "landmark": true, "desc": "명소: 관광 수입, 지가 +15"},
}
const FAC_ORDER := [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]
const SERVICE_BIT := {7: 1, 8: 2, 9: 4, 10: 8}   # police, fire, hospital, school

const KIND_NAMES := {
	"house": "주택", "rowhouse": "연립주택", "apartment": "아파트", "dept": "백화점",
	"workshop": "공방", "factory": "공장", "hightech": "첨단공장",
	"bakery": "빵집", "cafe": "카페", "restaurant": "식당", "clothes": "옷가게", "books": "서점", "flowers": "꽃집",
	"power": "발전소", "water_tower": "급수탑", "park": "공원", "tree": "나무", "fountain": "분수",
	"police": "경찰서", "fire": "소방서", "hospital": "병원", "school": "학교",
	"clock": "시계탑", "wheel": "관람차", "stadium": "경기장",
}

# Rank i needs these to be reached. size = playable square side.
const RANKS := [
	{"name": "마을", "size": 16},
	{"name": "읍", "size": 20, "pop": 150},
	{"name": "소도시", "size": 24, "pop": 500, "happy": 55},
	{"name": "도시", "size": 28, "pop": 1200, "happy": 60, "landmarks": 1},
	{"name": "대도시", "size": 32, "pop": 2200, "happy": 65, "landmarks": 2},
]

const TAX_NAMES := ["낮음", "보통", "높음"]
const TAX_RATE := [0.75, 1.0, 1.3]
const TAX_DEMAND := [0.1, 0.0, -0.15]

const EVENTS := [
	{"key": "festival", "name": "마을 축제", "months": 2, "text": "축제가 열렸어요! 2달 동안 상업 수입 +50%"},
	{"key": "tourists", "name": "관광객 붐", "months": 3, "text": "관광객이 몰려와요! 3달 동안 상업 수요 증가"},
	{"key": "boom", "name": "경기 호황", "months": 6, "text": "호황이에요! 6달 동안 세금 수입 +25%"},
	{"key": "recession", "name": "경기 불황", "months": 6, "text": "불황이에요. 6달 동안 세금 수입 -20%"},
	{"key": "movein", "name": "이사 행렬", "months": 3, "text": "이사 오려는 사람이 늘었어요! 3달 동안 주거 수요 증가"},
	{"key": "orders", "name": "주문 폭주", "months": 3, "text": "공장 주문이 밀려와요! 3달 동안 공업 수요 증가"},
	{"key": "grant", "name": "정부 보조금", "months": 0, "text": "정부 보조금 $%d을 받았어요!"},
	{"key": "fire", "name": "화재", "months": 0, "text": ""},
]

const POLICIES := [
	{"key": "green", "name": "녹색 도시", "text": "1년 동안 공원·나무의\n지가 효과 2배"},
	{"key": "taxcut", "name": "이사 장려금", "text": "1년 동안\n주거 수요 크게 증가"},
	{"key": "industry", "name": "산업 진흥", "text": "1년 동안\n공업 수요 크게 증가"},
	{"key": "tourism", "name": "관광 홍보", "text": "1년 동안 상업 수요 증가,\n명소 수입 2배"},
	{"key": "subsidy", "name": "건설 보조금", "text": "지금 바로\n$1500 받기"},
	{"key": "safety", "name": "안전 캠페인", "text": "1년 동안 화재 없음,\n행복 +5"},
	{"key": "education", "name": "교육 투자", "text": "1년 동안\n건물이 더 빨리 자람"},
]


static func fac(id: int) -> Dictionary:
	return FAC.get(id, {})


static func is_landmark(id: int) -> bool:
	return FAC.has(id) and FAC[id].get("landmark", false)


static func rank_size(rank: int) -> int:
	return RANKS[clampi(rank, 0, RANKS.size() - 1)]["size"]


static func kind_name(kind: String) -> String:
	return KIND_NAMES.get(kind, kind)
