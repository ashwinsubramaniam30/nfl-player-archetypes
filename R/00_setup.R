# =============================================================================
# 00_setup.R
# Packages, season range, shared data loads, and helper functions.
# Every other script assumes this file has been sourced first.
# =============================================================================

library(nflreadr)
library(dplyr)
library(ggplot2)

# Seasons analyzed. Next Gen Stats tracking data begins in 2016; we use 2018+.
# NOTE: the current season (2026) is partial, so its numbers will move week to week.
SEASONS <- 2018:2026

# Share of qualifying players tagged with each archetype (top 10% by default).
ARCHETYPE_CUTOFF <- 0.90

# ---- Helpers ----------------------------------------------------------------

# Standardize a vector to a z-score (mean 0, sd 1), ignoring NAs.
zscore <- function(x) (x - mean(x, na.rm = TRUE)) / sd(x, na.rm = TRUE)

# Summarize EPA by archetype for a long table with one row per player-season.
summarize_archetype_epa <- function(df, epa_col, weight_col = NULL) {
  out <- df |>
    group_by(archetype) |>
    summarize(
      n = n(),
      mean_epa = mean(.data[[epa_col]], na.rm = TRUE),
      median_epa = median(.data[[epa_col]], na.rm = TRUE),
      sd_epa = sd(.data[[epa_col]], na.rm = TRUE),
      weighted_epa = if (is.null(weight_col)) NA_real_ else
        weighted.mean(.data[[epa_col]], .data[[weight_col]], na.rm = TRUE),
      .groups = "drop"
    ) |>
    arrange(desc(mean_epa))
  if (is.null(weight_col)) out$weighted_epa <- NULL
  out
}

# ---- Shared data (loaded once) -------------------------------------------------

message("Loading nflverse data for ", min(SEASONS), "-", max(SEASONS), " ...")

pbp <- load_pbp(SEASONS) |>
  select(season, week, play_type, posteam, ydstogo, epa,
         pass_attempt, rush_attempt, qb_dropback, qb_scramble, rushing_yards,
         passer_player_id, passer_player_name,
         rusher_player_id, rusher_player_name,
         receiver_player_id, receiver_player_name)

rosters <- load_rosters(SEASONS)

# One row per player-season with position, keyed by GSIS id.
# FIX: joins now use player IDs instead of names. Joining on names duplicated
# players who share a name (e.g., two different "Mike Williams" WRs).
positions <- rosters |>
  filter(!is.na(gsis_id)) |>
  distinct(season, gsis_id, .keep_all = TRUE) |>
  select(season, gsis_id, pfr_id, full_name, position, team)

# Pro Football Reference ID -> GSIS ID crosswalk (PFR advanced stats use PFR IDs).
id_crosswalk <- load_players() |>
  filter(!is.na(gsis_id), !is.na(pfr_id)) |>
  distinct(pfr_id, .keep_all = TRUE) |>
  select(gsis_id, pfr_id, display_name)

ngs_passing   <- load_nextgen_stats(SEASONS, stat_type = "passing")
ngs_receiving <- load_nextgen_stats(SEASONS, stat_type = "receiving")
pfr_pass      <- load_pfr_advstats(SEASONS, stat_type = "pass")
pfr_rush      <- load_pfr_advstats(SEASONS, stat_type = "rush")
player_stats  <- load_player_stats(SEASONS)

# NOTE (open question): Next Gen Stats include a week 0 row per player that is
# the season total. The season-level averages below include that row alongside
# the weekly rows, and games_played counts it as a game. See README.
