# Eclectic Music Discovery System – API Integration Guide

## Overview
A learning music discovery platform that integrates with Lyrionmusic Server (LMS), Blueosand LastFM to generate increasingly personalised eclectic playlists based on user listening behaviour.

---

## Core Parameters (1-10 Scale)

### Primary Eclecticism Controls
- **Genre Variety** (1-10)
  - 1 = Single genre playlist
  - 5 = Balanced mix
  - 10 = Wildly heterogeneous styles

- **BPM Variety** (1-10)
  - 1 = Consistent tempo (±10 BPM)
  - 5 = Moderate variation (±30 BPM)
  - 10 = Extreme range (40–200+ BPM)

- **Band Members** (1-10)
  - 1 = Solo artists only
  - 5 = Mixed ensemble sizes
  - 10 = Large orchestras/ensembles preferred
  - **With member tracking**: System learns which individual musicians user prefers, their instrument roles, and career movements across bands

### Mood System
- **Mood Selection** (10-point scale)
  - Euphoric (😄) → Energetic (⚡) → Happy (😊) → Upbeat (🎉)
  - Peaceful (☮️) → Calm (😌) → Contemplative (🤔)
  - Melancholic (😢) → Sad (💔) → Dark (🌑)
  
  The system uses mood to filter and weight tracks, matching emotional arc with musical characteristics. Mood is stored with each playback event to build temporal mood-preference patterns.

### Audio Characteristics
- **Acousticness** (1-10)
  - 1 = Fully electric/synthesised
  - 10 = Purely acoustic instruments

- **Danceability** (1-10)
  - 1 = Non-danceable, experimental
  - 10 = Highly rhythmic, club-ready

- **Energy** (1-10)
  - 1 = Ambient, calm, introspective
  - 10 = Intense, aggressive, fast

- **Instrumentalness** (1-10)
  - 1 = Vocal-focused
  - 10 = Pure instrumental/ambient

- **Liveness** (1-10)
  - 1 = Studio recordings
  - 10 = Live performances

- **Speechiness** (1-10)
  - 1 = Music-focused
  - 10 = Spoken word, podcast-like

- **Explicitness** (1-10)
  - 1 = Clean/family-friendly
  - 10 = Mature/explicit content

---

## Band Member Tracking System

### Individual Musician Tracking

The system learns about individual musicians across their career trajectory:

```javascript
memberProfile = {
  name: 'David Gilmour',
  primaryInstrument: 'guitar',
  currentBands: ['Pink Floyd'],
  historicalBands: [
    { band: 'Pink Floyd', joinedYear: 1968, leftYear: null, roles: ['guitar', 'vocals'] },
    { band: 'Jokers Wild', joinedYear: 1962, leftYear: 1965, roles: ['guitar'] },
    { band: 'Syd Barrett tribute', joinedYear: 2005, leftYear: 2007, roles: ['guitar'] }
  ],
  collaborations: ['David Bowie', 'Phil Manzanera', 'Polly Samson'],
  playlistAppearances: 24,  // Number of times heard in user's playlists
  averageCompletion: 0.92,  // How often user completes tracks with this member
  genresActive: ['rock', 'psychedelic rock', 'progressive rock'],
  eraActive: [1962, 2024],
}
```

### Member Affinity Learning

```javascript
memberAffinity = {
  favMusicians: {
    'David Gilmour': { count: 24, avg_completion: 0.92, mood_association: [5, 6, 7] },
    'Jon Lord': { count: 18, avg_completion: 0.88, mood_association: [2, 3, 5] },
    'John Entwistle': { count: 15, avg_completion: 0.85, mood_association: [2, 4, 8] },
  },
  memberTransitions: {
    'Ginger Baker': {
      movements: [
        { from: 'Cream', to: 'Blind Faith', year: 1969 },
        { from: 'Blind Faith', to: 'solo', year: 1970 },
        { from: 'solo', to: 'Graham Bond Organization', year: 1963 }  // backwards for clarity
      ]
    }
  },
  "supergroup" detection: [
    { members: ['Eric Clapton', 'Ginger Baker', 'Jack Bruce'], band: 'Cream', userAffinity: 0.95 }
  ]
}
```

### Cross-Band Discovery

