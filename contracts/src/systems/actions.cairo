#[starknet::interface]
pub trait IActions<T> {
    fn create_trader(ref self: T);
    fn create_market(ref self: T, market_id: u32, yes_odds: u32, no_odds: u32);
    fn place_prediction(ref self: T, market_id: u32, is_yes: bool, amount: u32);
    fn resolve_market(ref self: T, market_id: u32, outcome: bool);
    fn claim(ref self: T, market_id: u32);
    fn buy_relic(ref self: T, relic_type: u32);
    fn bet_world_boss(ref self: T, is_yes: bool, amount: u32);
    fn init_world_boss(ref self: T, title_id: u32);
    fn cash_out_early(ref self: T, market_id: u32);
}

#[dojo::contract]
pub mod actions {
    use dojo::event::EventStorage;
    use dojo::model::ModelStorage;
    use prophecy_roguelite::models::{Market, Position, Trader, LeaderboardEntry, Relics, WorldBoss};
    use starknet::{ContractAddress, get_caller_address};
    use super::IActions;

    #[derive(Copy, Drop, Serde)]
    #[dojo::event]
    pub struct TraderCreated {
        #[key]
        pub player: ContractAddress,
        pub balance: u32,
    }

    #[derive(Copy, Drop, Serde)]
    #[dojo::event]
    pub struct PredictionPlaced {
        #[key]
        pub player: ContractAddress,
        pub market_id: u32,
        pub is_yes: bool,
        pub amount: u32,
    }

    #[derive(Copy, Drop, Serde)]
    #[dojo::event]
    pub struct MarketResolved {
        #[key]
        pub market_id: u32,
        pub outcome: bool,
    }

    #[derive(Copy, Drop, Serde)]
    #[dojo::event]
    pub struct PositionSettled {
        #[key]
        pub player: ContractAddress,
        pub market_id: u32,
        pub correct: bool,
        pub payout: u32,
    }

    #[abi(embed_v0)]
    impl ActionsImpl of IActions<ContractState> {
        fn create_trader(ref self: ContractState) {
            let mut world = self.world_default();
            let player_address = get_caller_address();

            let trader = Trader {
                address: player_address,
                balance: 10000,
                total_wagered: 0,
                total_won: 0,
                total_lost: 0,
                markets_played: 0,
                correct_predictions: 0,
                streak: 0,
                best_streak: 0,
            };

            world.write_model(@trader);
            world.emit_event(@TraderCreated { player: player_address, balance: 10000 });
        }

        fn create_market(ref self: ContractState, market_id: u32, yes_odds: u32, no_odds: u32) {
            let mut world = self.world_default();

            // Verify market doesn't already exist (yes_odds would be 0 for uninitialized)
            let existing: Market = world.read_model(market_id);
            assert!(existing.yes_odds == 0, "Market already exists");

            let market = Market {
                market_id,
                yes_odds,
                no_odds,
                is_resolved: false,
                outcome: false,
                total_yes_amount: 0,
                total_no_amount: 0,
            };

            world.write_model(@market);
        }

        fn place_prediction(ref self: ContractState, market_id: u32, is_yes: bool, amount: u32) {
            let mut world = self.world_default();
            let player_address = get_caller_address();

            // Read trader and market
            let mut trader: Trader = world.read_model(player_address);
            let mut market: Market = world.read_model(market_id);

            // Validate
            assert!(trader.balance > 0, "No trader account. Call create_trader() first.");
            assert!(market.yes_odds > 0, "Market does not exist.");
            assert!(amount > 0, "Amount must be greater than 0.");
            assert!(amount <= trader.balance, "Insufficient balance.");

            // Check no existing position
            let existing_pos: Position = world.read_model((player_address, market_id));
            assert!(existing_pos.amount == 0, "Already have a position on this market.");

            // Deduct from balance
            trader.balance -= amount;
            trader.markets_played += 1;
            trader.total_wagered += amount;

            // Create position
            let mut position = Position {
                player: player_address,
                market_id,
                is_yes,
                amount,
                is_settled: false,
                payout: 0,
            };

            // Update market totals
            if is_yes {
                market.total_yes_amount += amount;
            } else {
                market.total_no_amount += amount;
            }

            world.write_model(@market);

            // If market already resolved, auto-settle
            if market.is_resolved {
                let correct = (is_yes && market.outcome) || (!is_yes && !market.outcome);
                if correct {
                    let odds = if is_yes {
                        market.yes_odds
                    } else {
                        market.no_odds
                    };
                    let payout_amount = (amount * odds) / 100;
                    position.payout = payout_amount;
                    trader.balance += payout_amount;
                    trader.total_won += payout_amount;
                    trader.correct_predictions += 1;
                    trader.streak += 1;
                    if trader.streak > trader.best_streak {
                        trader.best_streak = trader.streak;
                    }
                } else {
                    position.payout = 0;
                    trader.total_lost += amount;
                    trader.streak = 0;
                }
                position.is_settled = true;

                // Update leaderboard if balance is a new high
                let mut entry: LeaderboardEntry = world.read_model(player_address);
                if trader.balance > entry.high_score {
                    entry.high_score = trader.balance;
                }
                entry.highest_floor = trader.markets_played;
                entry.best_streak = trader.best_streak;
                entry.total_runs += 1;
                world.write_model(@entry);

                world
                    .emit_event(
                        @PositionSettled {
                            player: player_address,
                            market_id,
                            correct,
                            payout: position.payout,
                        },
                    );
            }

            world.write_model(@position);
            world.write_model(@trader);
            world
                .emit_event(
                    @PredictionPlaced {
                        player: player_address, market_id, is_yes, amount,
                    },
                );
        }

