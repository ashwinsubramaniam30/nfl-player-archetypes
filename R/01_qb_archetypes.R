# =============================================================================
# 01_qb_archetypes.R  (Ashwin Subramaniam)
# Quarterback archetypes: Pocket Passer, Gunslinger, Improviser, Dual-Threat.
# Each archetype is a weighted sum of z-scores; the top 10% of qualifying
# QB-seasons are tagged. Then EPA per dropback is compared across archetypes.
# =============================================================================

# ---- Shared QB inputs ---------------------------------------------------------

# Season-level NGS passing averages for QBs with 8+ games.
qb_ngs_season <- ngs_passing |>
  group_by(season, player_gsis_id, player_display_name) |>
  summarize(
    avg_time_to_throw      = mean(avg_time_to_throw, na.rm = TRUE),
    aggressiveness         = mean(aggressiveness, na.rm = TRUE),
    avg_intended_air_yards = mean(avg_intended_air_yards, na.rm = TRUE),
    games_played           = n_distinct(week),
    .groups = "drop"
  ) |>
  filter(games_played >= 8)

# Dropbacks attributed to a QB (passer, or rusher on scrambles).
qb_dropbacks <- pbp |>
  mutate(qb_id   = coalesce(passer_player_id, rusher_player_id),
         qb_name = coalesce(passer_player_name, rusher_player_name)) |>
  filter(qb_dropback == 1, !is.na(qb_id))

# ---- Pocket Passer: quick release + rarely scrambles ----------------------------

scramble_rate <- qb_dropbacks |>
  group_by(season, qb_id, qb_name) |>
  summarize(dropbacks = n(),
            scrambles = sum(qb_scramble, na.rm = TRUE),
            scramble_rate = scrambles / dropbacks,
            .groups = "drop") |>
  filter(dropbacks >= 288)

pocket_passer_stats <- qb_ngs_season |>
  select(season, player_gsis_id, player_display_name, avg_time_to_throw, games_played) |>
  inner_join(scramble_rate, by = c("season", "player_gsis_id" = "qb_id")) |>
  mutate(z_ttt = zscore(avg_time_to_throw),
         z_scramble = zscore(scramble_rate),
         pocket_passer_score = -z_ttt - z_scramble)

pocket_passers <- pocket_passer_stats |>
  filter(pocket_passer_score >= quantile(pocket_passer_score, ARCHETYPE_CUTOFF, na.rm = TRUE)) |>
  arrange(desc(pocket_passer_score)) |>
  select(season, player_gsis_id, player_display_name, pocket_passer_score,
         z_ttt, z_scramble, avg_time_to_throw, scramble_rate)

# ---- Gunslinger: tight-window throws + deep intended air yards --------------------

gunslinger_stats <- qb_ngs_season |>
  select(season, player_gsis_id, player_display_name, aggressiveness, avg_intended_air_yards) |>
  mutate(z_agg = zscore(aggressiveness),
         z_air = zscore(avg_intended_air_yards),
         gunslinger_score = z_agg + z_air)

gunslingers <- gunslinger_stats |>
  filter(gunslinger_score >= quantile(gunslinger_score, ARCHETYPE_CUTOFF, na.rm = TRUE)) |>
  arrange(desc(gunslinger_score))

# ---- Improviser: holds the ball, faces pressure, avoids sacks, stays accurate ----

pressure_season <- pfr_pass |>
  group_by(season, pfr_player_id, pfr_player_name) |>
  summarize(times_pressured = sum(times_pressured, na.rm = TRUE),
            times_sacked = sum(times_sacked, na.rm = TRUE),
            .groups = "drop") |>
  mutate(sack_rate_given_pressure = times_sacked / times_pressured) |>
  left_join(select(id_crosswalk, gsis_id, pfr_id), by = c("pfr_player_id" = "pfr_id"))

cpoe_season <- player_stats |>
  filter(position == "QB") |>
  group_by(season, player_id, player_display_name) |>
  summarize(passing_cpoe = mean(passing_cpoe, na.rm = TRUE), .groups = "drop")