When user likes a musician, system can recommend:
1. **Earlier bands** the musician was in
2. **Later projects** after they left their well-known band
3. **Collaborations** with musicians they also enjoy
4. **Bands with overlapping members** (e.g., "You liked David Gilmour from Pink Floyd, might enjoy these other members' side projects")

### Track Member Data Structure

```javascript
track = {
  title: 'Comfortably Numb',
  artist: 'Pink Floyd',
  members: [
    {
      name: 'David Gilmour',
      instrument: 'lead guitar, vocals',
      joinedYear: 1968,
      isCurrentMember: true,
      previousBands: ['Jokers Wild', 'Syd Barrett tribute']
    },
    {
      name: 'Roger Waters',
      instrument: 'bass guitar, vocals',
      joinedYear: 1965,
      isCurrentMember: false,  // Left in 1985
      leftYear: 1985,
      previousBands: ['T-Set', 'Sigma 6'],
      laterProjects: ['solo career', 'The Wall touring']
    },
    {
      name: 'Rick Wright',
      instrument: 'keyboards',
      joinedYear: 1965,
      leftYear: 1979,
      rejoinedYear: 1987,  // Returned for re-recordings
      previousBands: [],
      laterProjects: ['Zee', 'solo albums']
    },
    {
      name: 'Nick Mason',
      instrument: 'drums, percussion',
      joinedYear: 1964,
      isCurrentMember: true
    }
  ]
}
```

---

## Suggested Additional Parameters

### Temporal/Historical
- **Era Span** (1-10)
  - 1 = Single decade
  - 10 = 1920s–present day
  
- **Release Freshness** (1-10)
  - 1 = Only classic/historic tracks
  - 10 = Exclusively new releases (<1 year)

- **Popularity Spread** (1-10)
  - 1 = Mainstream hits only
  - 10 = Ultra-obscure deep cuts

### Cultural/Regional
- **Geographic Diversity** (1-10)
  - 1 = Single country/region
  - 10 = Global/world music fusion

- **Language Mix** (1-10)
  - 1 = Single language
  - 10 = Polyglot playlist

### Technical Audio
- **Loudness Variance** (1-10)
  - 1 = Consistent loudness
  - 10 = Dynamic compression variation

- **Frequency Balance** (1-10)
  - 1 = Treble-heavy/bright
  - 5 = Balanced
  - 10 = Bass-heavy/warm

- **Production Quality** (1-10)
  - 1 = High-fidelity studio (>320kbps)
  - 10 = Lo-fi/bedroom recordings

### Emotional/Thematic
- **Mood Range** (1-10)
  - Linked to circumplex model of emotion
  - 1-4: High arousal (Euphoric→Upbeat)
  - 5-7: Moderate arousal (Peaceful→Contemplative)
  - 8-10: Low arousal/negative valence (Melancholic→Dark)

- **Lyrical Sentiment** (1-10)
  - 1 = Positive/uplifting
  - 10 = Dark/melancholic

- **Novelty Score** (1-10)
  - 1 = Similar to what you know
  - 10 = Completely unexpected styles

### Collaborative/Social
- **Artist Collaboration Density** (1-10)
  - 1 = Solo artists/bands
  - 10 = Heavy on features & remixes

- **Producer Diversity** (1-10)
  - 1 = Same producer
  - 10 = Different producer per track

---

## API Integration Architecture

### 1. Logitech Media Server (LMS) Integration

**Endpoint Base**: `http://YOUR_LMS_SERVER:9000/`

```javascript
// Query player information
GET /jsonrpc.js
?request={
  "jsonrpc": "2.0",
  "method": "slim.request",
  "params": ["<PLAYER_ID>", ["status", "tags:aAlBdkmnrtuoyDc"]]
}

// Record playback history
GET /jsonrpc.js
?request={
  "jsonrpc": "2.0",
  "method": "slim.request",
  "params": ["<PLAYER_ID>", ["playlistid"]]
}

// Fetch track metadata
GET /jsonrpc.js
?request={
  "jsonrpc": "2.0",
  "method": "slim.request",
  "params": ["<PLAYER_ID>", ["songinfo", "0", "30"]]
}
```

**Learning Hook**: After each track completes, POST to LMS to log:
- Track ID
- Duration played
- Completion percentage
- Playlist context

### 2. Blueosand API Integration

**Endpoint Base**: `https://YOUR_DEVICE_IP:11000/` (or Blueosand cloud endpoint)