        fn resolve_market(ref self: ContractState, market_id: u32, outcome: bool) {
            let mut world = self.world_default();

            let mut market: Market = world.read_model(market_id);
            assert!(market.yes_odds > 0, "Market does not exist.");
            assert!(!market.is_resolved, "Market already resolved.");

            market.is_resolved = true;
            market.outcome = outcome;

            world.write_model(@market);
            world.emit_event(@MarketResolved { market_id, outcome });
        }

        fn buy_relic(ref self: ContractState, relic_type: u32) {
            let mut world = self.world_default();
            let player_address = get_caller_address();
            let mut trader: Trader = world.read_model(player_address);
            assert!(trader.balance > 0, "No trader account.");

            // relic_type: 0 = leverage ($1500), 1 = stop_loss ($1000), 2 = insider ($2000)
            let cost: u32 = if relic_type == 0 {
                1500
            } else if relic_type == 1 {
                1000
            } else if relic_type == 2 {
                2000
            } else {
                0
            };
            assert!(cost > 0, "Invalid relic type.");
            assert!(trader.balance >= cost, "Insufficient balance for relic.");

            trader.balance -= cost;
            world.write_model(@trader);

            let mut relics: Relics = world.read_model(player_address);
            if relic_type == 0 {
                relics.leverage_tokens += 1;
            } else if relic_type == 1 {
                relics.stop_loss += 1;
            } else {
                relics.insider_info += 1;
            }
            relics.address = player_address;
            world.write_model(@relics);
        }

        fn claim(ref self: ContractState, market_id: u32) {
            let mut world = self.world_default();
            let player_address = get_caller_address();

            let market: Market = world.read_model(market_id);
            assert!(market.is_resolved, "Market not yet resolved.");

            let mut position: Position = world.read_model((player_address, market_id));
            assert!(position.amount > 0, "No position on this market.");
            assert!(!position.is_settled, "Position already settled.");

            let mut trader: Trader = world.read_model(player_address);

            let correct = (position.is_yes && market.outcome)
                || (!position.is_yes && !market.outcome);

            if correct {
                let odds = if position.is_yes {
                    market.yes_odds
                } else {
                    market.no_odds
                };
                let payout_amount = (position.amount * odds) / 100;
                position.payout = payout_amount;
                trader.balance += payout_amount;
                trader.total_won += payout_amount;
                trader.correct_predictions += 1;
                trader.streak += 1;
                if trader.streak > trader.best_streak {
                    trader.best_streak = trader.streak;
                }
            } else {
                position.payout = 0;
                trader.total_lost += position.amount;
                trader.streak = 0;
            }

            position.is_settled = true;

            // Update leaderboard
            let mut entry: LeaderboardEntry = world.read_model(player_address);
            if trader.balance > entry.high_score {
                entry.high_score = trader.balance;
            }
            entry.highest_floor = trader.markets_played;
            entry.best_streak = trader.best_streak;
            entry.total_runs += 1;
            world.write_model(@entry);

            world.write_model(@position);
            world.write_model(@trader);
            world
                .emit_event(
                    @PositionSettled {
                        player: player_address, market_id, correct, payout: position.payout,
                    },
                );
        }

