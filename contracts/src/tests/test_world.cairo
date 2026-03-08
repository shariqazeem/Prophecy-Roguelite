#[cfg(test)]
mod tests {
    use dojo::model::ModelStorage;
    use dojo::world::{WorldStorageTrait, world};
    use dojo_cairo_test::{
        ContractDef, ContractDefTrait, NamespaceDef, TestResource, WorldStorageTestTrait,
        spawn_test_world,
    };
    use prophecy_roguelite::models::{
        Market, Position, Trader, LeaderboardEntry, m_Market, m_Position, m_Trader,
        m_LeaderboardEntry,
    };
    use prophecy_roguelite::systems::actions::{IActionsDispatcher, IActionsDispatcherTrait, actions};
    use starknet::ContractAddress;

    fn namespace_def() -> NamespaceDef {
        NamespaceDef {
            namespace: "prophecy_roguelite",
            resources: [
                TestResource::Model(m_Market::TEST_CLASS_HASH),
                TestResource::Model(m_Position::TEST_CLASS_HASH),
                TestResource::Model(m_Trader::TEST_CLASS_HASH),
                TestResource::Model(m_LeaderboardEntry::TEST_CLASS_HASH),
                TestResource::Event(actions::e_TraderCreated::TEST_CLASS_HASH),
                TestResource::Event(actions::e_PredictionPlaced::TEST_CLASS_HASH),
                TestResource::Event(actions::e_MarketResolved::TEST_CLASS_HASH),
                TestResource::Event(actions::e_PositionSettled::TEST_CLASS_HASH),
                TestResource::Contract(actions::TEST_CLASS_HASH),
            ]
                .span(),
        }
    }

    fn contract_defs() -> Span<ContractDef> {
        [
            ContractDefTrait::new(@"prophecy_roguelite", @"actions")
                .with_writer_of([dojo::utils::bytearray_hash(@"prophecy_roguelite")].span())
        ]
            .span()
    }

