# Prophecy Roguelite — Dojo Game Jam VIII Build Guide

## CONTEXT

You are building a game for the **Dojo Game Jam VIII** (March 6-8, 2026). Prize pool: **$15,000**. 80 submissions, 818 hackers. The developer (Shariq) has experience with Cairo/Starknet from building Veil Protocol (privacy protocol deployed on Starknet mainnet), and recently won 3rd place ($1,000) in the Tapestry track of the Solana Graveyard Hackathon with Umanity. He has NO game dev experience but is using Claude Opus (max subscription) to build. Time budget: ~48 hours.

**This guide was written by the Claude session that built Umanity and wrote the winning guide for Veil Protocol. Follow it precisely.**

---

## THE GAME: "Prophecy Roguelite"

A turn-based dungeon survival game where **predicting the future keeps you alive.** Built fully on-chain with Dojo ECS + Godot engine.

### Core Game Loop
1. Player enters a dungeon with 100 HP
2. Each floor has a random event: Monster, Trap, Treasure, or Heal
3. BEFORE the event reveals, player **predicts** what's coming (4 choices)
4. **Correct prediction** = prepared (dodge trap, first-strike monster, bonus gold from treasure, extra healing)
5. **Wrong prediction** = caught off-guard (full monster damage, trap hits, treasure vanishes, reduced healing)
6. Survive as many floors as possible. Die = permadeath
7. Score = floors survived + prediction accuracy bonus
8. **Global on-chain leaderboard** — highest scores permanently recorded

### Why This Wins
- **Single player** — no matchmaking complexity
- **Turn-based** — no real-time sync issues
- **Simple scope** — 3-4 Cairo models, 3-4 systems
- **Fully on-chain** — all game state in Dojo ECS
- **Cartridge session keys** — seamless gameplay, no TX popups every turn
- **Addictive** — roguelite "one more run" loop
- **Competitive** — on-chain leaderboard
- **Novel** — prediction-enhanced combat is unique in Dojo ecosystem
- **Builds on Godot demo** — SDK demo already has grid movement + wallet auth

### Previous Jam Winners (for reference)
- **zKnight** — Strategic turn-based (Into-The-Breach style)
- **zDefender** — Tower defense
- **zKlash** — 2D autobattler
- **Blob Arena** — Tactical 1v1
- **Tale Weaver** — AI-driven narrative

Pattern: **Turn-based strategic games with clear win/lose conditions dominate.**

---

## REFERENCE LINKS

### Dojo Engine
- **Dojo Docs**: https://dojoengine.org
- **Dojo Framework**: https://dojoengine.org/framework
- **Dojo Book**: https://book.dojoengine.org
- **Dojo GitHub**: https://github.com/dojoengine/dojo
- **Torii Indexer**: https://book.dojoengine.org/toolchain/torii
- **Katana (Local Chain)**: https://book.dojoengine.org/toolchain/katana
- **Sozo (Build/Deploy)**: https://book.dojoengine.org/toolchain/sozo

### Godot SDK
- **Godot SDK Docs**: https://dojoengine.org/client/sdk/godot
- **Godot-Dojo GitHub (Demo Project)**: https://github.com/lonewolftechnology/godot-dojo
- **Godot Engine Download**: https://godotengine.org/download

### Wallet & Auth
- **Cartridge Controller**: https://docs.cartridge.gg/controller/overview
- **Starkzap SDK**: https://starkzap.io
- **Starkzap Docs**: https://docs.starknet.io/build/starkzap/overview

### Hackathon
- **Dojo Game Jam VIII**: https://lu.ma/dojogamejam8
- **Dojo Discord** (for help): https://discord.gg/dojoengine
- **Previous Jam Winners**: https://itch.io/jam/dojo-game-jam

---

## PHASE 1: ENVIRONMENT SETUP (First 2-3 hours)

### 1.1 Install Dojo Toolchain

```bash
# Install dojoup (Dojo version manager)
curl -L https://install.dojoengine.org | bash

# Install latest Dojo (includes katana, sozo, torii)
dojoup

# Verify installation
katana --version
sozo --version
torii --version
```

### 1.2 Install Godot Engine

Download Godot 4.5+ from https://godotengine.org/download (macOS Apple Silicon build).

