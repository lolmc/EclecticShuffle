import React, { useState, useEffect } from 'react';
import { Music, Sliders, Play, Plus, TrendingUp, Target, Settings, RotateCcw } from 'lucide-react';

export default function MusicDiscovery() {
  // Eclectic playlist parameters
  const [parameters, setParameters] = useState({
    genre: 5,
    bpm: 5,
    bandMembers: 5,
    acousticness: 5,
    danceability: 5,
    energy: 5,
    instrumentalness: 5,
    liveness: 5,
    speechiness: 5,
    explicitness: 5,
  });

  // Learning system
  const [playbackHistory, setPlaybackHistory] = useState([]);
  const [preferences, setPreferences] = useState({
    favGenres: {},
    favBPMRange: [80, 140],
    favBandSizes: {},
    recentlyPlayed: [],
    favMembers: {},  // Track preferred musicians
    memberTransitions: {},  // Track musicians across bands
  });

  // Mood tracking
  const moods = [
    { label: 'Euphoric', value: 1, color: '#FFD700', emoji: '😄' },
    { label: 'Energetic', value: 2, color: '#FF6B6B', emoji: '⚡' },
    { label: 'Happy', value: 3, color: '#FFA500', emoji: '😊' },
    { label: 'Upbeat', value: 4, color: '#FECA57', emoji: '🎉' },
    { label: 'Peaceful', value: 5, color: '#87CEEB', emoji: '☮️' },
    { label: 'Calm', value: 6, color: '#87CEEB', emoji: '😌' },
    { label: 'Contemplative', value: 7, color: '#6B8E99', emoji: '🤔' },
    { label: 'Melancholic', value: 8, color: '#4B0082', emoji: '😢' },
    { label: 'Sad', value: 9, color: '#2F4F7F', emoji: '💔' },
    { label: 'Dark', value: 10, color: '#0F0C29', emoji: '🌑' },
  ];

  const [selectedMood, setSelectedMood] = useState(5);

  const [playlist, setPlaylist] = useState([]);
  const [selectedTrack, setSelectedTrack] = useState(null);
  const [apiConfig, setApiConfig] = useState({
    lmsUrl: 'http://localhost:9000',
    lastfmUsername: '',
    blueosMac: '',
    apiKey: '',
  });

  const [showAdvanced, setShowAdvanced] = useState(false);
  const [stats, setStats] = useState({ tracksLearned: 0, playlistsCreated: 0 });

  // Learn from playback
  const recordPlayback = (track, duration) => {
    const newHistory = [...playbackHistory, { ...track, timestamp: Date.now(), duration, mood: selectedMood }];
    setPlaybackHistory(newHistory);
    stats.tracksLearned += 1;

    // Update preferences based on listening history
    updateLearningPreferences(newHistory);
  };

  // Analyse listening patterns including band member movements
  const updateLearningPreferences = (history) => {
    if (history.length === 0) return;

    const genreWeights = {};
    const bandSizeWeights = {};
    const memberWeights = {};
    const memberTransitionMap = {};
    let totalBPM = 0;
    let bpmCount = 0;

    history.forEach((track) => {
      if (track.genre) {
        genreWeights[track.genre] = (genreWeights[track.genre] || 0) + 1;
      }
      if (track.bandMembers) {
        bandSizeWeights[track.bandMembers] = (bandSizeWeights[track.bandMembers] || 0) + 1;
      }
      if (track.bpm) {
        totalBPM += track.bpm;
        bpmCount += 1;
      }
      
      // Track individual band members
      if (track.members && Array.isArray(track.members)) {
        track.members.forEach((member) => {
          memberWeights[member.name] = (memberWeights[member.name] || 0) + 1;
          
          // Track member transitions between bands
          if (member.previousBands && Array.isArray(member.previousBands)) {
            const memberKey = member.name;
            if (!memberTransitionMap[memberKey]) {
              memberTransitionMap[memberKey] = [];
            }
            memberTransitionMap[memberKey].push({
              currentBand: track.artist,
              previousBands: member.previousBands,
              joinedYear: member.joinedYear,
              leftYear: member.leftYear,
            });
          }
        });
      }
    });

    setPreferences((prev) => ({
      ...prev,
      favGenres: genreWeights,
      favBandSizes: bandSizeWeights,
      favMembers: memberWeights,
      memberTransitions: memberTransitionMap,
      favBPMRange: bpmCount > 0 ? [totalBPM / bpmCount - 20, totalBPM / bpmCount + 20] : [80, 140],
      recentlyPlayed: history.slice(-10),
    }));
  };

  // Generate eclectic playlist using parameters
  const generatePlaylist = async () => {
    try {
      const currentMood = moods.find(m => m.value === selectedMood);
      const favMembersList = Object.entries(preferences.favMembers)
        .sort(([, a], [, b]) => b - a)
        .slice(0, 10)
        .map(([member]) => member);

      const response = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: 'claude-sonnet-4-20250514',
          max_tokens: 1000,
          messages: [
            {
              role: 'user',
              content: `Generate an eclectic music playlist with the following parameters (1-10 scale where 5 is balanced):
              
              MOOD: ${currentMood.label} (${currentMood.emoji})
              Genre Variety: ${parameters.genre} (1=single genre, 10=wildly mixed)
              BPM Variety: ${parameters.bpm} (1=consistent tempo, 10=tempo chaos)
              Band Size Variety: ${parameters.bandMembers} (1=solo artists, 10=orchestras)
              Acousticness: ${parameters.acousticness}
              Danceability: ${parameters.danceability}
              Energy: ${parameters.energy}
              Instrumentalness: ${parameters.instrumentalness}
              Liveness: ${parameters.liveness}
              Speechiness: ${parameters.speechiness}
              Explicitness: ${parameters.explicitness}
              
              User Preferences:
              Favourite Genres: ${Object.keys(preferences.favGenres).slice(0, 5).join(', ') || 'None yet'}
              Favourite Musicians: ${favMembersList.join(', ') || 'None yet'}
              BPM Range: ${preferences.favBPMRange[0].toFixed(0)}-${preferences.favBPMRange[1].toFixed(0)}
              
              Musical Context for Mood: For a ${currentMood.label} mood, prioritise tracks that evoke this emotional state whilst respecting user's parameter preferences.
              
              Return ONLY a JSON array of 15 tracks with fields: title, artist, genre, bpm, bandMembers, year, explicitness, acousticness, danceability, energy, members (array of {name, instrument, joinedYear, previousBands}), moodAlign (1-10 how well it matches the selected mood).`,
            },
          ],
        }),
      });

      const data = await response.json();
      const responseText = data.content[0].text.replace(/```json|```/g, '').trim();
      const tracks = JSON.parse(responseText);
      setPlaylist(tracks);
      stats.playlistsCreated += 1;
    } catch (error) {
      console.error('Playlist generation error:', error);
    }
  };

  // Reset preferences
  const resetLearning = () => {
    setPlaybackHistory([]);
    setPreferences({
      favGenres: {},
      favBPMRange: [80, 140],
      favBandSizes: {},
      recentlyPlayed: [],
    });
    setStats({ tracksLearned: 0, playlistsCreated: 0 });
  };

  // Parameter slider component
  const ParamSlider = ({ label, value, onChange, description }) => (
    <div className="param-slider">
      <div className="param-header">
        <span className="param-label">{label}</span>
        <span className="param-value">{value}</span>
      </div>
      <input
        type="range"
        min="1"
        max="10"
        value={value}
        onChange={(e) => onChange(parseInt(e.target.value))}
        className="slider"
      />
      <p className="param-description">{description}</p>
    </div>
  );

  return (
    <div className="music-discovery">
      <style>{`
        * {
          margin: 0;
          padding: 0;
          box-sizing: border-box;
        }

        .music-discovery {
          min-height: 100vh;
          background: linear-gradient(135deg, #0f0c29, #302b63, #24243e);
          color: #e0e0e0;
          font-family: 'Courier New', monospace;
          padding: 20px;
          overflow-x: hidden;
        }

        .header {
          display: flex;
          align-items: center;
          gap: 15px;
          margin-bottom: 30px;
          animation: slideDown 0.6s ease-out;
        }

        .header-icon {
          width: 50px;
          height: 50px;
          background: linear-gradient(135deg, #ff6b6b, #feca57);
          border-radius: 8px;
          display: flex;
          align-items: center;
          justify-content: center;
          box-shadow: 0 8px 24px rgba(255, 107, 107, 0.3);
        }

        .header h1 {
          font-size: 2.5em;
          font-weight: bold;
          letter-spacing: 2px;
          background: linear-gradient(90deg, #ff6b6b, #feca57);
          -webkit-background-clip: text;
          -webkit-text-fill-color: transparent;
        }

        .container {
          max-width: 1200px;
          margin: 0 auto;
        }

        .grid {
          display: grid;
          grid-template-columns: 1fr 1fr;
          gap: 30px;
          margin-bottom: 30px;
        }

        @media (max-width: 768px) {
          .grid {
            grid-template-columns: 1fr;
          }
        }

        .panel {
          background: rgba(48, 43, 99, 0.4);
          border: 1px solid rgba(255, 107, 107, 0.2);
          border-radius: 12px;
          padding: 25px;
          backdrop-filter: blur(10px);
          box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
        }

        .panel-title {
          display: flex;
          align-items: center;
          gap: 10px;
          font-size: 1.3em;
          font-weight: bold;
          margin-bottom: 20px;
          color: #feca57;
          text-transform: uppercase;
          letter-spacing: 1px;
        }

        .param-slider {
          margin-bottom: 20px;
          padding-bottom: 20px;
          border-bottom: 1px solid rgba(255, 107, 107, 0.1);
        }

        .param-slider:last-child {
          border-bottom: none;
        }

        .param-header {
          display: flex;
          justify-content: space-between;
          align-items: center;
          margin-bottom: 8px;
        }

        .param-label {
          font-weight: bold;
          color: #ff6b6b;
        }

        .param-value {
          background: rgba(255, 107, 107, 0.2);
          padding: 4px 12px;
          border-radius: 20px;
          font-size: 0.9em;
          color: #feca57;
        }

        .slider {
          width: 100%;
          height: 6px;
          border-radius: 3px;
          background: linear-gradient(90deg, rgba(255, 107, 107, 0.2), rgba(254, 202, 87, 0.2));
          outline: none;
          -webkit-appearance: none;
          appearance: none;
          cursor: pointer;
        }

        .slider::-webkit-slider-thumb {
          -webkit-appearance: none;
          appearance: none;
          width: 18px;
          height: 18px;
          border-radius: 50%;
          background: linear-gradient(135deg, #ff6b6b, #feca57);
          cursor: pointer;
          box-shadow: 0 4px 12px rgba(255, 107, 107, 0.5);
        }

        .slider::-moz-range-thumb {
          width: 18px;
          height: 18px;
          border-radius: 50%;
          background: linear-gradient(135deg, #ff6b6b, #feca57);
          cursor: pointer;
          border: none;
          box-shadow: 0 4px 12px rgba(255, 107, 107, 0.5);
        }

        .param-description {
          font-size: 0.8em;
          color: #999;
          margin-top: 6px;
          font-style: italic;
        }

        .button-group {
          display: flex;
          gap: 12px;
          margin-top: 25px;
          flex-wrap: wrap;
        }

        .btn {
          flex: 1;
          min-width: 150px;
          padding: 12px 20px;
          border: none;
          border-radius: 8px;
          font-weight: bold;
          cursor: pointer;
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 8px;
          font-size: 0.95em;
          transition: all 0.3s ease;
          text-transform: uppercase;
          letter-spacing: 1px;
        }

        .btn-primary {
          background: linear-gradient(135deg, #ff6b6b, #feca57);
          color: #0f0c29;
        }

        .btn-primary:hover {
          transform: translateY(-2px);
          box-shadow: 0 8px 24px rgba(255, 107, 107, 0.4);
        }

        .btn-secondary {
          background: rgba(255, 107, 107, 0.1);
          border: 1px solid #ff6b6b;
          color: #ff6b6b;
        }

        .btn-secondary:hover {
          background: rgba(255, 107, 107, 0.2);
        }

        .stats {
          display: grid;
          grid-template-columns: repeat(2, 1fr);
          gap: 12px;
          margin-top: 20px;
        }

        .stat-item {
          background: rgba(254, 202, 87, 0.1);
          border: 1px solid rgba(254, 202, 87, 0.2);
          padding: 15px;
          border-radius: 8px;
          text-align: center;
        }

        .stat-value {
          font-size: 1.8em;
          font-weight: bold;
          color: #feca57;
        }

        .stat-label {
          font-size: 0.8em;
          color: #999;
          margin-top: 4px;
          text-transform: uppercase;
        }

        .track-list {
          display: flex;
          flex-direction: column;
          gap: 12px;
          max-height: 500px;
          overflow-y: auto;
        }

        .track-item {
          background: rgba(255, 107, 107, 0.05);
          border: 1px solid rgba(255, 107, 107, 0.2);
          padding: 15px;
          border-radius: 8px;
          cursor: pointer;
          transition: all 0.3s ease;
          animation: fadeIn 0.4s ease-out backwards;
        }

        .track-item:hover {
          background: rgba(255, 107, 107, 0.15);
          border-color: #ff6b6b;
          transform: translateX(4px);
        }

        .track-title {
          font-weight: bold;
          color: #feca57;
          margin-bottom: 4px;
        }

        .track-meta {
          font-size: 0.85em;
          color: #aaa;
          display: flex;
          gap: 12px;
          flex-wrap: wrap;
        }

        .meta-tag {
          background: rgba(254, 202, 87, 0.1);
          padding: 2px 8px;
          border-radius: 4px;
          border-left: 2px solid #feca57;
        }

        .track-detail {
          background: rgba(48, 43, 99, 0.6);
          border: 1px solid rgba(254, 202, 87, 0.3);
          padding: 20px;
          border-radius: 8px;
          margin-top: 20px;
        }

        .detail-grid {
          display: grid;
          grid-template-columns: repeat(2, 1fr);
          gap: 15px;
          margin-top: 15px;
        }

        .detail-item {
          background: rgba(255, 107, 107, 0.05);
          padding: 10px;
          border-radius: 6px;
          border-left: 2px solid #ff6b6b;
        }

        .detail-label {
          font-size: 0.8em;
          color: #999;
          text-transform: uppercase;
        }

        .detail-value {
          font-weight: bold;
          color: #feca57;
          margin-top: 4px;
        }

        .preferences-panel {
          background: rgba(254, 202, 87, 0.05);
          border: 1px solid rgba(254, 202, 87, 0.2);
          padding: 15px;
          border-radius: 8px;
          margin-top: 15px;
        }

        .pref-title {
          color: #feca57;
          font-weight: bold;
          margin-bottom: 10px;
          text-transform: uppercase;
          font-size: 0.9em;
        }

        .pref-list {
          display: flex;
          flex-wrap: wrap;
          gap: 8px;
        }

        .pref-tag {
          background: rgba(255, 107, 107, 0.2);
          color: #ff6b6b;
          padding: 6px 12px;
          border-radius: 20px;
          font-size: 0.85em;
          border: 1px solid rgba(255, 107, 107, 0.4);
        }

        .toggle-btn {
          background: rgba(254, 202, 87, 0.1);
          border: 1px solid #feca57;
          color: #feca57;
          padding: 8px 16px;
          border-radius: 6px;
          cursor: pointer;
          margin-top: 15px;
          font-weight: bold;
        }

        @keyframes slideDown {
          from {
            opacity: 0;
            transform: translateY(-20px);
          }
          to {
            opacity: 1;
            transform: translateY(0);
          }
        }

        @keyframes fadeIn {
          from {
            opacity: 0;
            transform: translateX(-10px);
          }
          to {
            opacity: 1;
            transform: translateX(0);
          }
        }

        .scrollbar {
          scrollbar-width: thin;
          scrollbar-color: rgba(255, 107, 107, 0.4) rgba(48, 43, 99, 0.2);
        }

        .scrollbar::-webkit-scrollbar {
          width: 6px;
        }

        .scrollbar::-webkit-scrollbar-track {
          background: rgba(48, 43, 99, 0.2);
        }

        .scrollbar::-webkit-scrollbar-thumb {
          background: rgba(255, 107, 107, 0.4);
          border-radius: 3px;
        }

        .scrollbar::-webkit-scrollbar-thumb:hover {
          background: rgba(255, 107, 107, 0.6);
        }
      `}</style>

      <div className="container">
        <div className="header">
          <div className="header-icon">
            <Music size={32} color="#0f0c29" />
          </div>
          <h1>ECLECTIC HARMONY</h1>
        </div>

        <div className="grid">
          {/* Mood Selector */}
          <div className="panel" style={{ gridColumn: '1 / -1' }}>
            <div className="panel-title">
              <Target size={20} />
              Current Mood
            </div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '10px', marginBottom: '20px' }}>
              {moods.map((mood) => (
                <button
                  key={mood.value}
                  onClick={() => setSelectedMood(mood.value)}
                  style={{
                    padding: '12px 16px',
                    borderRadius: '8px',
                    border: selectedMood === mood.value ? '2px solid #feca57' : '1px solid rgba(254, 202, 87, 0.2)',
                    background: selectedMood === mood.value ? `rgba(${parseInt(mood.color.slice(1, 3), 16)}, ${parseInt(mood.color.slice(3, 5), 16)}, ${parseInt(mood.color.slice(5, 7), 16)}, 0.2)` : 'rgba(254, 202, 87, 0.05)',
                    color: selectedMood === mood.value ? mood.color : '#aaa',
                    cursor: 'pointer',
                    fontWeight: selectedMood === mood.value ? 'bold' : 'normal',
                    transition: 'all 0.3s ease',
                    fontSize: '0.9em',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px',
                  }}
                >
                  {mood.emoji} {mood.label}
                </button>
              ))}
            </div>
          </div>

          {/* Parameters Panel */}
          <div className="panel">
            <div className="panel-title">
              <Sliders size={20} />
              Parameters
            </div>

            <ParamSlider
              label="Genre Variety"
              value={parameters.genre}
              onChange={(val) => setParameters({ ...parameters, genre: val })}
              description="1 = Single genre, 10 = Wildly mixed styles"
            />
            <ParamSlider
              label="BPM Variety"
              value={parameters.bpm}
              onChange={(val) => setParameters({ ...parameters, bpm: val })}
              description="1 = Consistent tempo, 10 = Tempo chaos"
            />
            <ParamSlider
              label="Band Members"
              value={parameters.bandMembers}
              onChange={(val) => setParameters({ ...parameters, bandMembers: val })}
              description="1 = Solo artists, 10 = Large ensembles"
            />
            <ParamSlider
              label="Danceability"
              value={parameters.danceability}
              onChange={(val) => setParameters({ ...parameters, danceability: val })}
              description="1 = Non-danceable, 10 = Highly rhythmic"
            />
            <ParamSlider
              label="Energy"
              value={parameters.energy}
              onChange={(val) => setParameters({ ...parameters, energy: val })}
              description="1 = Calm, 10 = Intense"
            />

            <button className="toggle-btn" onClick={() => setShowAdvanced(!showAdvanced)}>
              {showAdvanced ? '— Advanced' : '+ Advanced'}
            </button>

            {showAdvanced && (
              <>
                <ParamSlider
                  label="Acousticness"
                  value={parameters.acousticness}
                  onChange={(val) => setParameters({ ...parameters, acousticness: val })}
                  description="1 = Electric, 10 = Acoustic"
                />
                <ParamSlider
                  label="Instrumentalness"
                  value={parameters.instrumentalness}
                  onChange={(val) => setParameters({ ...parameters, instrumentalness: val })}
                  description="1 = Vocals, 10 = Pure instrumental"
                />
                <ParamSlider
                  label="Liveness"
                  value={parameters.liveness}
                  onChange={(val) => setParameters({ ...parameters, liveness: val })}
                  description="1 = Studio, 10 = Live performance"
                />
                <ParamSlider
                  label="Speechiness"
                  value={parameters.speechiness}
                  onChange={(val) => setParameters({ ...parameters, speechiness: val })}
                  description="1 = Music, 10 = Speech/podcast"
                />
                <ParamSlider
                  label="Explicitness"
                  value={parameters.explicitness}
                  onChange={(val) => setParameters({ ...parameters, explicitness: val })}
                  description="1 = Clean, 10 = Explicit"
                />
              </>
            )}

            <div className="button-group">
              <button className="btn btn-primary" onClick={generatePlaylist}>
                <Play size={16} /> Generate Playlist
              </button>
              <button className="btn btn-secondary" onClick={resetLearning}>
                <RotateCcw size={16} /> Reset
              </button>
            </div>
          </div>

          {/* Learning & Stats Panel */}
          <div className="panel">
            <div className="panel-title">
              <TrendingUp size={20} />
              Learning Profile
            </div>

            <div className="stats">
              <div className="stat-item">
                <div className="stat-value">{stats.tracksLearned}</div>
                <div className="stat-label">Tracks Analysed</div>
              </div>
              <div className="stat-item">
                <div className="stat-value">{stats.playlistsCreated}</div>
                <div className="stat-label">Playlists Created</div>
              </div>
            </div>

            {Object.keys(preferences.favGenres).length > 0 && (
              <div className="preferences-panel">
                <div className="pref-title">Favourite Genres</div>
                <div className="pref-list">
                  {Object.entries(preferences.favGenres)
                    .sort(([, a], [, b]) => b - a)
                    .slice(0, 6)
                    .map(([genre, count]) => (
                      <div key={genre} className="pref-tag">
                        {genre} ({count})
                      </div>
                    ))}
                </div>
              </div>
            )}

            {preferences.favBandSizes && Object.keys(preferences.favBandSizes).length > 0 && (
              <div className="preferences-panel">
                <div className="pref-title">Band Size Distribution</div>
                <div className="pref-list">
                  {Object.entries(preferences.favBandSizes)
                    .sort(([, a], [, b]) => b - a)
                    .slice(0, 5)
                    .map(([size, count]) => (
                      <div key={size} className="pref-tag">
                        {size} members ({count})
                      </div>
                    ))}
                </div>
              </div>
            )}

            {Object.keys(preferences.favMembers).length > 0 && (
              <div className="preferences-panel">
                <div className="pref-title">Favourite Musicians</div>
                <div className="pref-list">
                  {Object.entries(preferences.favMembers)
                    .sort(([, a], [, b]) => b - a)
                    .slice(0, 8)
                    .map(([member, count]) => (
                      <div key={member} className="pref-tag" title={`Heard ${count} times`}>
                        🎵 {member} ({count})
                      </div>
                    ))}
                </div>
              </div>
            )}

            {Object.keys(preferences.memberTransitions).length > 0 && (
              <div className="preferences-panel">
                <div className="pref-title">Member Movements</div>
                <div style={{ fontSize: '0.8em', color: '#aaa', marginTop: '8px', maxHeight: '120px', overflowY: 'auto' }}>
                  {Object.entries(preferences.memberTransitions)
                    .slice(0, 5)
                    .map(([member, transitions]) => (
                      <div key={member} style={{ marginBottom: '8px', paddingBottom: '8px', borderBottom: '1px solid rgba(254, 202, 87, 0.1)' }}>
                        <div style={{ color: '#feca57', fontWeight: 'bold', marginBottom: '4px' }}>{member}</div>
                        {transitions.slice(-1).map((t, idx) => (
                          <div key={idx}>
                            Now in <span style={{ color: '#ff6b6b' }}>{t.currentBand}</span>
                            {t.previousBands && t.previousBands.length > 0 && (
                              <div style={{ fontSize: '0.75em', marginTop: '2px' }}>
                                Previously: {t.previousBands.join(', ')}
                              </div>
                            )}
                          </div>
                        ))}
                      </div>
                    ))}
                </div>
              </div>
            )}

            {preferences.recentlyPlayed.length > 0 && (
              <div className="preferences-panel">
                <div className="pref-title">Recently Analysed</div>
                <div style={{ fontSize: '0.85em', color: '#aaa', marginTop: '8px' }}>
                  Last 10 tracks tracked and analysed
                </div>
              </div>
            )}

            <div className="preferences-panel" style={{ marginTop: '20px' }}>
              <div className="pref-title">Detected BPM Range</div>
              <div className="detail-value">
                {preferences.favBPMRange[0].toFixed(0)} - {preferences.favBPMRange[1].toFixed(0)} BPM
              </div>
            </div>
          </div>
        </div>

        {/* Playlist Results */}
        {playlist.length > 0 && (
          <div className="panel">
            <div className="panel-title">
              <Music size={20} />
              Generated Playlist ({playlist.length} Tracks)
            </div>

            <div className="track-list scrollbar">
              {playlist.map((track, idx) => (
                <div
                  key={idx}
                  className="track-item"
                  onClick={() => {
                    setSelectedTrack(track);
                    recordPlayback(track, 180);
                  }}
                >
                  <div className="track-title">
                    {idx + 1}. {track.title}
                  </div>
                  <div className="track-meta">
                    <span className="meta-tag">{track.artist}</span>
                    <span className="meta-tag">{track.genre}</span>
                    <span className="meta-tag">{track.bpm} BPM</span>
                    <span className="meta-tag">{track.bandMembers} members</span>
                  </div>
                </div>
              ))}
            </div>

            {selectedTrack && (
              <div className="track-detail">
                <div style={{ marginBottom: '10px' }}>
                  <div className="track-title">{selectedTrack.title}</div>
                  <div className="track-meta">
                    <span className="meta-tag">{selectedTrack.artist}</span>
                    <span className="meta-tag">{selectedTrack.year}</span>
                  </div>
                </div>
                <div className="detail-grid">
                  <div className="detail-item">
                    <div className="detail-label">Genre</div>
                    <div className="detail-value">{selectedTrack.genre}</div>
                  </div>
                  <div className="detail-item">
                    <div className="detail-label">BPM</div>
                    <div className="detail-value">{selectedTrack.bpm}</div>
                  </div>
                  <div className="detail-item">
                    <div className="detail-label">Band Members</div>
                    <div className="detail-value">{selectedTrack.bandMembers}</div>
                  </div>
                  <div className="detail-item">
                    <div className="detail-label">Mood Alignment</div>
                    <div className="detail-value">{selectedTrack.moodAlign || 'N/A'}/10</div>
                  </div>
                  <div className="detail-item">
                    <div className="detail-label">Energy</div>
                    <div className="detail-value">{selectedTrack.energy}/10</div>
                  </div>
                  <div className="detail-item">
                    <div className="detail-label">Danceability</div>
                    <div className="detail-value">{selectedTrack.danceability}/10</div>
                  </div>
                  <div className="detail-item">
                    <div className="detail-label">Acousticness</div>
                    <div className="detail-value">{selectedTrack.acousticness}/10</div>
                  </div>
                  <div className="detail-item">
                    <div className="detail-label">Liveness</div>
                    <div className="detail-value">{selectedTrack.liveness || 'N/A'}/10</div>
                  </div>
                </div>

                {selectedTrack.members && selectedTrack.members.length > 0 && (
                  <div style={{ marginTop: '15px', paddingTop: '15px', borderTop: '1px solid rgba(254, 202, 87, 0.2)' }}>
                    <div style={{ color: '#feca57', fontWeight: 'bold', marginBottom: '10px', textTransform: 'uppercase', fontSize: '0.9em' }}>
                      Band Members
                    </div>
                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(150px, 1fr))', gap: '10px' }}>
                      {selectedTrack.members.map((member, idx) => (
                        <div key={idx} style={{ background: 'rgba(255, 107, 107, 0.05)', border: '1px solid rgba(255, 107, 107, 0.2)', padding: '10px', borderRadius: '6px' }}>
                          <div style={{ color: '#ff6b6b', fontWeight: 'bold', fontSize: '0.9em', marginBottom: '4px' }}>
                            {member.name}
                          </div>
                          <div style={{ fontSize: '0.8em', color: '#999' }}>{member.instrument || 'Musician'}</div>
                          {member.joinedYear && (
                            <div style={{ fontSize: '0.75em', color: '#666', marginTop: '4px' }}>
                              Joined: {member.joinedYear}
                            </div>
                          )}
                          {member.previousBands && member.previousBands.length > 0 && (
                            <div style={{ fontSize: '0.7em', color: '#666', marginTop: '4px', fontStyle: 'italic' }}>
                              Previously: {member.previousBands.slice(0, 2).join(', ')}
                              {member.previousBands.length > 2 && ` (+${member.previousBands.length - 2})`}
                            </div>
                          )}
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