    fn setup() -> (dojo::world::WorldStorage, IActionsDispatcher, ContractAddress) {
        let caller: ContractAddress = 0.try_into().unwrap();
        let ndef = namespace_def();
        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [ndef].span());
        world.sync_perms_and_inits(contract_defs());
        let (contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address };
        (world, actions_system, caller)
    }

    #[test]
    fn test_create_trader() {
        let (world, actions, caller) = setup();

        actions.create_trader();

        let trader: Trader = world.read_model(caller);
        assert(trader.balance == 10000, 'balance should be 10000');
        assert(trader.total_wagered == 0, 'wagered should be 0');
        assert(trader.total_won == 0, 'won should be 0');
        assert(trader.total_lost == 0, 'lost should be 0');
        assert(trader.markets_played == 0, 'played should be 0');
        assert(trader.correct_predictions == 0, 'correct should be 0');
        assert(trader.streak == 0, 'streak should be 0');
        assert(trader.best_streak == 0, 'best_streak should be 0');
    }

    #[test]
    fn test_create_market() {
        let (world, actions, _) = setup();

        actions.create_market(1, 280, 140);

        let market: Market = world.read_model(1);
        assert(market.yes_odds == 280, 'yes_odds should be 280');
        assert(market.no_odds == 140, 'no_odds should be 140');
        assert(!market.is_resolved, 'should not be resolved');
        assert(!market.outcome, 'outcome should be false');
        assert(market.total_yes_amount == 0, 'total_yes should be 0');
        assert(market.total_no_amount == 0, 'total_no should be 0');
    }

    #[test]
    fn test_place_prediction() {
        let (world, actions, caller) = setup();

        actions.create_trader();
        actions.create_market(1, 280, 140);

        actions.place_prediction(1, true, 500);

        let trader: Trader = world.read_model(caller);
        assert(trader.balance == 9500, 'balance should be 9500');
        assert(trader.markets_played == 1, 'played should be 1');
        assert(trader.total_wagered == 500, 'wagered should be 500');

        let position: Position = world.read_model((caller, 1));
        assert(position.is_yes, 'should be YES');
        assert(position.amount == 500, 'amount should be 500');
        assert(!position.is_settled, 'should not be settled');

        let market: Market = world.read_model(1);
        assert(market.total_yes_amount == 500, 'total_yes should be 500');
        assert(market.total_no_amount == 0, 'total_no should be 0');
    }

    #[test]
    fn test_place_prediction_auto_settle() {
        let (world, actions, caller) = setup();

        actions.create_trader();
        actions.create_market(1, 280, 140);
        // Resolve market first (YES wins)
        actions.resolve_market(1, true);

        // Place YES prediction on resolved market → auto-settles
        actions.place_prediction(1, true, 500);

        let position: Position = world.read_model((caller, 1));
        assert(position.is_settled, 'should be auto-settled');
        // Payout = 500 * 280 / 100 = 1400
        assert(position.payout == 1400, 'payout should be 1400');

        let trader: Trader = world.read_model(caller);
        // Balance: 10000 - 500 (deducted) + 1400 (payout) = 10900
        assert(trader.balance == 10900, 'balance should be 10900');
        assert(trader.correct_predictions == 1, 'correct should be 1');
        assert(trader.streak == 1, 'streak should be 1');
    }

    #[test]
    fn test_claim_correct() {
        let (world, actions, caller) = setup();

        actions.create_trader();
        actions.create_market(1, 280, 140);

        // Place NO prediction
        actions.place_prediction(1, false, 1000);

        // Resolve market (NO wins → outcome=false)
        actions.resolve_market(1, false);

        // Claim
        actions.claim(1);

        let position: Position = world.read_model((caller, 1));
        assert(position.is_settled, 'should be settled');
        // Payout = 1000 * 140 / 100 = 1400
        assert(position.payout == 1400, 'payout should be 1400');

        let trader: Trader = world.read_model(caller);
        // Balance: 10000 - 1000 + 1400 = 10400
        assert(trader.balance == 10400, 'balance should be 10400');
        assert(trader.correct_predictions == 1, 'correct should be 1');
        assert(trader.streak == 1, 'streak should be 1');
        assert(trader.total_won == 1400, 'won should be 1400');
    }

    #[test]
    fn test_claim_wrong() {
        let (world, actions, caller) = setup();

        actions.create_trader();
        actions.create_market(1, 280, 140);

        // Place YES prediction
        actions.place_prediction(1, true, 500);

        // Resolve market (NO wins → outcome=false, so YES is wrong)
        actions.resolve_market(1, false);

        // Claim
        actions.claim(1);

        let position: Position = world.read_model((caller, 1));
        assert(position.is_settled, 'should be settled');
        assert(position.payout == 0, 'payout should be 0');

        let trader: Trader = world.read_model(caller);
        // Balance: 10000 - 500 = 9500 (no payout)
        assert(trader.balance == 9500, 'balance should be 9500');
        assert(trader.correct_predictions == 0, 'correct should be 0');
        assert(trader.streak == 0, 'streak should be 0');
        assert(trader.total_lost == 500, 'lost should be 500');
    }

    #[test]
    #[should_panic(expected: ("Already have a position on this market.", 'ENTRYPOINT_FAILED'))]
    fn test_cannot_double_bet() {
        let (_, actions, _) = setup();

        actions.create_trader();
        actions.create_market(1, 280, 140);

        actions.place_prediction(1, true, 500);
        // Second bet should fail
        actions.place_prediction(1, false, 500);
    }

    #[test]
    fn test_cash_out_early() {
        let (world, actions, caller) = setup();

        actions.create_trader();
        actions.create_market(1, 280, 140);

        // Place YES bet of $1000
        actions.place_prediction(1, true, 1000);

        // Cash out before resolution
        actions.cash_out_early(1);

        let position: Position = world.read_model((caller, 1));
        assert(position.is_settled, 'should be settled');
        // With $1000 on YES and $0 on NO: your_side=1000, other_side=0
        // raw = 1000 * (50 + 0*100/1000) / 100 = 1000*50/100 = 500 (min 50%)
        assert(position.payout == 500, 'payout should be 500');

        let trader: Trader = world.read_model(caller);
        // 10000 - 1000 + 500 = 9500
        assert(trader.balance == 9500, 'balance should be 9500');
        assert(trader.total_lost == 500, 'lost should be 500');
    }

    #[test]
    fn test_leaderboard_update() {
        let (world, actions, caller) = setup();

        actions.create_trader();
        actions.create_market(1, 280, 140);
        // Pre-resolve YES
        actions.resolve_market(1, true);

        // Place correct YES prediction → auto-settle → balance goes up
        actions.place_prediction(1, true, 1000);

        let entry: LeaderboardEntry = world.read_model(caller);
        // Balance after: 10000 - 1000 + 2800 = 11800
        assert(entry.high_score == 11800, 'high_score should be 11800');
        assert(entry.best_streak == 1, 'best_streak should be 1');
        assert(entry.total_runs == 1, 'total_runs should be 1');
    }
}
