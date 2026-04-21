# EclecticShuffle

A shuffle plugin for [Lyrion Music Server](https://lyrion.org) that learns from your listening history.

Tracks you play to the end get surfaced more often. Tracks you skip get played less. The longer you use it, the better it knows your taste — without you having to rate, tag, or configure anything beyond one slider.

---

## How it works

Every time a track plays, EclecticShuffle watches what you do:

- **Skip** (stopped before 20% of the track): small penalty, track plays less often
- **Complete** (played past 80%): small bonus, track plays more often
- **Partial** (20–80%): recorded but no weight change

Weights decay over time. A track you loved six months ago drifts back toward neutral if you haven't played it recently — so the plugin keeps up with how your taste shifts, not just a one-time snapshot.

Each queue top-up is a mix of **weighted picks** (tracks your history says you like) and **random picks** (tracks you haven't heard recently, for discovery). The **Adventurousness** slider controls the balance.

---

## Requirements

- Lyrion Music Server 8.0 or later (tested on 9.1.0)
- No other dependencies — EclecticShuffle uses the SQLite database already bundled with LMS

---

## Installation

### Step 1 — Download the zip

Go to [Releases](../../releases) and download `EclecticShuffle-1.0.0.zip`. Save it anywhere on your computer.

### Step 2 — Upload to LMS

1. Open LMS in your browser (usually `http://your-server:9000`)
2. Go to **Settings** (top right)
3. Click the **Plugins** tab
4. Scroll to the bottom and click **Install from file**
5. Choose the zip file you downloaded and click **Install**

### Step 3 — Restart LMS

LMS will ask you to restart. Click **Restart** and wait about 30 seconds for it to come back.

### Step 4 — Find the settings page

1. Go back to **Settings → Plugins**
2. You should see **Eclectic Shuffle** in the list
3. Click it to open the settings page

That's it. The plugin is installed.

---

## Using the plugin

### Starting Eclectic Shuffle

1. Open the **Eclectic Shuffle** settings page (Settings → Plugins → Eclectic Shuffle)
2. Make sure your player is selected (the player name appears at the top of the LMS settings page)
3. Click **Start Eclectic Shuffle**

LMS will fill your queue with 20 tracks and keep topping it up as you listen. You can still skip, add tracks manually, or use any LMS client as normal — EclecticShuffle works in the background.

### Stopping

Click **Stop (use native shuffle)** on the settings page. Your queue stays as-is; EclecticShuffle just stops managing it.

### The Adventurousness slider

The slider runs from 0 to 10 and controls two things at once: how much your history influences picks, and how much randomness is mixed in.

| Slider | What happens |
|--------|-------------|
| **0** | Plays your highest-weighted tracks in order. Very predictable. |
| **1–4** | Mostly favourites, occasional surprises. |
| **5** | Half your queue is history-weighted, half is random discovery. **(default)** |
| **6–9** | Mostly random, light weighting from history. |
| **10** | Fully random — history is ignored entirely. Same as native shuffle. |

At **10**, the status note will say: *"Weights are not used for selection at this setting."* Events are still recorded, so your history keeps building even when you explore.

### The status indicator

The settings page shows a status line that updates whenever you reload it:

| Status | What it means |
|--------|--------------|
| **Inactive** | Plugin is installed but not running. Click Start. |
| **Learning (N/20 tracks heard)** | Not enough history yet. Plugin is in native shuffle mode until 20 distinct tracks have been played or skipped. |
| **Eclectic Shuffle active (N tracks in history)** | Weighted mode is on and working. |
| **Database unavailable** | Something went wrong with the database. LMS log has details. Native shuffle is being used as a fallback. |

### Resetting weights

If you want to start fresh — say, someone else used your system for a week and skewed the weights — click **Reset weights** on the settings page. This clears all learned history and starts the learning process from zero.

A confirmation dialog will appear before anything is deleted.

---

## Tips

**Let it run for a week before judging it.** The first few hours after cold-start, EclecticShuffle doesn't have enough history to be meaningfully different from native shuffle. After a week of regular listening, the difference becomes noticeable.

**Slider 5 is a good starting point.** Half your queue comes from what you've liked before, half comes from tracks you haven't heard recently. This keeps things fresh while building on your taste.

**Skip freely.** Skipping is how EclecticShuffle learns. There's no penalty for skipping — you're giving the plugin information. Tracks skipped consistently will appear less often over time.

**Eclectic Shuffle and your existing queue.** If you add tracks manually or use another LMS feature, EclecticShuffle won't interfere. It only adds tracks to an empty or near-empty queue — it tops up to 5 remaining tracks, then adds a batch of 20. Your manually added tracks stay in place.

---

## Folder layout

```
EclecticShuffle/
  Plugin.pm       Main plugin: event hooks, activate/deactivate, event classification
  Schema.pm       SQLite database layer: events, weights, pruning
  Scoring.pm      Applies weight deltas on play events
  Playlist.pm     Queue generation: softmax sampling + LMS random mix
  Settings.pm     LMS web settings page handler
  install.xml     Plugin manifest
  strings.txt     UI strings (English)
  HTML/Default/plugins/EclecticShuffle/
    settings.html LMS settings page template

t/
  events.t        Unit tests: skip/completion/partial classification
  scoring.t       Unit tests: weight update, clamp, recalc formula
  playlist.t      Unit tests: temperature formula, queue split, decay, softmax
```

---

## How the algorithm works (for the curious)

Each track has a **base weight** that starts at 1.0 (neutral). It goes up when you complete a track (+1.0, max 10.0) and down when you skip one (−0.5, min 0.1). A track can never be fully excluded — the floor of 0.1 means anything in your library can still appear, just rarely.

The **live score** applies a time decay to base weight:

```
score = base_weight × 0.977 ^ days_since_last_play
```

A track not played for about 30 days scores roughly half its base weight. After a year without playing it, even a heavily-weighted track drifts back toward neutral. This means your taste today matters more than your taste two years ago.

When building a queue, EclecticShuffle uses **softmax sampling** — a mathematical technique that turns scores into probabilities, where higher-scored tracks are more likely to be picked but not guaranteed. The Adventurousness slider controls the temperature of the softmax: low temperature makes it deterministic (top tracks always win), high temperature makes it uniform (all tracks equal).

Half the queue is always filled from LMS's own native random picks — tracks you haven't necessarily heard before. This is how new music enters the rotation even when EclecticShuffle is fully active.

---

## License

MIT