### 1.3 Clone the Godot-Dojo Demo Project

```bash
cd /Users/macbookair/projects/prophecy-roguelite

# Clone the official demo project — this is our starting base
git clone https://github.com/lonewolftechnology/godot-dojo.git godot-client

# Also init a dojo starter for the contracts
sozo init contracts
```

The demo project has a working onchain game skeleton: player spawning, arrow-key movement, blockchain-to-visual state sync. We build on top of this.

### 1.4 Verify Everything Works

```bash
# Terminal 1: Start local Starknet chain
katana --allowed-origins "*"

# Terminal 2: Build and deploy the starter contracts
cd contracts
sozo build
sozo migrate

# Terminal 3: Start Torii indexer (connects to katana + deployed world)
torii --world <WORLD_ADDRESS_FROM_MIGRATE> --allowed-origins "*"

# Terminal 4: Open Godot, load the demo project from godot-client/, hit Play
```

If you see a character that can move with arrow keys and state syncs to blockchain — the stack is working.

---

## PHASE 2: CAIRO SMART CONTRACTS (Hours 3-8)

This is the on-chain game logic. Everything lives in the `contracts/` directory.

### 2.1 Game Models (ECS Components)

Create these Cairo models. Keep them small and focused — this is Dojo best practice.

```cairo
// models/player.cairo
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Player {
    #[key]
    pub address: ContractAddress,
    pub hp: u32,
    pub max_hp: u32,
    pub floor: u32,
    pub gold: u32,
    pub prediction_streak: u32,
    pub total_predictions: u32,
    pub correct_predictions: u32,
    pub is_alive: bool,
}

// models/game_round.cairo
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct GameRound {
    #[key]
    pub address: ContractAddress,
    #[key]
    pub floor: u32,
    pub event_type: u8,       // 0=Monster, 1=Trap, 2=Treasure, 3=Heal
    pub player_prediction: u8, // What player predicted
    pub damage_dealt: u32,
    pub gold_earned: u32,
    pub hp_change: i32,
    pub was_correct: bool,
    pub resolved: bool,
}

// models/leaderboard_entry.cairo
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct LeaderboardEntry {
    #[key]
    pub address: ContractAddress,
    pub high_score: u32,
    pub highest_floor: u32,
    pub best_streak: u32,
    pub total_runs: u32,
}
```

### 2.2 Game Systems (Logic)

