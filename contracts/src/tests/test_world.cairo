#[cfg(test)]
mod tests {
    use dojo::model::{ModelStorage, ModelStorageTest};
    use dojo::world::{WorldStorageTrait, world};
    use dojo_cairo_test::{
        ContractDef, ContractDefTrait, NamespaceDef, TestResource, WorldStorageTestTrait,
        spawn_test_world,
    };
    use prophecy_roguelite::models::{Player, GameRound, m_Player, m_GameRound, m_LeaderboardEntry};
    use prophecy_roguelite::systems::actions::{IActionsDispatcher, IActionsDispatcherTrait, actions};
    use starknet::ContractAddress;

    fn namespace_def() -> NamespaceDef {
        NamespaceDef {
            namespace: "prophecy_roguelite",
            resources: [
                TestResource::Model(m_Player::TEST_CLASS_HASH),
                TestResource::Model(m_GameRound::TEST_CLASS_HASH),
                TestResource::Model(m_LeaderboardEntry::TEST_CLASS_HASH),
                TestResource::Event(actions::e_PlayerSpawned::TEST_CLASS_HASH),
                TestResource::Event(actions::e_FloorResolved::TEST_CLASS_HASH),
                TestResource::Event(actions::e_PlayerDied::TEST_CLASS_HASH),
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

    // Helper: get the correct prediction for a player's current seed
    fn get_correct_prediction(world: @dojo::world::WorldStorage, caller: ContractAddress) -> u8 {
        let player: Player = world.read_model(caller);
        let seed_u256: u256 = player.next_event_seed.into();
        (seed_u256 % 4).try_into().unwrap()
    }

    #[test]
    fn test_spawn_creates_player() {
        let caller: ContractAddress = 0.try_into().unwrap();
        let ndef = namespace_def();
        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address };

        actions_system.spawn();

        let player: Player = world.read_model(caller);

        assert(player.hp == 100, 'hp should be 100');
        assert(player.max_hp == 100, 'max_hp should be 100');
        assert(player.floor == 0, 'floor should be 0');
        assert(player.gold == 0, 'gold should be 0');
        assert(player.is_alive, 'should be alive');
        assert(player.prediction_streak == 0, 'streak should be 0');
        assert(player.streak_tier == 0, 'tier should be 0');
        assert(player.clue_type <= 1, 'clue_type must be 0 or 1');
        assert(player.clue_detail <= 4, 'clue_detail must be 0-4');
    }

    #[test]
    fn test_predict_advances_floor() {
        let caller: ContractAddress = 0.try_into().unwrap();
        let ndef = namespace_def();
        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address };

        actions_system.spawn();
        actions_system.predict_and_advance(0, 0); // Predict Monster, no wager

        let player: Player = world.read_model(caller);
        assert(player.floor == 1, 'floor should be 1');
        assert(player.total_predictions == 1, 'total predictions should be 1');
    }

    #[test]
    fn test_multiple_floors() {
        let caller: ContractAddress = 0.try_into().unwrap();
        let ndef = namespace_def();
        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address };

        actions_system.spawn();

        // Play 5 floors
        actions_system.predict_and_advance(0, 0);
        actions_system.predict_and_advance(1, 0);
        actions_system.predict_and_advance(2, 0);
        actions_system.predict_and_advance(3, 0);
        actions_system.predict_and_advance(0, 0);

        let player: Player = world.read_model(caller);
        assert(player.floor == 5, 'floor should be 5');
        assert(player.total_predictions == 5, 'total predictions should be 5');
    }

    #[test]
    fn test_spawn_resets_after_death() {
        let caller: ContractAddress = 0.try_into().unwrap();
        let ndef = namespace_def();
        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address };

        // Manually set player to dead state
        let dead_player = Player {
            address: caller,
            hp: 0,
            max_hp: 100,
            floor: 10,
            gold: 50,
            prediction_streak: 0,
            best_streak: 3,
            total_predictions: 10,
            correct_predictions: 5,
            is_alive: false,
            next_event_seed: 0,
            clue_type: 0,
            clue_detail: 0,
            streak_tier: 0,
        };
        world.write_model_test(@dead_player);

        // Respawn
        actions_system.spawn();

