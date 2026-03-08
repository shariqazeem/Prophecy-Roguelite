#!/bin/bash
# Seed markets 16-75 on Slot (Katana)
# Markets 16-50: pre-resolved trivia → create_market + resolve_market
# Markets 51-75: open predictions → create_market only

RPC="https://api.cartridge.gg/x/prophecy-roguelite/katana"
TAG="prophecy_roguelite-actions"
MANIFEST="contracts/Scarb.toml"
DELAY=0.3

run_sozo() {
    local result
    result=$(sozo execute --wait --rpc-url "$RPC" --manifest-path "$MANIFEST" "$TAG" "$@" 2>&1)
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "  FAILED: $result" | tail -3
        return 1
    else
        echo "  OK: $(echo "$result" | head -1)"
        return 0
    fi
}

# Odds: market_id yes_odds no_odds
declare -A ODDS_YES ODDS_NO
ODDS_YES[16]=150; ODDS_NO[16]=260
ODDS_YES[17]=190; ODDS_NO[17]=200
ODDS_YES[18]=200; ODDS_NO[18]=190
ODDS_YES[19]=300; ODDS_NO[19]=140
ODDS_YES[20]=250; ODDS_NO[20]=160
ODDS_YES[21]=180; ODDS_NO[21]=220
ODDS_YES[22]=160; ODDS_NO[22]=250
ODDS_YES[23]=210; ODDS_NO[23]=180
ODDS_YES[24]=170; ODDS_NO[24]=230
ODDS_YES[25]=190; ODDS_NO[25]=200
ODDS_YES[26]=220; ODDS_NO[26]=180
ODDS_YES[27]=200; ODDS_NO[27]=190
ODDS_YES[28]=160; ODDS_NO[28]=250
ODDS_YES[29]=180; ODDS_NO[29]=210
ODDS_YES[30]=230; ODDS_NO[30]=170
ODDS_YES[31]=280; ODDS_NO[31]=140
ODDS_YES[32]=240; ODDS_NO[32]=160
ODDS_YES[33]=190; ODDS_NO[33]=200
ODDS_YES[34]=210; ODDS_NO[34]=180
ODDS_YES[35]=150; ODDS_NO[35]=260
ODDS_YES[36]=220; ODDS_NO[36]=180
ODDS_YES[37]=170; ODDS_NO[37]=230
ODDS_YES[38]=250; ODDS_NO[38]=160
ODDS_YES[39]=230; ODDS_NO[39]=170
ODDS_YES[40]=160; ODDS_NO[40]=240
ODDS_YES[41]=180; ODDS_NO[41]=220
ODDS_YES[42]=150; ODDS_NO[42]=270
ODDS_YES[43]=200; ODDS_NO[43]=190
ODDS_YES[44]=240; ODDS_NO[44]=160
ODDS_YES[45]=170; ODDS_NO[45]=230
ODDS_YES[46]=190; ODDS_NO[46]=200
ODDS_YES[47]=210; ODDS_NO[47]=180
ODDS_YES[48]=220; ODDS_NO[48]=180
ODDS_YES[49]=180; ODDS_NO[49]=210
ODDS_YES[50]=200; ODDS_NO[50]=190
ODDS_YES[51]=180; ODDS_NO[51]=220
ODDS_YES[52]=300; ODDS_NO[52]=140
ODDS_YES[53]=250; ODDS_NO[53]=160
ODDS_YES[54]=150; ODDS_NO[54]=260
ODDS_YES[55]=220; ODDS_NO[55]=180
ODDS_YES[56]=200; ODDS_NO[56]=190
ODDS_YES[57]=140; ODDS_NO[57]=280
ODDS_YES[58]=170; ODDS_NO[58]=230
ODDS_YES[59]=130; ODDS_NO[59]=300
ODDS_YES[60]=280; ODDS_NO[60]=140
ODDS_YES[61]=190; ODDS_NO[61]=200
ODDS_YES[62]=210; ODDS_NO[62]=180
ODDS_YES[63]=250; ODDS_NO[63]=160
ODDS_YES[64]=140; ODDS_NO[64]=290
ODDS_YES[65]=300; ODDS_NO[65]=140
ODDS_YES[66]=160; ODDS_NO[66]=250
ODDS_YES[67]=270; ODDS_NO[67]=150
ODDS_YES[68]=170; ODDS_NO[68]=230
ODDS_YES[69]=220; ODDS_NO[69]=180
ODDS_YES[70]=190; ODDS_NO[70]=210
ODDS_YES[71]=280; ODDS_NO[71]=140
ODDS_YES[72]=320; ODDS_NO[72]=130
ODDS_YES[73]=200; ODDS_NO[73]=190
ODDS_YES[74]=140; ODDS_NO[74]=290
ODDS_YES[75]=230; ODDS_NO[75]=170

