<p align="center">
  <h1 align="center">🔮 PROPHECY</h1>
  <p align="center"><strong>The first fully on-chain prediction market roguelite.</strong></p>
  <p align="center">
    <em>Swipe. Predict. Survive. Every bet is a transaction on Starknet.</em>
  </p>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Dojo-1.8-blue?style=flat-square" alt="Dojo" />
  <img src="https://img.shields.io/badge/Cairo-2.13-orange?style=flat-square" alt="Cairo" />
  <img src="https://img.shields.io/badge/Godot-4.6-478cbf?style=flat-square" alt="Godot" />
  <img src="https://img.shields.io/badge/Starknet-L2-purple?style=flat-square" alt="Starknet" />
  <img src="https://img.shields.io/badge/Cartridge-Controller-green?style=flat-square" alt="Cartridge" />
  <img src="https://img.shields.io/badge/Tests-9%2F9_passing-brightgreen?style=flat-square" alt="Tests" />
</p>

<p align="center">
  <strong>🏆 Built for Dojo Game Jam VIII — March 6-8, 2026</strong>
</p>

<p align="center">
  <a href="https://x.com/shariqshkt/status/2030780305104384343"><strong>Watch the Trailer</strong></a>
</p>

---

## 🎮 What is Prophecy?

Prophecy is a **prediction market roguelite** where you bet virtual currency on real-world trivia and live prediction markets — then try to survive 10 rounds without going bankrupt.

**The problem it solves:** Web3 games feel like spreadsheets. Prophecy makes on-chain transactions feel like *gameplay*. Every swipe is a signed Starknet transaction. Every prediction is an immutable bet. Every streak is verifiable on-chain.

**The hook:** You start with $10,000. Swipe right for YES. Swipe left for NO. Swipe up to SKIP. You have 30 seconds per card. If your balance hits $0, you're liquidated — game over.

### 🃏 Core Loop

```
Start Run ($10,000) → Swipe Cards (10 per round) → Earn/Lose → Round Summary
     ↓                                                              ↓
  Liquidated ←── Balance hits $0                    Next Round → Harder Markets
     ↓                                                              ↓
  Leaderboard                                              Dark Pool Shop (Relics)
```

**75 markets** — 50 pre-resolved trivia (instant settlement) + 25 live prediction markets (settle when resolved).

### 🔥 Streak System

| Streak | Tier | Effect |
|--------|------|--------|
| 2x | 🔥 HOT HAND | Confidence boost |
| 4x | 🔥🔥 ON FIRE | Momentum building |
| 7x | 👁️ ORACLE | Flow State — camera zoom, shader overdrive |

At 3+ combo, **Flow State** activates: camera zoom 1.03x, shader speed 3x. Miss a prediction and the screen *shatters*.

---

## ⚡ Tech Flex

### 🎮 Cartridge Session Keys — Popup-Free Rapid Fire

```
Traditional Web3 Game:        Prophecy:
Click → Wallet popup →        Swipe → Instant TX →
Confirm → Wait → Result       Result in <1s
(5-10 seconds per action)     (Popup-free after first auth)
```

Cartridge Controller creates a **session key** on first connection. Every subsequent transaction (`place_prediction`, `buy_relic`, `cash_out_early`, `bet_world_boss`) executes instantly — no wallet popups, no confirmation dialogs. The game feels like a native mobile app, not a dApp.

### 📡 Torii Indexer — Global State Sync

Torii provides real-time entity subscriptions via gRPC. The Godot client subscribes once and receives **push updates** for every model change across all players:

- **Spectator Mode** — Watch any player's live positions
- **World Boss** — Global shared prediction market with live bet feed and ring buffer of recent bettors
- **Judgment Day** — Hidden admin panel (Ctrl+Shift+O) resolves live markets in real-time during demo. All connected clients see results instantly via Torii sync.

### 🏗️ Dojo ECS Architecture

**6 Models** — Pure on-chain state, zero off-chain logic:

| Model | Key | Purpose |
|-------|-----|---------|
| `Market` | `market_id` | Odds, resolution status, pool totals |
| `Position` | `(player, market_id)` | Player's bet on a specific market |
| `Trader` | `address` | Balance, stats, streak tracking |
| `Relics` | `address` | Power-up inventory (Leverage, Stop Loss, Insider Info) |
| `WorldBoss` | `boss_id` | Global shared market with recent bettor ring buffer |
| `LeaderboardEntry` | `address` | High score, best streak, total runs |

**9 System Actions** — All game logic lives in Cairo:

| Action | What it does |
|--------|-------------|
| `create_trader` | Initialize with $10,000 virtual balance |
| `create_market` | Admin creates market with YES/NO odds |
| `place_prediction` | Bet on market — auto-settles if pre-resolved |
| `resolve_market` | Oracle resolves open market |
| `claim` | Settle position after market resolution |
| `cash_out_early` | Dynamic exit (50-150% of wager based on market sentiment) |
| `buy_relic` | Purchase power-ups from Dark Pool Shop |
| `bet_world_boss` | Bet on the global shared prediction |
| `init_world_boss` | Initialize the World Boss market |

### 🎨 Godot Client — Not Your Average Web3 Frontend