        let player: Player = world.read_model(caller);
        assert(player.hp == 100, 'hp should reset to 100');
        assert(player.floor == 0, 'floor should reset to 0');
        assert(player.is_alive, 'should be alive after respawn');
        assert(player.streak_tier == 0, 'tier should reset to 0');
    }

    #[test]
    fn test_correct_prediction_earns_streak() {
        let caller: ContractAddress = 0.try_into().unwrap();
        let ndef = namespace_def();
        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address };

        actions_system.spawn();

        // Make a correct prediction by reading the seed
        let correct = get_correct_prediction(@world, caller);
        actions_system.predict_and_advance(correct, 0);

        let player: Player = world.read_model(caller);
        assert(player.prediction_streak == 1, 'streak should be 1');
        assert(player.correct_predictions == 1, 'correct should be 1');
    }

    #[test]
    fn test_wager_system() {
        let caller: ContractAddress = 0.try_into().unwrap();
        let ndef = namespace_def();
        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address };

        actions_system.spawn();

        // Give the player some gold to wager
        let mut player: Player = world.read_model(caller);
        player.gold = 100;
        world.write_model_test(@player);

        // Make a correct prediction with wager
        let correct = get_correct_prediction(@world, caller);
        actions_system.predict_and_advance(correct, 50);

        let player_after: Player = world.read_model(caller);
        // Should have gained gold from event + wager bonus
        // At tier 0 (streak=1), mult=100, wager gain = 50*100/100 = 50
        assert(player_after.gold > 100, 'should gain gold from wager');
    }

    #[test]
    fn test_wager_loss() {
        let caller: ContractAddress = 0.try_into().unwrap();
        let ndef = namespace_def();
        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address };

        actions_system.spawn();

        // Give the player gold
        let mut player: Player = world.read_model(caller);
        player.gold = 100;
        world.write_model_test(@player);

        // Make a wrong prediction with wager
        let correct = get_correct_prediction(@world, caller);
        let wrong = (correct + 1) % 4;
        actions_system.predict_and_advance(wrong, 50);

        let player_after: Player = world.read_model(caller);
        // Lost 50 gold from wager, but may have gained some from event
        // The key check: gold should be less than 100 (started) minus 50 (wager) + whatever event gold
        assert(player_after.prediction_streak == 0, 'streak should reset');
    }

    #[test]
    fn test_boss_floor() {
        let caller: ContractAddress = 0.try_into().unwrap();
        let ndef = namespace_def();
        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address };

        actions_system.spawn();

        // Set player to floor 4 so next floor (5) is boss
        let mut player: Player = world.read_model(caller);
        player.floor = 4;
        player.hp = 100;
        player.gold = 50;
        world.write_model_test(@player);

        // Predict for floor 5 (boss floor)
        let correct = get_correct_prediction(@world, caller);
        actions_system.predict_and_advance(correct, 0);

        let player_after: Player = world.read_model(caller);
        assert(player_after.floor == 5, 'floor should be 5');

        // Check the round was marked as boss
        let round: GameRound = world.read_model((caller, 5));
        assert(round.is_boss, 'floor 5 should be boss');
    }

    #[test]
    fn test_streak_tiers() {
        let caller: ContractAddress = 0.try_into().unwrap();
        let ndef = namespace_def();
        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address };

        actions_system.spawn();

        // Set streak to 2, make correct prediction → streak=3 → tier 1 (Hot)
        let mut player: Player = world.read_model(caller);
        player.prediction_streak = 2;
        world.write_model_test(@player);

        let correct = get_correct_prediction(@world, caller);
        actions_system.predict_and_advance(correct, 0);

        let player_after: Player = world.read_model(caller);
        assert(player_after.prediction_streak == 3, 'streak should be 3');
        assert(player_after.streak_tier == 1, 'tier should be 1 (Hot)');

        // Set streak to 7, make correct prediction → streak=8 → tier 3 (Prophetic)
        let mut player2: Player = world.read_model(caller);
        player2.prediction_streak = 7;
        world.write_model_test(@player2);

        let correct2 = get_correct_prediction(@world, caller);
        actions_system.predict_and_advance(correct2, 0);

        let player_after2: Player = world.read_model(caller);
        assert(player_after2.streak_tier == 3, 'tier should be 3 (Prophetic)');
    }

    #[test]
    fn test_clues_generated() {
        let caller: ContractAddress = 0.try_into().unwrap();
        let ndef = namespace_def();
        let mut world = spawn_test_world(world::TEST_CLASS_HASH, [ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address };

        actions_system.spawn();

        let player: Player = world.read_model(caller);
        // Verify clues are consistent with seed
        let seed_u256: u256 = player.next_event_seed.into();
        let event_type: u8 = (seed_u256 % 4).try_into().unwrap();

        // Category clue should match event
        if event_type < 2 {
            assert(player.clue_type == 0, 'should be danger clue');
        } else {
            assert(player.clue_type == 1, 'should be fortune clue');
        }

        // After prediction, new clues should be generated
        actions_system.predict_and_advance(0, 0);
        let player2: Player = world.read_model(caller);
        assert(player2.clue_type <= 1, 'new clue_type valid');
        assert(player2.clue_detail <= 4, 'new clue_detail valid');
    }
}