```javascript
// Authenticate
POST /api/v1/player/authenticate
{
  "macAddress": "<DEVICE_MAC>",
  "accessToken": "<BLUEOSAND_TOKEN>"
}

// Get currently playing track
GET /api/v1/playbackStatus

// Retrieve full playback history
GET /api/v1/playbackHistory
?limit=100&offset=0

// Log listening event
POST /api/v1/listening-events
{
  "trackId": "spotify:track:...",
  "duration": 240,
  "completedAt": "2025-04-19T14:32:00Z",
  "context": "eclectic_playlist"
}
```

### 3. LastFM Scraping & Scrobbling

**Endpoint Base**: `https://ws.audioscrobbler.com/2.0/`

```javascript
// Get user top tracks
GET /
?method=user.getTopTracks
&user=<USERNAME>
&period=3month
&limit=100
&api_key=<API_KEY>
&format=json

// Get track info with tags/attributes
GET /
?method=track.getInfo
&artist=<ARTIST>
&track=<TITLE>
&api_key=<API_KEY>
&format=json

// Get user listening history
GET /
?method=user.getRecentTracks
&user=<USERNAME>
&limit=100
&extended=1
&api_key=<API_KEY>
&format=json

// Scrobble a track (if using authenticated session)
POST /
method=track.scrobble
&artist=<ARTIST>
&track=<TITLE>
&timestamp=<UNIX_TIMESTAMP>
&sk=<SESSION_KEY>
&api_key=<API_KEY>
```

**Data Extraction**:
- Genre tags (from track.getInfo + user.getTopTracks)
- Play count history
- User affinity with artists
- Temporal patterns (morning vs. evening listening)

---

## Learning Algorithm

### Phase 1: Ingestion
```javascript
recordedEvent = {
  trackId: unique_id,
  metadata: {
    genre: [],
    bpm: number,
    bandMembers: number,
    members: [
      { name: 'Artist Name', instrument: 'role', joinedYear: 2000, previousBands: ['Band1', 'Band2'] },
      // ... more members
    ],
    acousticness: 0-1,
    danceability: 0-1,
    energy: 0-1,
    // ... all parameters
  },
  listening: {
    timestampStart: unix_epoch,
    timestampEnd: unix_epoch,
    completionRatio: 0.0-1.0,  // 0.8 = played 80%
    source: 'lms|blueosand|lastfm',
    context: 'playlist_name|radio|search',
    mood: 5,  // 1-10 mood scale at time of listening
    moodChangePattern: 'happy_to_calm'  // Optional: mood arc over session
  }
}
```

### Phase 2: Aggregation
```javascript
preferenceVector = {
  // Weighted averages
  avgBPM: sum(bpm * completionRatio) / totalWeight,
  
  // Categorical frequencies
  genreAffinity: {
    'indie': { count: 15, avg_completion: 0.87 },
    'jazz': { count: 3, avg_completion: 0.65 },
    // ...
  },
  
  // Member preferences
  musicianAffinity: {
    'David Gilmour': { count: 24, avg_completion: 0.92, preferred_moods: [5, 6, 7] },
    'Jon Lord': { count: 18, avg_completion: 0.88, preferred_moods: [2, 3, 5] },
  },
  
  memberTransitions: {
    'member_name': [
      { fromBand: 'X', toBand: 'Y', year: 2010 },
      // Tracks musician career movements
    ]
  },
  
  // Mood-based preferences
  moodPreferences: {
    1: { genres: ['happy pop', 'funk'], energy: 8, danceability: 7 },  // Euphoric
    5: { genres: ['indie', 'ambient'], energy: 4, danceability: 3 },    // Peaceful
    10: { genres: ['dark ambient', 'metal'], energy: 2, danceability: 1 }  // Dark
  },
  
  // Range preferences
  bpmRange: {
    lower: percentile(25, [bpm values]),
    median: percentile(50, [bpm values]),
    upper: percentile(75, [bpm values])
  },
  
  // Temporal patterns
  timingPreferences: {
    morningGenres: { ... },
    eveningGenres: { ... },
    weekendVsWeekday: { ... },
    moodByTimeOfDay: {  // New: mood patterns throughout day
      morning: 5,       // Peaceful
      afternoon: 3,     // Happy
      evening: 6,       // Calm
      night: 8          // Melancholic
    }
  }
}
```

