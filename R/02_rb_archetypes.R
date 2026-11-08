# =============================================================================
# 02_rb_archetypes.R  (Naveen Narayanaswami)
# Running back archetypes: Power Back, Receiving Back, Elusive Back.
# The top 10% of qualifying RB-seasons (72+ carries) are tagged, then EPA per
# touch is compared across archetypes.
# =============================================================================

MIN_CARRIES <- 72

# ---- Shared RB inputs -----------------------------------------------------------

# Rushing EPA and carries for every ball carrier.
# FIX: na.rm = TRUE added; one missing EPA value previously made the season total NA.
rush_epa <- pbp |>
  filter(!is.na(rusher_player_id)) |>
  group_by(season, rusher_player_id) |>
  summarize(rusher_player_name = first(rusher_player_name),
            total_rush_epa = sum(epa, na.rm = TRUE), szn_carries = n(), .groups = "drop")

# Receiving EPA and targets for every pass target.
# FIX: renamed total_catches -> szn_targets. The count is every play the player
# was targeted, not only completed catches.
rec_epa <- pbp |>
  filter(!is.na(receiver_player_id)) |>
  group_by(season, receiver_player_id) |>
  summarize(total_pass_epa = sum(epa, na.rm = TRUE), szn_targets = n(), .groups = "drop")

# Add rushing + receiving EPA per touch to a table of RB-seasons keyed by GSIS id.
# FIX: backs with zero targets now get 0 receiving EPA instead of NA.
add_rb_epa <- function(df, id_col = "rusher_player_id") {
  df |>
    select(season, rb_id = all_of(id_col)) |>
    distinct() |>
    left_join(rush_epa, by = c("season", "rb_id" = "rusher_player_id")) |>
    left_join(rec_epa,
              by = c("season", "rb_id" = "receiver_player_id")) |>
    mutate(total_pass_epa = coalesce(total_pass_epa, 0),
           szn_targets = coalesce(szn_targets, 0L),
           epa_sum = total_rush_epa + total_pass_epa,
           touches = szn_carries + szn_targets,
           epa_per_touch = epa_sum / touches) |>
    arrange(desc(epa_per_touch))
}

run_plays <- filter(pbp, play_type == "run")

rb_carries <- run_plays |>
  group_by(season, rusher_player_id) |>
  summarize(rusher_player_name = first(rusher_player_name), season_carries = n(), .groups = "drop")

# ---- Power Back: high share of carries with 7 or fewer yards to go ----------------

power_stats <- run_plays |>
  filter(ydstogo <= 7) |>
  group_by(season, rusher_player_id) |>
  summarize(carries_u7 = n(), .groups = "drop") |>
  inner_join(filter(rb_carries, season_carries >= MIN_CARRIES),
             by = c("season", "rusher_player_id")) |>
  mutate(u7_carry_rate = carries_u7 / season_carries) |>
  left_join(select(positions, season, gsis_id, position),
            by = c("season", "rusher_player_id" = "gsis_id"))

power_backs <- power_stats |>
  filter(position == "RB") |>
  filter(u7_carry_rate >= quantile(u7_carry_rate, ARCHETYPE_CUTOFF, na.rm = TRUE)) |>
  arrange(desc(u7_carry_rate))

# ---- Receiving Back: high share of team pass attempts -----------------------------

pass_plays <- filter(pbp, play_type == "pass")

rb_targets <- pass_plays |>
  group_by(season, receiver_player_id) |>
  summarize(szn_targets = n(), .groups = "drop")

team_passing <- pass_plays |>
  group_by(season, posteam) |>
  summarize(team_throws = sum(pass_attempt), .groups = "drop")

receiving_stats <- rb_carries |>
  filter(season_carries >= MIN_CARRIES) |>
  left_join(rb_targets, by = c("season", "rusher_player_id" = "receiver_player_id")) |>
  left_join(select(positions, season, gsis_id, position, team),
            by = c("season", "rusher_player_id" = "gsis_id")) |>
  filter(position == "RB") |>
  # Roster team codes differ from play-by-play codes for relocated teams.
  mutate(team = case_match(team, "LAR" ~ "LA", "SD" ~ "LAC", "OAK" ~ "LV", .default = team)) |>
  left_join(team_passing, by = c("season", "team" = "posteam")) |>
  mutate(target_rate = szn_targets / team_throws)

receiving_backs <- receiving_stats |>
  filter(target_rate >= quantile(target_rate, ARCHETYPE_CUTOFF, na.rm = TRUE)) |>
  arrange(desc(target_rate))

# ---- Elusive Back: broken tackles per carry -----------------------------------------

elusive_stats <- pfr_rush |>
  group_by(season, pfr_player_id, pfr_player_name) |>
  summarize(szn_carries = sum(carries, na.rm = TRUE),
            total_rush_broken = sum(rushing_broken_tackles, na.rm = TRUE),
            .groups = "drop") |>
  filter(szn_carries >= MIN_CARRIES) |>
  mutate(broken_tackle_per_carry = total_rush_broken / szn_carries) |>
  # FIX: map PFR ids to GSIS ids so EPA can be joined (this join previously errored).
  left_join(select(id_crosswalk, gsis_id, pfr_id), by = c("pfr_player_id" = "pfr_id")) |>
  left_join(select(positions, season, gsis_id, position), by = c("season", "gsis_id")) |>
  filter(position == "RB")

elusive_backs <- elusive_stats |>
  filter(broken_tackle_per_carry >= quantile(broken_tackle_per_carry, ARCHETYPE_CUTOFF, na.rm = TRUE)) |>
  arrange(desc(broken_tackle_per_carry))

# ---- EPA per touch by archetype --------------------------------------------------

rb_archetypes <- bind_rows(
  mutate(add_rb_epa(power_backs), archetype = "Power Back"),
  mutate(add_rb_epa(receiving_backs), archetype = "Receiving Back"),
  mutate(add_rb_epa(elusive_backs, "gsis_id"), archetype = "Elusive Back")
) |>
  rename(player = rusher_player_name)

rb_archetype_summary <- summarize_archetype_epa(rb_archetypes, "epa_per_touch", "touches")

rb_epa_plot <- ggplot(rb_archetypes, aes(x = archetype, y = epa_per_touch)) +
  geom_boxplot() +
  coord_flip() +
  labs(x = "Archetype", y = "EPA per Touch", title = "RB Performance by Archetype",
       caption = paste0("Seasons ", min(SEASONS), "-", max(SEASONS), " | Data: nflverse"))
