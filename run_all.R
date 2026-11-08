# =============================================================================
# run_all.R
# Runs the full pipeline and writes results to output/.
# Usage (from the repo root):  Rscript run_all.R
# =============================================================================

source("R/00_setup.R")
source("R/01_qb_archetypes.R")
source("R/02_rb_archetypes.R")
source("R/03_wr_archetypes.R")

dir.create("output/figures", recursive = TRUE, showWarnings = FALSE)

# Player-season archetype tags with EPA
write.csv(qb_archetypes, "output/qb_archetypes.csv", row.names = FALSE)
write.csv(rb_archetypes, "output/rb_archetypes.csv", row.names = FALSE)
write.csv(wr_archetypes, "output/wr_archetypes.csv", row.names = FALSE)

# EPA summaries by archetype
write.csv(qb_archetype_summary, "output/qb_archetype_summary.csv", row.names = FALSE)
write.csv(rb_archetype_summary, "output/rb_archetype_summary.csv", row.names = FALSE)
write.csv(wr_archetype_summary, "output/wr_archetype_summary.csv", row.names = FALSE)

ggsave("output/figures/qb_epa_by_archetype.png", qb_epa_plot, width = 7, height = 4, dpi = 150)
ggsave("output/figures/rb_epa_by_archetype.png", rb_epa_plot, width = 7, height = 4, dpi = 150)
ggsave("output/figures/wr_epa_by_archetype.png", wr_epa_plot, width = 7, height = 4, dpi = 150)

print(qb_archetype_summary)
print(rb_archetype_summary)
print(wr_archetype_summary)
message("Done. Results are in output/.")