```cairo
// systems/game.cairo

#[dojo::interface]
trait IGameActions {
    fn spawn(ref world: IWorldDispatcher);
    fn predict_and_advance(ref world: IWorldDispatcher, prediction: u8);
}

#[dojo::contract]
mod game_actions {
    use super::IGameActions;
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};

    #[abi(embed_v0)]
    impl GameActionsImpl of IGameActions<ContractState> {

        // Spawn a new player (or restart after death)
        fn spawn(ref world: IWorldDispatcher) {
            let player_address = get_caller_address();

            // Create/reset player
            set!(world, (Player {
                address: player_address,
                hp: 100,
                max_hp: 100,
                floor: 0,
                gold: 0,
                prediction_streak: 0,
                total_predictions: 0,
                correct_predictions: 0,
                is_alive: true,
            }));
        }

        // Player predicts what's on the next floor, then the floor resolves
        fn predict_and_advance(ref world: IWorldDispatcher, prediction: u8) {
            let player_address = get_caller_address();
            let mut player = get!(world, player_address, (Player));

            assert!(player.is_alive, "Player is dead. Call spawn() to restart.");
            assert!(prediction < 4, "Invalid prediction. Must be 0-3.");

            // Advance to next floor
            let new_floor = player.floor + 1;

            // Generate pseudo-random event based on block timestamp + floor + address
            // (Good enough for a game jam — not cryptographically secure but fair)
            let seed = get_block_timestamp().into() + new_floor.into() + player_address.into();
            let event_type: u8 = (seed % 4).try_into().unwrap();

            let was_correct = prediction == event_type;

            // Calculate outcomes based on prediction accuracy
            let (damage, gold, hp_change) = calculate_outcome(
                event_type, was_correct, new_floor
            );

            // Apply damage/healing
            if damage > 0 && damage >= player.hp {
                player.hp = 0;
                player.is_alive = false;
            } else if damage > 0 {
                player.hp -= damage;
            }

            if hp_change > 0 {
                player.hp = min(player.hp + hp_change, player.max_hp);
            }

            // Update stats
            player.floor = new_floor;
            player.gold += gold;
            player.total_predictions += 1;
            if was_correct {
                player.correct_predictions += 1;
                player.prediction_streak += 1;
            } else {
                player.prediction_streak = 0;
            }

            // Save player state
            set!(world, (player));

            // Save round details
            set!(world, (GameRound {
                address: player_address,
                floor: new_floor,
                event_type,
                player_prediction: prediction,
                damage_dealt: damage,
                gold_earned: gold,
                hp_change,
                was_correct,
                resolved: true,
            }));

            // If player died, update leaderboard
            if !player.is_alive {
                let score = calculate_score(player);
                let mut entry = get!(world, player_address, (LeaderboardEntry));

                if score > entry.high_score {
                    entry.high_score = score;
                }
                if new_floor > entry.highest_floor {
                    entry.highest_floor = new_floor;
                }
                if player.prediction_streak > entry.best_streak {
                    // Use the max streak from the run, not current (which is 0 at death)
                    entry.best_streak = player.prediction_streak;
                }
                entry.total_runs += 1;

                set!(world, (entry));
            }
        }
    }

    // Event outcomes scale with floor depth
    fn calculate_outcome(event_type: u8, predicted_correctly: bool, floor: u32) -> (u32, u32, u32) {
        let base_damage = 10 + (floor * 2); // Gets harder each floor
        let base_gold = 5 + floor;
        let base_heal = 15;

        match event_type {
            0 => { // Monster
                if predicted_correctly {
                    // First strike — take half damage, earn gold for kill
                    (base_damage / 2, base_gold, 0)
                } else {
                    // Ambushed — full damage, no gold
                    (base_damage, 0, 0)
                }
            },
            1 => { // Trap
                if predicted_correctly {
                    // Avoided trap, find hidden gold
                    (0, base_gold / 2, 0)
                } else {
                    // Walked right into it
                    (base_damage * 3 / 4, 0, 0)
                }
            },
            2 => { // Treasure
                if predicted_correctly {
                    // Prepared — grab everything
                    (0, base_gold * 3, 0)
                } else {
                    // Missed most of it
                    (0, base_gold / 2, 0)
                }
            },
            3 => { // Heal
                if predicted_correctly {
                    // Full restoration
                    (0, 0, base_heal + 5)
                } else {
                    // Partial heal
                    (0, 0, base_heal / 2)
                }
            },
            _ => (0, 0, 0),
        }
    }

    fn calculate_score(player: Player) -> u32 {
        let accuracy_bonus = if player.total_predictions > 0 {
            (player.correct_predictions * 100) / player.total_predictions
        } else {
            0
        };
        // Score = floors * 10 + gold + accuracy_bonus + streak_bonus
        (player.floor * 10) + player.gold + accuracy_bonus + (player.prediction_streak * 5)
    }

    fn min(a: u32, b: u32) -> u32 {
        if a < b { a } else { b }
    }
}
```

### 2.3 Build and Deploy

```bash
cd contracts
sozo build
sozo migrate  # Deploy to katana local chain

# Note the World address from migration output — needed for Torii
```

### 2.4 Write Tests

```cairo
// tests/test_game.cairo
#[test]
fn test_spawn_creates_player() { ... }

#[test]
fn test_predict_advances_floor() { ... }

#[test]
fn test_death_updates_leaderboard() { ... }

#[test]
fn test_correct_prediction_reduces_damage() { ... }
```

Run: `sozo test`

---

## PHASE 3: GODOT FRONTEND (Hours 8-20)

### 3.1 Project Structure

Build on top of the demo project. The key scenes:

