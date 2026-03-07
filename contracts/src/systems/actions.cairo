#[starknet::interface]
pub trait IActions<T> {
    fn spawn(ref self: T);
    fn predict_and_advance(ref self: T, prediction: u8, wager: u32);
}

#[dojo::contract]
pub mod actions {
    use core::pedersen::pedersen;
    use dojo::event::EventStorage;
    use dojo::model::ModelStorage;
    use prophecy_roguelite::models::{
        Player, GameRound, LeaderboardEntry, EventType, event_type_from_u8,
    };
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use super::IActions;

    #[derive(Copy, Drop, Serde)]
    #[dojo::event]
    pub struct PlayerSpawned {
        #[key]
        pub player: ContractAddress,
        pub hp: u32,
    }

    #[derive(Copy, Drop, Serde)]
    #[dojo::event]
    pub struct FloorResolved {
        #[key]
        pub player: ContractAddress,
        pub floor: u32,
        pub event_type: EventType,
        pub was_correct: bool,
        pub damage: u32,
        pub gold: u32,
        pub heal: u32,
    }

    #[derive(Copy, Drop, Serde)]
    #[dojo::event]
    pub struct PlayerDied {
        #[key]
        pub player: ContractAddress,
        pub final_floor: u32,
        pub final_score: u32,
    }

    #[abi(embed_v0)]
    impl ActionsImpl of IActions<ContractState> {
        fn spawn(ref self: ContractState) {
            let mut world = self.world_default();
            let player_address = get_caller_address();

            // Generate seed for floor 1
            let timestamp: felt252 = get_block_timestamp().into();
            let addr_felt: felt252 = player_address.into();
            let seed = pedersen(pedersen(timestamp, 1), addr_felt);
            let (clue_type, clue_detail) = generate_clues(seed);

            let new_player = Player {
                address: player_address,
                hp: 100,
                max_hp: 100,
                floor: 0,
                gold: 0,
                prediction_streak: 0,
                best_streak: 0,
                total_predictions: 0,
                correct_predictions: 0,
                is_alive: true,
                next_event_seed: seed,
                clue_type,
                clue_detail,
                streak_tier: 0,
            };

            world.write_model(@new_player);
            world.emit_event(@PlayerSpawned { player: player_address, hp: 100 });
        }

        fn predict_and_advance(ref self: ContractState, prediction: u8, wager: u32) {
            let mut world = self.world_default();
            let player_address = get_caller_address();
            let mut player: Player = world.read_model(player_address);

            // Validate
            assert!(player.is_alive, "Player is dead. Call spawn() to restart.");
            assert!(prediction < 4, "Invalid prediction. Must be 0-3.");
            assert!(wager <= player.gold, "Wager exceeds gold.");

            let new_floor = player.floor + 1;

            // Determine event from pre-committed seed
            let seed_u256: u256 = player.next_event_seed.into();
            let event_type_val: u8 = (seed_u256 % 4).try_into().unwrap();
            let event_type = event_type_from_u8(event_type_val);
            let player_prediction = event_type_from_u8(prediction);

            let was_correct = event_type_val == prediction;

            // Update streak and calculate tier
            let new_streak = if was_correct {
                player.prediction_streak + 1
            } else {
                0
            };
            let (tier, tier_mult) = get_streak_tier(new_streak);

            // Boss floor check
            let is_boss = new_floor % 5 == 0;

            // Calculate base outcomes
            let (base_damage, base_gold, base_heal) = calculate_outcome(
                event_type, was_correct, new_floor,
            );

            // Apply boss multiplier (2x)
            let mut damage = if is_boss {
                base_damage * 2
            } else {
                base_damage
            };
            let mut gold = if is_boss {
                base_gold * 2
            } else {
                base_gold
            };
            let mut heal = if is_boss {
                base_heal * 2
            } else {
                base_heal
            };

            // Apply tier multiplier to gold rewards
            gold = (gold * tier_mult) / 100;

            // Apply wager
            if was_correct && wager > 0 {
                gold += (wager * tier_mult) / 100;
            }

            // Boss correct bonus
            if is_boss && was_correct {
                gold += 10 + new_floor;
                heal += player.max_hp / 4;
            }

            // Prophetic tier HP regen
            if tier == 3 {
                heal += 5;
            }

            // Apply damage
            if damage >= player.hp {
                player.hp = 0;
                player.is_alive = false;
            } else if damage > 0 {
                player.hp -= damage;
            }

            // Deduct wager loss
            if !was_correct && wager > 0 {
                if wager >= player.gold {
                    player.gold = 0;
                } else {
                    player.gold -= wager;
                }
            }

            // Apply healing (cap at max_hp)
            if heal > 0 {
                let new_hp = player.hp + heal;
                if new_hp > player.max_hp {
                    player.hp = player.max_hp;
                } else {
                    player.hp = new_hp;
                }
            }

            // Update stats
            player.floor = new_floor;
            player.gold += gold;
            player.total_predictions += 1;

            if was_correct {
                player.correct_predictions += 1;
                player.prediction_streak = new_streak;
                if new_streak > player.best_streak {
                    player.best_streak = new_streak;
                }
            } else {
                player.prediction_streak = 0;
            }

            player.streak_tier = tier;

            // Generate next seed and clues
            let timestamp: felt252 = get_block_timestamp().into();
            let new_seed = pedersen(
                pedersen(timestamp, (new_floor + 1).into()), player.next_event_seed,
            );
            let (new_clue_type, new_clue_detail) = generate_clues(new_seed);
            player.next_event_seed = new_seed;
            player.clue_type = new_clue_type;
            player.clue_detail = new_clue_detail;

            // Save player state
            world.write_model(@player);

            // Save round details
            let round = GameRound {
                address: player_address,
                floor: new_floor,
                event_type,
                player_prediction,
                damage_dealt: damage,
                gold_earned: gold,
                hp_healed: heal,
                was_correct,
                wager_amount: wager,
                is_boss,
            };
            world.write_model(@round);

            // Emit floor resolved event
            world
                .emit_event(
                    @FloorResolved {
                        player: player_address,
                        floor: new_floor,
                        event_type,
                        was_correct,
                        damage,
                        gold,
                        heal,
                    },
                );

            // If player died, update leaderboard
            if !player.is_alive {
                let score = calculate_score(@player);
                let mut entry: LeaderboardEntry = world.read_model(player_address);

                if score > entry.high_score {
                    entry.high_score = score;
                }
                if new_floor > entry.highest_floor {
                    entry.highest_floor = new_floor;
                }
                if player.best_streak > entry.best_streak {
                    entry.best_streak = player.best_streak;
                }
                entry.total_runs += 1;

                world.write_model(@entry);

                world
                    .emit_event(
                        @PlayerDied {
                            player: player_address, final_floor: new_floor, final_score: score,
                        },
                    );
            }
        }
    }

