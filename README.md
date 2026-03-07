# Prophecy Roguelite

**A fully on-chain prediction roguelite built with Dojo, Cairo, and Godot.**

Predict what lurks on each dungeon floor. Correct predictions give you combat advantages, bonus gold, and full healing. Wrong predictions mean full damage and missed rewards. Survive as long as you can.

Every move is an on-chain transaction on Starknet.

## How It Works

You descend through a procedurally generated dungeon. Each floor has one of four events:

| Event | Correct Prediction | Wrong Prediction |
|-------|-------------------|-----------------|
| **Monster** | Half damage + earn gold | Full damage |
| **Trap** | Dodge it + find gold | Take damage |
| **Treasure** | 3x gold bonus | Half gold |
| **Heal** | Full restoration (+20 HP) | Partial heal (+7 HP) |

Damage scales with floor depth, making deeper floors riskier. Build prediction streaks for bonus score.

**Score** = (Floors x 10) + Gold + Accuracy Bonus + (Best Streak x 5)

## Tech Stack

- **Cairo** — Smart contracts for all game logic (models, systems, events)
- **Dojo ECS v1.8** — On-chain entity component system framework
- **Starknet** — L2 execution via Katana sequencer
- **Torii** — Real-time indexer for game state subscriptions
- **Godot 4.6** — Game engine with native GDExtension integration
- **Cartridge** — Deployment infrastructure (Slot) and wallet auth (Controller)

## Architecture

```
Player (Godot)
    |
    v
DojoConnection (GDExtension)
    |
    +-- ToriiClient (state subscriptions + queries)
    +-- DojoSessionAccount (Cartridge Controller auth)
    |
    v
Katana (Starknet sequencer)
    |
    v
Cairo Contracts (Dojo ECS)
    +-- Player model (HP, gold, floor, streaks, accuracy)
    +-- GameRound model (event, prediction, outcomes)
    +-- LeaderboardEntry model (high scores across runs)
    +-- Actions system (spawn, predict_and_advance)
```

## On-Chain Game Logic

All game state lives on-chain. The `predict_and_advance` system:

1. Validates the player is alive and prediction is valid (0-3)
2. Generates a pseudo-random event from `block_timestamp + floor + address`
3. Compares prediction to event, calculates outcomes
4. Applies damage/healing/gold, updates streaks
5. Writes updated Player + GameRound models
6. Emits FloorResolved event
7. If player dies: updates LeaderboardEntry, emits PlayerDied

Zero off-chain game logic. The Godot client is purely a renderer.

## Project Structure

```
contracts/
  src/
    models.cairo        # Player, GameRound, LeaderboardEntry, EventType
    systems/actions.cairo  # spawn(), predict_and_advance()
    tests/test_world.cairo # 4 integration tests
  Scarb.toml
  dojo_dev.toml

game/
  scenes/main.tscn      # UI scene
  scripts/
    main_game.gd        # UI controller, animations, effects
    game_manager.gd     # State management, signal routing
  connection/
    dojo_connection.gd  # Torii + transaction execution
  shaders/
    dungeon_bg.gdshader # Animated background
  addons/godot-dojo/    # GDExtension (ToriiClient, DojoSessionAccount)
```

## Running Locally

### Prerequisites

- [Dojo](https://dojoengine.org) v1.8.6+ (`dojoup`)
- [Godot](https://godotengine.org) 4.6+
- [asdf](https://asdf-vm.com) with sozo/scarb plugins

### Setup

```bash
# 1. Start Katana (local Starknet)
cd contracts
katana --dev --dev.no-fee --http.cors_origins "*"

# 2. Build and deploy contracts
sozo build
sozo migrate

# 3. Start Torii indexer
torii --world 0x<WORLD_ADDRESS> --http.cors_origins "*"

# 4. Run the game
cd ../game
godot --path .
```

## Built For

**Dojo Game Jam VIII** — March 6-8, 2026

Fully on-chain game demonstrating Dojo ECS, Cairo smart contracts, Godot GDExtension integration, and Cartridge infrastructure on Starknet.