- **Volumetric nebula shader** — 3-octave FBM with film grain, vignette, and biome-based color palettes
- **Procedural audio engine** — All SFX generated at runtime via `AudioStreamWAV` (zero external audio files)
- **Audio bus architecture** — Master → SFX + Ambience buses with dynamic ducking on impacts
- **Ambient drone** — Looping sub-bass (40Hz + 60Hz harmonic) with LFO-modulated noise
- **Cinematic intro** — Terminal typing sequence with per-character sound, color-coded output, bass drop reveal
- **Tween-based juice** — Card flip reveals, hit pause on settlement, floating balance text, button hover scaling, streak punch animations, glass shatter on flow state break
- **Dynamic card tinting** — Cards glow green (YES) or red (NO) as you drag
- **Hot-swappable market data** — Markets loaded from `data/markets.json` at runtime (no client rebuild needed)

---

## 📁 Project Structure

```
prophecy-roguelite/
├── contracts/                      # Cairo smart contracts (Dojo ECS)
│   ├── src/
│   │   ├── models.cairo            # 6 on-chain models
│   │   ├── systems/actions.cairo   # 9 system actions (all game logic)
│   │   └── tests/test_world.cairo  # 9 integration tests (all passing)
│   ├── Scarb.toml                  # Dojo 1.8 + Cairo 2.13
│   └── dojo_dev.toml               # Local dev config
│
├── game/                           # Godot 4.6 client
│   ├── scripts/
│   │   ├── game_manager.gd         # Dojo connection, state sync, action dispatch
│   │   ├── main_game.gd            # UI controller, animations, 8-panel roguelite flow
│   │   └── sfx.gd                  # Procedural audio engine (12 sound types)
│   ├── data/
│   │   └── markets.json            # 75 markets (hot-swappable, no rebuild needed)
│   ├── shaders/
│   │   └── dungeon_bg.gdshader     # Volumetric nebula background
│   ├── scenes/main.tscn            # Single-scene architecture
│   ├── connection/
│   │   └── dojo_connection.gd      # Torii + Katana + Controller bridge
│   └── addons/godot-dojo/          # GDExtension plugin (v0.7.3)
│
└── README.md
```

---

## 🚀 Running Locally

### Prerequisites

- [Dojo](https://dojoengine.org) v1.8.6+ — install via `dojoup`
- [Godot](https://godotengine.org) 4.6+ — with GDExtension support

### 3 Steps

```bash
# 1. Deploy contracts to local Katana
cd contracts
katana --dev --dev.no-fee --http.cors_origins "*" &
sozo build && sozo migrate

# 2. Start Torii indexer (use the world address from migrate output)
torii --world <WORLD_ADDRESS> --http.cors_origins "*" &

# 3. Open Godot and hit Play
cd ../game
godot --path .
```

### Deployed on Slot (Live)

The game is deployed on Cartridge Slot infrastructure:

```
Katana RPC:  https://api.cartridge.gg/x/prophecy-roguelite/katana
Torii:       https://api.cartridge.gg/x/prophecy-roguelite/torii
```

---

## 🖥️ Platform Support

Prophecy runs as a **native desktop application** (macOS, Windows, Linux). The Dojo GDExtension plugin includes native binaries for all desktop platforms.

> **Note:** The GDExtension `.gdextension` config declares web/WASM targets, but the WebAssembly binaries are not yet shipped with the current plugin release (v0.7.3). For the game jam, **download the release binary** or run from the Godot editor. Web export will be available in a future plugin update.

---

## 🧪 Tests

All 9 Cairo integration tests pass:

```
$ cd contracts && sozo test

running 9 tests
test test_create_trader ............. ok
test test_create_market ............. ok
test test_place_prediction .......... ok
test test_place_prediction_auto_settle ok
test test_claim_correct ............. ok
test test_claim_wrong ............... ok
test test_cannot_double_bet ......... ok
test test_cash_out_early ............ ok
test test_leaderboard_update ........ ok

test result: ok. 9 passed; 0 failed
```

Tests cover: trader creation, market creation, prediction placement, auto-settlement on pre-resolved markets, correct/wrong claim payouts, double-bet prevention, early cash-out with dynamic pricing, and leaderboard updates.

---

## 🎯 Design Decisions

| Decision | Why |
|----------|-----|
| **Swipe UX over click** | Mobile-native feel, faster gameplay loop, gesture = commitment |
| **Pre-resolved markets** | Instant gratification — no waiting for real-world outcomes during a jam demo |
| **Virtual currency** | Zero financial risk, pure gameplay. $10K start creates urgency without real stakes |
| **Roguelite structure** | Rounds of 10 create natural tension arcs. Liquidation = permadeath = drama |
| **Procedural audio** | Zero external dependencies. Every sound synthesized at runtime. Pitch randomization prevents repetition |
| **JSON market data** | Decouple content from code. Swap markets via API/IPFS without client updates |
| **Dynamic cash-out pricing** | Contrarian positions worth more. Creates real market dynamics even in a game |

---

## 👤 Author

**Shariq** — Built solo in 48 hours for Dojo Game Jam VIII.

---

<p align="center">
  <em>Every prediction is on-chain. Every streak is verifiable. Every liquidation is permanent.</em>
</p>
