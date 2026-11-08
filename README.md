# NFL Player Archetypes

**Which kinds of NFL players produce the most value?** This project sorts quarterbacks, running backs and wide receivers into statistical archetypes using 2018–2026 play-by-play, Next Gen Stats tracking and Pro Football Reference advanced data, then compares how much each archetype contributes in **expected points added (EPA)**.

*Status: archetype definitions and EPA comparisons are complete. Next step: test whether archetype traits are linked to team success (see [Next steps](#next-steps)).*

## How it works

For each position we pick a few measurable traits, standardize them as z-scores across qualifying player-seasons, combine them into an archetype score, and tag the **top 10%** of player-seasons (top 5% or 15% where noted). A player can hold more than one archetype in the same season.

### Quarterbacks (8+ games, 288+ dropbacks where applicable)

| Archetype | Defined by |
|---|---|
| Pocket Passer | Quick time to throw and low scramble rate |
| Gunslinger | High aggressiveness (tight-window throws) and deep intended air yards |
| Improviser | Holds the ball longer, faces more pressure, avoids sacks under pressure, and stays accurate (CPOE, half weight) |
| Dual-Threat | High rush rate and rushing EPA per play, plus yards per carry (half weight). QBs need 100+ pass attempts |

### Running backs (72+ carries)

| Archetype | Defined by |
|---|---|
| Power Back | High share of carries with 7 or fewer yards to go |
| Receiving Back | High share of the team's pass attempts targeted to him |
| Elusive Back | Broken tackles per carry |

### Wide receivers (100+ targets)

| Archetype | Defined by |
|---|---|
| Contested Catcher | High catch rate despite low separation (top 5%) |
| Deep Threat | Highest average intended air yards |
| Route Runner | Most average separation (top 15%) |

## Results so far

**Quarterbacks: EPA per dropback**

| Archetype | QB-seasons | Mean EPA | Median EPA |
|---|---|---|---|
| Improviser | 30 | 0.154 | 0.136 |
| Pocket Passer | 27 | 0.086 | 0.110 |
| Dual-Threat | 28 | 0.083 | 0.060 |
| Gunslinger | 30 | 0.007 | 0.005 |

![QB EPA by archetype](output/figures/qb_epa_by_archetype.png)

**Running backs: EPA per touch (carries + targets)**

| Archetype | RB-seasons | Mean EPA | Median EPA | Touch-weighted EPA |
|---|---|---|---|---|
| Power Back | 26 | -0.007 | -0.007 | 0.002 |
| Elusive Back | 50 | -0.021 | -0.031 | -0.025 |
| Receiving Back | 50 | -0.028 | -0.012 | -0.023 |

![RB EPA by archetype](output/figures/rb_epa_by_archetype.png)

**Wide receivers: EPA per target**

| Archetype | WR-seasons | Mean EPA | Median EPA | Target-weighted EPA |
|---|---|---|---|---|
| Contested Catcher | 31 | 0.497 | 0.525 | 0.493 |
| Deep Threat | 50 | 0.293 | 0.320 | 0.299 |
| Route Runner | 18 | 0.258 | 0.259 | 0.277 |

![WR EPA by archetype](output/figures/wr_epa_by_archetype.png)

Early takeaways (descriptive, not causal):
- **Improviser QBs** produced the most EPA per dropback, and **Gunslingers** the least.
- **Running back archetypes are bunched close to zero**, consistent with the broader finding that RB value depends heavily on the offense around them.
- **Contested Catchers** lead WRs by a wide margin. Part of this is built into the definition: a high catch rate means more completed targets, which raises EPA per target.

The 2026 season is partial and updates as new data is published.

## Run it yourself

Requires R with `nflreadr`, `dplyr` and `ggplot2`. All data is downloaded from the public [nflverse](https://github.com/nflverse) data releases, so no local files are needed.

```r
install.packages(c("nflreadr", "dplyr", "ggplot2"))
```

```bash
Rscript run_all.R
```

This writes player-level archetype tags and EPA summaries to `output/` and the charts to `output/figures/`.

## Repository layout

```
R/00_setup.R            packages, season range, data loads, helpers
R/01_qb_archetypes.R    QB archetypes + EPA per dropback
R/02_rb_archetypes.R    RB archetypes + EPA per touch
R/03_wr_archetypes.R    WR archetypes + EPA per target
run_all.R               runs everything, saves CSVs and charts
output/                 results (CSV) and figures (PNG)
```

## Open questions

Methodology choices still under discussion; each is marked `NOTE` in the code:

1. **Next Gen Stats week 0 rows.** NGS includes a week 0 row per player that is the season total. Season averages currently include it alongside weekly rows, and `games_played` counts it as a game. Using the week 0 row directly would be cleaner.
2. **Percentile cutoffs computed before position filters.** Power Backs and Deep Threats take the 90th percentile across all players (including QBs, TEs and low-volume players) before keeping only RBs or WRs, so fewer players qualify than the "top 10%" label suggests.
3. **Different cutoffs by archetype.** Contested Catcher uses the top 5% and Route Runner the top 15%; everything else uses the top 10%.
4. **"Power Back" uses 7 or fewer yards to go**, which captures many standard downs, not just short-yardage situations.
5. **Gadget QBs** (the "Taysom Hill problem") can still qualify as Dual-Threat if they meet the passing threshold.

## Next steps

- Test whether archetype traits are linked to team success (wins, playoff appearances, offensive EPA).
- Apply the archetypes to individual rosters, for example which archetypes a team has and which it lacks compared with playoff teams.
- Add tight end and defensive archetypes.

## Authors

- **Ashwin Subramaniam**: quarterback and wide receiver archetypes, EPA comparisons ([GitHub](https://github.com/ashwinsubramaniam30))
- **Naveen Narayanaswami**: running back archetypes, first drafts of the deep threat and route runner definitions ([GitHub](https://github.com/naveennar2026-git))

Data: [nflverse](https://github.com/nflverse) via the `nflreadr` R package (play-by-play, Next Gen Stats, Pro Football Reference advanced stats).