```
godot-client/
├── game/
│   ├── scenes/
│   │   ├── Main.tscn           # Main game scene
│   │   ├── DungeonFloor.tscn   # Floor display with event card
│   │   ├── PredictionUI.tscn   # 4 prediction buttons
│   │   ├── PlayerHUD.tscn      # HP bar, floor counter, gold, streak
│   │   ├── EventReveal.tscn    # Animation when event reveals
│   │   ├── GameOver.tscn       # Death screen with score + leaderboard
│   │   ├── MainMenu.tscn       # Start screen with wallet connect
│   │   └── Leaderboard.tscn    # Global rankings
│   ├── scripts/
│   │   ├── game_manager.gd     # Core game state + Dojo interaction
│   │   ├── prediction_ui.gd    # 4 buttons: Monster/Trap/Treasure/Heal
│   │   ├── player_hud.gd       # HP bar, stats display
│   │   ├── event_reveal.gd     # Reveal animation + outcome display
│   │   ├── leaderboard.gd      # Fetch + display rankings from Torii
│   │   └── wallet_manager.gd   # Cartridge Controller session keys
│   └── assets/
│       ├── sprites/            # Simple pixel art or icons
│       ├── sounds/             # SFX (predict, correct, wrong, death)
│       └── fonts/              # Pixel font for dungeon aesthetic
└── addons/
    └── dojo/                   # Dojo GDExtension (from SDK release)
```

### 3.2 Core Game Manager (GDScript)

```gdscript
# game_manager.gd
extends Node

var torii_client: ToriiClient
var session_account: DojoSessionAccount
var world_address: String = "0x..."  # From sozo migrate
var game_contract: String = "0x..."  # Game actions contract address

var player_hp: int = 100
var current_floor: int = 0
var gold: int = 0
var prediction_streak: int = 0
var is_alive: bool = true

signal floor_resolved(event_type, was_correct, damage, gold_earned, hp_change)
signal player_died(final_score)
signal player_spawned()

func _ready():
    # Connect to Torii indexer
    torii_client = ToriiClient.new()
    torii_client.connect("http://localhost:8080")

    # Subscribe to player entity updates
    var callback = DojoCallback.new()
    callback.on_update = _on_entity_update
    torii_client.subscribe_entity_updates(DojoClause.new(), [world_address], callback)

func spawn_player():
    session_account.execute_single(game_contract, "spawn", [])
    is_alive = true
    player_hp = 100
    current_floor = 0
    gold = 0
    prediction_streak = 0
    emit_signal("player_spawned")

func make_prediction(prediction: int):
    # prediction: 0=Monster, 1=Trap, 2=Treasure, 3=Heal
    session_account.execute_single(game_contract, "predict_and_advance", [prediction])
    # Result comes back via Torii subscription → _on_entity_update

func _on_entity_update(entity):
    # Parse updated player state from Torii
    # Update local state and emit signals for UI
    pass
```

### 3.3 Prediction UI

Four large buttons, one for each event type. Use distinct colors and icons:
- **Monster** (Red, skull icon) — "I predict a Monster!"
- **Trap** (Orange, spike icon) — "I predict a Trap!"
- **Treasure** (Gold, chest icon) — "I predict Treasure!"
- **Heal** (Green, heart icon) — "I predict Healing!"

After clicking, show a dramatic reveal animation:
1. Card flips / door opens
2. Actual event appears with visual feedback
3. Green glow + "CORRECT!" or Red flash + "WRONG!"
4. HP bar updates, gold counter updates, streak counter updates
5. If HP = 0 → Death animation → Game Over screen

### 3.4 Visual Style

Keep it simple but atmospheric:
- **Dark dungeon theme** — dark backgrounds, torch-lit feel
- **Pixel art style** — achievable with free assets or simple custom sprites
- **4 event icons** — Monster (skull), Trap (spikes), Treasure (chest), Heal (potion)
- **Player character** — Simple knight/adventurer sprite
- **Animations** — Godot's built-in AnimationPlayer for reveals, damage, death
- **Particles** — Simple particle effects for correct predictions (sparkles) and damage (red flash)

**Free asset sources:**
- https://kenney.nl/assets (free game assets, public domain)
- https://opengameart.org (free sprites, sounds)
- Godot built-in primitives for prototyping

### 3.5 Game Over / Leaderboard

When player dies:
1. Show "GAME OVER" with dramatic animation
2. Display final stats: Floor reached, Gold collected, Prediction accuracy %, Best streak
3. Calculate final score
4. Show position on global leaderboard (fetched from Torii)
5. "Play Again" button (calls spawn)

---

## PHASE 4: CARTRIDGE CONTROLLER INTEGRATION (Hours 20-24)