        fn init_world_boss(ref self: ContractState, title_id: u32) {
            let mut world = self.world_default();
            let zero_addr: ContractAddress = 0.try_into().unwrap();
            let boss = WorldBoss {
                boss_id: 0,
                title_id,
                total_yes: 0,
                total_no: 0,
                total_yes_amount: 0,
                total_no_amount: 0,
                is_resolved: false,
                outcome: false,
                recent_0: zero_addr,
                recent_1: zero_addr,
                recent_2: zero_addr,
                recent_3: zero_addr,
                recent_4: zero_addr,
            };
            world.write_model(@boss);
        }

        fn cash_out_early(ref self: ContractState, market_id: u32) {
            let mut world = self.world_default();
            let player_address = get_caller_address();

            let market: Market = world.read_model(market_id);
            assert!(market.yes_odds > 0, "Market does not exist.");
            assert!(!market.is_resolved, "Market already resolved. Use claim instead.");

            let mut position: Position = world.read_model((player_address, market_id));
            assert!(position.amount > 0, "No position on this market.");
            assert!(!position.is_settled, "Position already settled.");

            let mut trader: Trader = world.read_model(player_address);

            // Dynamic cash-out value based on market sentiment (50%-150% of wager):
            // If you bet YES and more money is on YES, your position is worth less (crowded).
            // If you bet YES and less money is on YES (contrarian), worth more.
            let total_pool = market.total_yes_amount + market.total_no_amount;
            let cash_out_amount = if total_pool == 0 {
                // No pool data: refund 80% as a flat exit fee
                (position.amount * 80) / 100
            } else {
                let your_side = if position.is_yes {
                    market.total_yes_amount
                } else {
                    market.total_no_amount
                };
                let other_side = total_pool - your_side;
                // Ratio: other_side / your_side, clamped to [50%, 150%] of wager
                // More on the other side = your position is more valuable
                let raw = (position.amount * (50 + (other_side * 100) / total_pool)) / 100;
                // Clamp between 50% and 150%
                let min_out = (position.amount * 50) / 100;
                let max_out = (position.amount * 150) / 100;
                if raw < min_out {
                    min_out
                } else if raw > max_out {
                    max_out
                } else {
                    raw
                }
            };

            position.payout = cash_out_amount;
            position.is_settled = true;
            trader.balance += cash_out_amount;
            if cash_out_amount >= position.amount {
                trader.total_won += cash_out_amount - position.amount;
            } else {
                trader.total_lost += position.amount - cash_out_amount;
            }

            world.write_model(@position);
            world.write_model(@trader);
            world
                .emit_event(
                    @PositionSettled {
                        player: player_address,
                        market_id,
                        correct: cash_out_amount >= position.amount,
                        payout: cash_out_amount,
                    },
                );
        }

        fn bet_world_boss(ref self: ContractState, is_yes: bool, amount: u32) {
            let mut world = self.world_default();
            let player_address = get_caller_address();

            let mut trader: Trader = world.read_model(player_address);
            assert!(trader.balance > 0, "No trader account.");
            assert!(amount > 0 && amount <= trader.balance, "Invalid amount.");

            let mut boss: WorldBoss = world.read_model(0_u32);
            assert!(!boss.is_resolved, "World Boss already resolved.");

            trader.balance -= amount;
            trader.total_wagered += amount;

            if is_yes {
                boss.total_yes += 1;
                boss.total_yes_amount += amount;
            } else {
                boss.total_no += 1;
                boss.total_no_amount += amount;
            }

            // Ring buffer: store in slot (total_bets - 1) % 5
            let total_bets = boss.total_yes + boss.total_no;
            let slot = (total_bets - 1) % 5;
            if slot == 0 {
                boss.recent_0 = player_address;
            } else if slot == 1 {
                boss.recent_1 = player_address;
            } else if slot == 2 {
                boss.recent_2 = player_address;
            } else if slot == 3 {
                boss.recent_3 = player_address;
            } else {
                boss.recent_4 = player_address;
            }

            world.write_model(@boss);
            world.write_model(@trader);
            world
                .emit_event(
                    @PredictionPlaced {
                        player: player_address, market_id: 9999, is_yes, amount,
                    },
                );
        }

    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"prophecy_roguelite")
        }
    }
}
