# =============================================================================
# 03_wr_archetypes.R  (Ashwin Subramaniam, building on Naveen Narayanaswami's
# first deep threat and route runner drafts)
# Wide receiver archetypes: Contested Catcher, Deep Threat, Route Runner.
# Uses WRs with 100+ targets in a season, then compares EPA per target.
# =============================================================================

MIN_TARGETS <- 100

# Season-level NGS receiving profile.
wr_season <- ngs_receiving |>
  group_by(season, player_gsis_id, player_display_name, team_abbr) |>
  summarize(avg_separation         = mean(avg_separation, na.rm = TRUE),
            avg_catch_percentage   = mean(catch_percentage, na.rm = TRUE),
            avg_intended_air_yards = mean(avg_intended_air_yards, na.rm = TRUE),
            szn_receptions         = sum(receptions, na.rm = TRUE),
            szn_targets            = sum(targets, na.rm = TRUE),
            games_played           = n_distinct(week),
            .groups = "drop")

# Qualifying pool: WRs with 100+ targets in the season.
# FIX: positions are joined by player ID instead of name.
wr_pool <- wr_season |>
  left_join(select(positions, season, gsis_id, position),
            by = c("season", "player_gsis_id" = "gsis_id")) |>
  filter(position == "WR", szn_targets >= MIN_TARGETS)

# ---- Contested Catcher: catches a lot despite little separation ------------------

contested_stats <- wr_pool |>
  mutate(z_separation = zscore(avg_separation),
         z_catch_percentage = zscore(avg_catch_percentage),
         z_contested_catcher = z_catch_percentage - z_separation)

contested_catchers <- contested_stats |>
  filter(z_contested_catcher >= quantile(z_contested_catcher, ARCHETYPE_CUTOFF, na.rm = TRUE)) |>
  arrange(desc(z_contested_catcher))

# ---- Deep Threat: highest average intended air yards ---------------------------------

deep_threats <- wr_pool |>
  filter(avg_intended_air_yards >= quantile(avg_intended_air_yards, ARCHETYPE_CUTOFF, na.rm = TRUE)) |>
  arrange(desc(avg_intended_air_yards))

# ---- Route Runner: most separation at the catch point ---------------------------------

route_runners <- wr_pool |>
  filter(avg_separation >= quantile(avg_separation, ARCHETYPE_CUTOFF, na.rm = TRUE)) |>
  arrange(desc(avg_separation))

# ---- EPA per target by archetype --------------------------------------------------

receiver_epa <- pbp |>
  filter(pass_attempt == 1, !is.na(receiver_player_id)) |>
  group_by(season, receiver_player_id) |>
  summarize(epa_per_target = mean(epa, na.rm = TRUE), pbp_targets = n(), .groups = "drop")

wr_archetypes <- bind_rows(
  mutate(contested_catchers, archetype = "Contested Catcher"),
  mutate(deep_threats, archetype = "Deep Threat"),
  mutate(route_runners, archetype = "Route Runner")
) |>
  select(season, player_gsis_id, player = player_display_name, team_abbr, archetype) |>
  left_join(receiver_epa, by = c("season", "player_gsis_id" = "receiver_player_id"))

wr_archetype_summary <- summarize_archetype_epa(wr_archetypes, "epa_per_target", "pbp_targets")

# FIX: the plot now uses one row per receiver-season (it previously pointed at
# the grouped summary) and the axis says EPA per Target.
wr_epa_plot <- ggplot(wr_archetypes, aes(x = archetype, y = epa_per_target)) +
  geom_boxplot() +
  coord_flip() +
  labs(x = "Archetype", y = "EPA per Target", title = "WR Performance by Archetype",
       caption = paste0("Seasons ", min(SEASONS), "-", max(SEASONS), " | Data: nflverse"))
