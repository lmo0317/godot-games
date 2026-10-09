"""Rough economy check for 블록 기사단 (docs/LANE_UNITS.md 재설계 2026-10-09).

Assumes a player clears each stage once, collects first-clear gems and merges where possible.
Merging now costs copies AND gems (MERGE_GEMS). We check that the player can still reach
"전설 1명 · 신화 2명 정도" with only first-clear rewards (approximate).

Not a battle simulator — just the resource flow.
"""

MERGE_COPIES = [1, 2, 3, 4, 5]
MERGE_GEMS   = [50, 150, 400, 800, 1500]
GEMS_FIRST = 200
GEMS_FIRST_BOSS = 400
GEMS_PER_STAR = 30
PULL10_COST = 900
START_GEMS = 300
# Each 10-pull on average yields: 6 노멀, 3 레어, ~0.85 유니크, ~0.15 레전더리 copies (split across types)
# Simplified: a pull yields enough copies to merge about once every N pulls per tier
TIERS = ["노멀", "레어", "유니크", "레전더리", "신화", "전설"]


def main():
    gems = START_GEMS
    pulls = 0
    # Track how high we have raised our "best" soldier via chained merges
    copies_at_tier = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0}
    best_tier = 0
    log = []
    for stage in range(1, 25):
        # Clear reward
        boss = stage % 6 == 0
        gain = (GEMS_FIRST_BOSS if boss else GEMS_FIRST) + GEMS_PER_STAR * 3  # 3 stars optimistic
        gems += gain
        # Try to pull as many 10-pulls as we can afford at this stage (half the gems, keep half for merges)
        want_pull_budget = gems // 2
        while want_pull_budget >= PULL10_COST and gems >= PULL10_COST:
            gems -= PULL10_COST
            want_pull_budget -= PULL10_COST
            pulls += 10
            # On average: ~6 노멀 copies, ~3 레어, ~0.85 유니크, ~0.15 레전더리
            copies_at_tier[0] += 6
            copies_at_tier[1] += 3
            copies_at_tier[2] += 0.85
            copies_at_tier[3] += 0.15
        # Spend any extra copies+gems on merges from the bottom up (approximate; distributes copies across kinds)
        progress = True
        while progress:
            progress = False
            for t in range(best_tier, 5):
                need_c = MERGE_COPIES[t]
                need_g = MERGE_GEMS[t]
                if copies_at_tier[t] >= need_c and gems >= need_g:
                    copies_at_tier[t] -= need_c
                    gems -= need_g
                    if t + 1 < 5:
                        copies_at_tier[t + 1] += 1
                    best_tier = max(best_tier, t + 1)
                    progress = True
                    break
        log.append((stage, gems, pulls, best_tier, {k: round(v, 1) for k, v in copies_at_tier.items()}))
    print(f"{'Stage':>5} {'Gems':>6} {'Pulls':>6} {'Best':>5}  Copies(T0,T1,T2,T3,T4)")
    for stage, g, p, bt, c in log:
        print(f"{stage:>5} {g:>6} {p:>6} {TIERS[bt]:>5}  {c}")
    print()
    print(f"After 24 stages: best tier reached = {TIERS[best_tier]} (want 전설 or close)")
    if best_tier >= 5:
        print("OK: a 전설 is reachable from first clears alone.")
    elif best_tier >= 3:
        print("MARGINAL: a 레전더리/신화 is reachable, but 전설 needs replays.")
    else:
        print("TIGHT: consider raising replay/fail gems or lowering costs.")


if __name__ == "__main__":
    main()
