use starknet::ContractAddress;

// Event types that can appear on each floor
#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum EventType {
    #[default]
    Monster,
    Trap,
    Treasure,
    Heal,
}

// Player state - the core entity
#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct Player {
    #[key]
    pub address: ContractAddress,
    pub hp: u32,
    pub max_hp: u32,
    pub floor: u32,
    pub gold: u32,
    pub prediction_streak: u32,
    pub best_streak: u32,
    pub total_predictions: u32,
    pub correct_predictions: u32,
    pub is_alive: bool,
    pub next_event_seed: felt252,  // pre-committed seed for next floor's event
    pub clue_type: u8,            // 0=danger, 1=fortune
    pub clue_detail: u8,          // 0=none, 1=notMonster, 2=notTrap, 3=notTreasure, 4=notHeal
    pub streak_tier: u8,          // 0=Normal, 1=Hot, 2=Blazing, 3=Prophetic
}

// Record of each floor encounter
#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct GameRound {
    #[key]
    pub address: ContractAddress,
    #[key]
    pub floor: u32,
    pub event_type: EventType,
    pub player_prediction: EventType,
    pub damage_dealt: u32,
    pub gold_earned: u32,
    pub hp_healed: u32,
    pub was_correct: bool,
    pub wager_amount: u32,
    pub is_boss: bool,
}

// Persistent leaderboard across runs
#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct LeaderboardEntry {
    #[key]
    pub address: ContractAddress,
    pub high_score: u32,
    pub highest_floor: u32,
    pub best_streak: u32,
    pub total_runs: u32,
}

// Convert u8 to EventType
pub fn event_type_from_u8(val: u8) -> EventType {
    if val == 0 {
        EventType::Monster
    } else if val == 1 {
        EventType::Trap
    } else if val == 2 {
        EventType::Treasure
    } else {
        EventType::Heal
    }
}

// Convert EventType to u8 for comparison
pub fn event_type_to_u8(event: EventType) -> u8 {
    match event {
        EventType::Monster => 0,
        EventType::Trap => 1,
        EventType::Treasure => 2,
        EventType::Heal => 3,
    }
}

impl EventTypeIntoFelt252 of Into<EventType, felt252> {
    fn into(self: EventType) -> felt252 {
        match self {
            EventType::Monster => 0,
            EventType::Trap => 1,
            EventType::Treasure => 2,
            EventType::Heal => 3,
        }
    }
}