    // Returns (tier, multiplier_percentage) based on prediction streak
    fn get_streak_tier(streak: u32) -> (u8, u32) {
        if streak >= 8 {
            (3, 200) // Prophetic: 2x
        } else if streak >= 5 {
            (2, 150) // Blazing: 1.5x
        } else if streak >= 3 {
            (1, 125) // Hot: 1.25x
        } else {
            (0, 100) // Normal: 1x
        }
    }

    // Generate category and detail clues from a seed
    fn generate_clues(seed: felt252) -> (u8, u8) {
        let seed_u256: u256 = seed.into();
        let event_type: u8 = (seed_u256 % 4).try_into().unwrap();

        // Category clue: danger (Monster/Trap) or fortune (Treasure/Heal)
        let clue_type: u8 = if event_type < 2 {
            0 // danger
        } else {
            1 // fortune
        };

        // Detail clue: 50% chance based on different bits of seed
        let detail_roll: u8 = ((seed_u256 / 4) % 2).try_into().unwrap();
        let clue_detail: u8 = if detail_roll == 0 {
            0 // no detail
        } else {
            // "Not" the other event in the same category
            if event_type == 0 {
                2 // Monster → "not Trap"
            } else if event_type == 1 {
                1 // Trap → "not Monster"
            } else if event_type == 2 {
                4 // Treasure → "not Heal"
            } else {
                3 // Heal → "not Treasure"
            }
        };

        (clue_type, clue_detail)
    }

    // Event outcomes scale with floor depth
    fn calculate_outcome(
        event_type: EventType, predicted_correctly: bool, floor: u32,
    ) -> (u32, u32, u32) {
        let base_damage = 10 + (floor * 2); // Gets harder each floor
        let base_gold = 5 + floor;
        let base_heal: u32 = 15;

        match event_type {
            EventType::Monster => {
                if predicted_correctly {
                    // First strike — half damage, earn gold
                    (base_damage / 2, base_gold, 0)
                } else {
                    // Ambushed — full damage, no gold
                    (base_damage, 0, 0)
                }
            },
            EventType::Trap => {
                if predicted_correctly {
                    // Avoided trap, find hidden gold
                    (0, base_gold / 2, 0)
                } else {
                    // Walked right into it
                    (base_damage * 3 / 4, 0, 0)
                }
            },
            EventType::Treasure => {
                if predicted_correctly {
                    // Prepared — grab everything
                    (0, base_gold * 3, 0)
                } else {
                    // Missed most of it
                    (0, base_gold / 2, 0)
                }
            },
            EventType::Heal => {
                if predicted_correctly {
                    // Full restoration
                    (0, 0, base_heal + 5)
                } else {
                    // Partial heal
                    (0, 0, base_heal / 2)
                }
            },
        }
    }

    fn calculate_score(player: @Player) -> u32 {
        let accuracy_bonus = if *player.total_predictions > 0 {
            (*player.correct_predictions * 100) / *player.total_predictions
        } else {
            0
        };
        // Score = floors * 10 + gold + accuracy_bonus + streak_bonus
        (*player.floor * 10) + *player.gold + accuracy_bonus + (*player.best_streak * 5)
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"prophecy_roguelite")
        }
    }
}