### 4.1 Session Keys (CRITICAL for gameplay)

Without session keys, players get a wallet popup EVERY TURN. That kills the game feel. Cartridge Controller session keys pre-approve game actions.

```gdscript
# wallet_manager.gd
extends Node

var session_account: DojoSessionAccount
var controller_helper: ControllerHelper

func setup_session():
    var priv_key = ControllerHelper.generate_private_key()

    # Define which contract functions the session can call
    var policies = [
        {"target": game_contract, "method": "spawn"},
        {"target": game_contract, "method": "predict_and_advance"},
    ]

    # Generate session registration URL
    var session_url = ControllerHelper.create_session_registration_url(
        priv_key, policies, katana_url
    )

    # Open in browser for user to approve once
    OS.shell_open(session_url)

    # After approval, create session account
    session_account = DojoSessionAccount.new(priv_key, katana_url)
```

After one-time approval, every `predict_and_advance` call goes through instantly — no popups, seamless gameplay.

### 4.2 Starkzap Alternative

If Cartridge integration proves complex, Starkzap SDK can handle wallet auth:

```bash
npm install starkzap
```

Starkzap provides:
- Cartridge Controller integration out of the box
- Social login (Google, email, passkeys)
- AVNU paymaster for gasless transactions

Docs: https://docs.starknet.io/build/starkzap/overview

**NOTE**: Starkzap is a TypeScript SDK, so it would work for a web frontend (React/Next.js), not directly in Godot. If wallet integration in Godot proves too complex, consider building the UI as a web app instead of Godot and using Starkzap. Previous jam winners like zKlash used web frontends. Godot is encouraged but not mandatory.

---

## PHASE 5: POLISH & JUICE (Hours 24-36)

### 5.1 Sound Effects
Add simple SFX for key moments:
- Prediction selected (click)
- Correct prediction (triumphant chime)
- Wrong prediction (ominous thud)
- Monster encounter (growl)
- Treasure found (coin jingle)
- Healing (sparkle)
- Death (dramatic)
- New high score (fanfare)

Use Godot's AudioStreamPlayer. Free SFX from https://freesound.org or https://kenney.nl/assets/category:Audio

### 5.2 Screen Shake & Feedback
- Camera shake on damage
- Flash red on wrong prediction
- Flash green on correct prediction
- Pulse HP bar when low health
- Streak counter with escalating visual intensity (3x → 5x → 10x)

### 5.3 Difficulty Curve
The Cairo contract already scales damage with floor number. But visually:
- Floors 1-5: Easy, tutorial feel, gentle colors
- Floors 6-15: Medium, darker atmosphere, more intense SFX
- Floors 16+: Hard, screen effects, urgent music, death feels imminent

### 5.4 Statistics Screen
Between runs, show:
- Total runs
- Best floor reached
- Best prediction streak
- Overall accuracy %
- Gold earned all-time

---

## PHASE 6: DEMO VIDEO & SUBMISSION (Hours 36-48)

### 6.1 Demo Video (Under 3 Minutes)

**[0:00 - 0:15] Hook**
"Prophecy Roguelite — a fully on-chain dungeon crawler where predicting the future keeps you alive. Every move is a Dojo transaction on Starknet. Let me show you."

**[0:15 - 0:45] Connect + Spawn**
- Connect via Cartridge Controller (show session key approval — one time)
- Spawn character
- "Session keys mean I never see a wallet popup again. Every prediction is an instant on-chain transaction."

**[0:45 - 1:30] Gameplay (The Core)**
- Play 5-8 floors
- Show correct prediction: "I predicted a monster — and I was right! First strike, half damage, earned gold."
- Show wrong prediction: "Thought it was treasure... it was a trap. Full damage."
- Show streak building: "Three correct in a row — my streak is climbing."
- Show HP getting low: "Floor 12, barely alive..."

**[1:30 - 2:00] Death + Leaderboard**
- Player dies
- "Game over at floor 14. But my score is permanently on-chain."
- Show leaderboard: "Global rankings — every run is recorded on Starknet via Torii."

**[2:00 - 2:30] Technical Flex**
- Show Torii indexer running: "Every game state change is indexed in real-time."
- Show Voyager: "All game logic is verifiable Cairo smart contracts."
- Quick flash of code: "Three models. Three systems. Fully on-chain ECS."

