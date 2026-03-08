use starknet::ContractAddress;

// A prediction market with YES/NO outcome
#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct Market {
    #[key]
    pub market_id: u32,
    pub yes_odds: u32,         // basis points: 280 = 2.8x payout
    pub no_odds: u32,
    pub is_resolved: bool,
    pub outcome: bool,         // true = YES won
    pub total_yes_amount: u32, // total wagered on YES
    pub total_no_amount: u32,  // total wagered on NO
}

// A player's position on a specific market
#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct Position {
    #[key]
    pub player: ContractAddress,
    #[key]
    pub market_id: u32,
    pub is_yes: bool,
    pub amount: u32,
    pub is_settled: bool,
    pub payout: u32,
}

// Trader state (virtual balance + stats)
#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct Trader {
    #[key]
    pub address: ContractAddress,
    pub balance: u32,          // starts at 10000
    pub total_wagered: u32,
    pub total_won: u32,
    pub total_lost: u32,
    pub markets_played: u32,
    pub correct_predictions: u32,
    pub streak: u32,
    pub best_streak: u32,
}

// Player relics / power-ups inventory
#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct Relics {
    #[key]
    pub address: ContractAddress,
    pub leverage_tokens: u32,  // 3x payout multiplier
    pub stop_loss: u32,        // prevent loss (refund wager)
    pub insider_info: u32,     // reveal correct answer
}

// Global World Boss — shared prediction market all players bet on
// Uses market_id=0 as the singleton key
#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct WorldBoss {
    #[key]
    pub boss_id: u32,              // always 0 (singleton)
    pub title_id: u32,             // which boss question is active
    pub total_yes: u32,            // total players who bet YES
    pub total_no: u32,             // total players who bet NO
    pub total_yes_amount: u32,     // total $ wagered on YES
    pub total_no_amount: u32,      // total $ wagered on NO
    pub is_resolved: bool,
    pub outcome: bool,
    // Last 5 bettors (ring buffer — newest at slot (total_yes+total_no-1) % 5)
    pub recent_0: ContractAddress,
    pub recent_1: ContractAddress,
    pub recent_2: ContractAddress,
    pub recent_3: ContractAddress,
    pub recent_4: ContractAddress,
}

// Persistent leaderboard across all trading
#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct LeaderboardEntry {
    #[key]
    pub address: ContractAddress,
    pub high_score: u32,       // best balance ever achieved
    pub highest_floor: u32,    // kept for compat, repurposed as markets_played
    pub best_streak: u32,
    pub total_runs: u32,       // kept for compat, repurposed as total settled
}
