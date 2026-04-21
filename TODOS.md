# TODOS — EclecticShuffle Plugin

## TODO-001: Pre-install skip baseline capture
**What:** Before UAT, record a 3-session skip baseline without the plugin.
**Why:** The success metric (20% skip reduction) requires a pre-install baseline to measure against. The plugin only records events after install, so the comparison data must be captured manually.
**How to apply:** Ask the brother to count skips per hour across 3 typical listening sessions before installing the plugin. Record in a shared note (e.g., Notes app, shared doc). Store as: date, session length (minutes), skip count. After install, compare post-install skip rate (auto-captured by the plugin) against this baseline.
**Depends on:** Nothing. Do this BEFORE plugin install.
**Status:** Open

---

## TODO-002: ARM / Raspberry Pi portability verification
**What:** Before submitting to the LMS Plugin Manager (public listing), verify the plugin installs and runs on a Raspberry Pi (ARM Linux, the most common LMS community platform).
**Why:** Brother's install is Red Hat x86_64. The plugin uses only LMS's bundled Perl with no compiled XS binaries, so portability is likely fine — but unverified. First community ARM user will be the inadvertent test if not addressed.
**How to apply:** Find one community member with a Raspberry Pi LMS install (or use a Pi in the project) and do a clean install from the zip. Verify plugin loads, DB creates, weights persist, and queue generates.
**Pros:** Avoids first community bug report being "broken on Pi."
**Cons:** Requires access to a Pi or a willing early adopter.
**Depends on:** v1 UAT with brother complete and confirmed working.
**Status:** Open

---

## TODO-003: Per-player weight profiles (v2)
**What:** Use the player_id column already in play_events to build per-player weight profiles, replacing the current server-wide track_weights table.
**Why:** Households with multiple listeners on the same LMS instance will find that one person's skips penalise tracks for everyone else. For v1 (single listener), this is intentional. For community distribution, it's a known defect.
**How to apply:** Add a player_id dimension to track_weights (or a separate track_weights_{player_id} table). The player_id column is already captured in play_events — no schema migration needed for events, only for weights. Schema.pm v2 migration would use schema_version table (already planned).
**Pros:** Correct multi-listener behaviour. Unlocks household use case.
**Cons:** Weight history from v1 is shared and cannot be split retroactively per player.
**Depends on:** v1 UAT complete. Activate when a community user reports the shared-weights limitation, or when the brother gets a second listener.
**Status:** Open (v2)