**[2:30 - 2:50] Close**
"Prophecy Roguelite. Turn-based. On-chain. Every prediction matters. Built with Dojo, Godot, and Cartridge in 48 hours for Game Jam VIII."

### 6.2 Submission Checklist
- [ ] Game deployed (at minimum on Katana local, ideally on Starknet Sepolia testnet)
- [ ] GitHub repo public with clean README
- [ ] Demo video under 3 minutes uploaded to YouTube
- [ ] Submit on the Game Jam page (itch.io or wherever specified)
- [ ] Post on X tagging @ohayo_dojo @cartaboratory

---

## FALLBACK PLAN: WEB FRONTEND INSTEAD OF GODOT

If Godot + Dojo SDK integration proves too complex or buggy in the time constraint, pivot to a **web-based frontend**. Previous winning games (zKnight, zDefender, zKlash) all used web frontends.

### Web Stack:
```bash
npx create-next-app prophecy-web --typescript --tailwind
cd prophecy-web
npm install @dojoengine/core @dojoengine/react starknet starkzap
```

### Web Approach:
- Same Cairo contracts (Phase 2 stays identical)
- React frontend with Tailwind CSS
- Starkzap for wallet integration (Cartridge Controller + social login)
- @dojoengine/react hooks for entity subscriptions
- Framer Motion for card flip animations
- This is your comfort zone (you built Umanity and Veil Protocol in React/Next.js)

### Web vs Godot Trade-offs:
| | Godot | Web |
|--|-------|-----|
| **Impressiveness** | Higher (new SDK, judges love it) | Lower (expected) |
| **Dev speed for you** | Slower (new engine) | Faster (your expertise) |
| **Risk** | Higher (SDK bugs, unfamiliar) | Lower (proven stack) |
| **Game feel** | Better (real game engine) | Adequate (but still fun) |

**Recommendation**: Start with Godot (Phase 3). If after 4-6 hours you're stuck on Godot basics, pivot to web. Don't waste more than 6 hours fighting the engine. The game logic (Phase 2) is identical either way.

---

## CRITICAL REMINDERS

1. **SCOPE IS EVERYTHING** — This is a 48-hour jam. The game above is the MAXIMUM scope. If anything takes too long, cut it. A working simple game beats a broken ambitious one.

2. **GET THE GAME LOOP WORKING FIRST** — Before any polish: spawn → predict → resolve → die → leaderboard. That's the MVP. Everything else is bonus.

3. **TEST ON-CHAIN EARLY** — Don't build the entire Godot frontend before testing the Cairo contracts. Deploy to Katana and test with sozo execute first.

4. **SESSION KEYS ARE MANDATORY** — Without them, the game is unplayable (popup every turn). If Cartridge doesn't work, at minimum use a burner wallet pattern.

5. **THE DEMO VIDEO IS 50% OF THE SCORE** — Judges see the video first. A polished 2:50 demo of a simple working game beats a complex buggy game with a bad demo. We learned this from Umanity and Veil Protocol.

6. **COMMIT FREQUENTLY** — Git commit every milestone. If something breaks, you can roll back.

7. **ASK IN DOJO DISCORD** — If stuck on Dojo/Godot SDK issues, ask in the Dojo Discord. Game jam participants help each other. Link: https://discord.gg/dojoengine

---

## 48-HOUR TIMELINE

| Hours | Phase | Milestone |
|-------|-------|-----------|
| 0-3 | Setup | Dojo + Godot + Katana + Torii all running |
| 3-8 | Contracts | Cairo models + systems built, tested, deployed on Katana |
| 8-14 | Frontend | Basic Godot scene: predict buttons, event reveal, HP display |
| 14-20 | Integration | Godot ↔ Torii connected, full game loop working on-chain |
| 20-24 | Wallet | Cartridge session keys working, seamless gameplay |
| 24-32 | Polish | SFX, animations, leaderboard UI, death screen, visual juice |
| 32-40 | Testing | Playtest, fix bugs, balance difficulty, edge cases |
| 40-44 | Demo | Record video, edit, upload |
| 44-48 | Submit | Clean README, push to GitHub, submit to jam |

**Good luck. Ship it. Win it.**