# Pre-resolved outcomes: market_id → 1 (YES) or 0 (NO)
declare -A OUTCOMES
OUTCOMES[16]=1  # Bananas are radioactive → YES
OUTCOMES[17]=0  # Lightning never strikes same place → NO
OUTCOMES[18]=0  # Vikings horned helmets → NO
OUTCOMES[19]=1  # Oxford older than Aztec → YES
OUTCOMES[20]=1  # Russia > Pluto surface → YES
OUTCOMES[21]=0  # Africa < Moon surface → NO
OUTCOMES[22]=1  # Shrimp heart in head → YES
OUTCOMES[23]=0  # Bats are blind → NO
OUTCOMES[24]=1  # Pringles inventor buried in can → YES
OUTCOMES[25]=1  # Golf ball 300+ dimples → YES
OUTCOMES[26]=1  # 60% DNA with bananas → YES
OUTCOMES[27]=0  # Napoleon short → NO
OUTCOMES[28]=1  # Venus day > year → YES
OUTCOMES[29]=1  # Eiffel Tower grows in summer → YES
OUTCOMES[30]=0  # Bulls enraged by red → NO
OUTCOMES[31]=1  # Sharks older than trees → YES
OUTCOMES[32]=0  # Chameleons blend in → NO
OUTCOMES[33]=1  # Great Pyramid tallest 3800 years → YES
OUTCOMES[34]=0  # Lemmings mass suicide → NO
OUTCOMES[35]=1  # More chess games than atoms → YES
OUTCOMES[36]=0  # Humans use 10% brain → NO
OUTCOMES[37]=1  # Scotland unicorn → YES
OUTCOMES[38]=0  # Amazon longest river → NO (Nile)
OUTCOMES[39]=0  # Everest tallest base-to-peak → NO (Mauna Kea)
OUTCOMES[40]=1  # Strawberry not a berry → YES
OUTCOMES[41]=1  # Olympics art medals → YES
OUTCOMES[42]=1  # Wombat cube poop → YES
OUTCOMES[43]=0  # Einstein failed math → NO
OUTCOMES[44]=0  # Cleopatra Egyptian → NO (Greek/Macedonian)
OUTCOMES[45]=1  # Flamingos flamboyance → YES
OUTCOMES[46]=0  # Sound in space → NO
OUTCOMES[47]=1  # 38-minute war → YES
OUTCOMES[48]=0  # Peanuts are nuts → NO (legumes)
OUTCOMES[49]=1  # Hot water freezes faster → YES (Mpemba)
OUTCOMES[50]=1  # Body iron = nail → YES

FAIL_COUNT=0

echo "=== Creating markets 17-75 (16 already created) ==="
for mid in $(seq 17 75); do
    echo "Creating market $mid (YES=${ODDS_YES[$mid]} NO=${ODDS_NO[$mid]})"
    if ! run_sozo create_market "$mid" "${ODDS_YES[$mid]}" "${ODDS_NO[$mid]}"; then
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    sleep $DELAY
done

echo ""
echo "=== Resolving markets 16-50 ==="
for mid in $(seq 16 50); do
    echo "Resolving market $mid (outcome=${OUTCOMES[$mid]})"
    if ! run_sozo resolve_market "$mid" "${OUTCOMES[$mid]}"; then
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    sleep $DELAY
done

echo ""
echo "=== Done! ==="
echo "Failures: $FAIL_COUNT"