### Phase 3: Playlist Generation
```javascript
generateEclectic(userPreferences, parameters, selectedMood) {
  let candidates = [];
  
  // Constrain search space
  genrePool = selectGenres(
    preferences: userPreferences.genreAffinity,
    moodAlignment: userPreferences.moodPreferences[selectedMood],
    diversity: parameters.genre,
    count: 50
  );
  
  // Member-based filtering
  memberPool = selectByMembers(
    favMusicians: userPreferences.musicianAffinity,
    moodAffinity: memberMoodMap,
    variety: parameters.bandMembers
  );
  
  // Filter by audio characteristics
  audioFilter = {
    bpm: genrePool.filter(
      bpm >= preferences.bpmRange.lower - (10 * parameters.bpm)
      && bpm <= preferences.bpmRange.upper + (10 * parameters.bpm)
    ),
    acousticness: normalise(parameters.acousticness, 0, 10, 0, 1),
    danceability: normalise(parameters.danceability, 0, 10, 0, 1),
    energy: moodToEnergy(selectedMood),  // Mood → energy mapping
    // ... apply all parameters
  };
  
  // Ensure variety constraints
  selectedTracks = greedySelect(
    candidates: audioFilter,
    constraints: {
      minGenreDiversity: parameters.genre,
      maxRepeatedArtists: 1,
      maxRepeatedMembers: 1,  // Don't overuse same musicians
      bpmSpread: parameters.bpm * 15,
      ensembleSizeVariety: parameters.bandMembers,
      moodAlignment: calculateMoodMatch(track, selectedMood)
    }
  );
  
  return selectedTracks[0:15];
}
```

---

## Implementation Checklist

### Backend Setup
- [ ] LMS JSON-RPC client implementation
- [ ] Blueosand API authentication & session management
- [ ] LastFM API client with rate limiting
- [ ] PostgreSQL schema for learning history
- [ ] Preference vector caching layer (Redis)

### Learning System
- [ ] Playback event listener/webhook
- [ ] Weighted aggregation pipeline
- [ ] Preference vector update scheduler
- [ ] Anomaly detection (one-off vs. pattern)

### Playlist Generation
- [ ] Track database/index (Elasticsearch or similar)
- [ ] Constraint satisfaction solver
- [ ] Diversity metrics calculation
- [ ] A/B testing framework for parameter tuning

### UI/Frontend
- [ ] Parameter sliders with preview
- [ ] Real-time learning statistics
- [ ] Playback history visualisation
- [ ] Genre/artist preference dashboard

---

## Security Considerations

1. **API Keys**: Store in environment variables, never hardcode
2. **LMS**: Use local network only; consider reverse proxy with auth
3. **LastFM**: Use OAuth2; don't store plaintext credentials
4. **Blueosand**: MAC address rotation; request approval for device access
5. **Data Privacy**: Anonymise listening data; GDPR/CCPA compliance

---

## Example Workflow

```javascript
// 1. User logs in
authenticateWith(['lms', 'blueosand', 'lastfm']);

// 2. Fetch recent history from all sources
lmsHistory = fetchLMS('/user/playbackHistory');
blueosHistory = fetchBlueosand('/api/v1/playbackHistory');
lastfmHistory = fetchLastFM('user.getRecentTracks');

// 3. Merge & deduplicate
mergedHistory = deduplicateByTrack([...lmsHistory, ...blueosHistory, ...lastfmHistory]);

// 4. Update preference vector
preferences = aggregatePreferences(mergedHistory);

// 5. User adjusts eclectic parameters
params = { genre: 7, bpm: 8, bandMembers: 6, danceability: 4, energy: 6 };

// 6. Generate playlist
playlist = generateEclectic(preferences, params);

// 7. User plays tracks; system learns
onTrackFinished((track, completionRatio) => {
  logPlayback(track, completionRatio);
  updatePreferences(track, completionRatio);
});
```

---

## References

- **Spotify Audio Features**: https://developer.spotify.com/documentation/web-api/reference/get-audio-features
- **LastFM API**: https://www.last.fm/api/
- **LMS JSON-RPC**: http://wiki.slimdevices.com/index.php/JSON-RPC_API
- **Music Information Retrieval**: https://ismir.net/
- **Diversity in Recommender Systems**: Vargas & Castells, 2014