improviser_stats <- qb_ngs_season |>
  select(season, player_gsis_id, player_display_name, avg_time_to_throw, games_played) |>
  left_join(pressure_season, by = c("season", "player_gsis_id" = "gsis_id")) |>
  left_join(select(cpoe_season, season, player_id, passing_cpoe),
            by = c("season", "player_gsis_id" = "player_id")) |>
  mutate(z_ttt = zscore(avg_time_to_throw),
         z_pressure = zscore(times_pressured),
         z_sack_given_pressure = zscore(sack_rate_given_pressure),
         z_cpoe = zscore(passing_cpoe),
         improviser_score = z_ttt + z_pressure - z_sack_given_pressure + 0.5 * z_cpoe)

improvisers <- improviser_stats |>
  filter(improviser_score >= quantile(improviser_score, ARCHETYPE_CUTOFF, na.rm = TRUE)) |>
  arrange(desc(improviser_score))

# ---- Dual-Threat: runs often and runs efficiently ---------------------------------

# Confirm real QBs by passing volume (NGS), not roster position tags.
pass_attempts <- ngs_passing |>
  filter(player_position == "QB") |>
  group_by(season, player_gsis_id) |>
  summarize(total_attempts = sum(attempts, na.rm = TRUE), .groups = "drop") |>
  filter(total_attempts >= 100)

dropback_counts <- qb_dropbacks |>
  group_by(season, qb_id) |>
  summarize(dropbacks = n(), games_played = n_distinct(week), .groups = "drop")

# Designed runs + scrambles.
qb_rushing <- pbp |>
  filter(rush_attempt == 1, !is.na(rusher_player_id)) |>
  group_by(season, rusher_player_id, rusher_player_name) |>
  summarize(carries = n(),
            total_rush_yards = sum(rushing_yards, na.rm = TRUE),
            yards_per_carry = total_rush_yards / carries,
            rush_epa_per_play = mean(epa, na.rm = TRUE),
            .groups = "drop")

dual_threat_stats <- qb_rushing |>
  inner_join(pass_attempts, by = c("season", "rusher_player_id" = "player_gsis_id")) |>
  left_join(dropback_counts, by = c("season", "rusher_player_id" = "qb_id")) |>
  filter(games_played >= 9) |>
  mutate(rush_rate = carries / (dropbacks + carries),
         z_rush_rate = zscore(rush_rate),
         z_ypc = zscore(yards_per_carry),
         z_rush_epa = zscore(rush_epa_per_play),
         dual_threat_score = z_rush_rate + z_rush_epa + 0.5 * z_ypc)

# NOTE: gadget QBs with real passing volume (the "Taysom Hill problem") can still qualify.
dual_threat <- dual_threat_stats |>
  filter(dual_threat_score >= quantile(dual_threat_score, ARCHETYPE_CUTOFF, na.rm = TRUE)) |>
  arrange(desc(dual_threat_score)) |>
  select(season, rusher_player_name, rusher_player_id, dual_threat_score, rush_rate,
         yards_per_carry, rush_epa_per_play, carries, total_attempts)

# ---- EPA per dropback by archetype --------------------------------------------------

qb_epa <- qb_dropbacks |>
  group_by(season, qb_id) |>
  summarize(epa_per_dropback = mean(epa, na.rm = TRUE), dropbacks = n(), .groups = "drop")

qb_archetypes <- bind_rows(
  transmute(pocket_passers, season, qb_id = player_gsis_id, player = player_display_name, archetype = "Pocket Passer"),
  transmute(gunslingers,    season, qb_id = player_gsis_id, player = player_display_name, archetype = "Gunslinger"),
  transmute(improvisers,    season, qb_id = player_gsis_id, player = player_display_name, archetype = "Improviser"),
  transmute(dual_threat,    season, qb_id = rusher_player_id, player = rusher_player_name, archetype = "Dual-Threat")
) |>
  left_join(qb_epa, by = c("season", "qb_id"))

qb_archetype_summary <- summarize_archetype_epa(qb_archetypes, "epa_per_dropback")

qb_epa_plot <- ggplot(qb_archetypes, aes(x = archetype, y = epa_per_dropback)) +
  geom_boxplot() +
  coord_flip() +
  labs(x = "Archetype", y = "EPA per Dropback", title = "QB Performance by Archetype",
       caption = paste0("Seasons ", min(SEASONS), "-", max(SEASONS), " | Data: nflverse"))
