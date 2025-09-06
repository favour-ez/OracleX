# OracleX - Decentralized Prediction Market

## Overview

OracleX is a decentralized prediction market smart contract where users can create markets on real-world or future events, define possible outcomes, and stake tokens on the results. When markets resolve, winnings are distributed proportionally among participants who backed the correct outcome. The system enforces fair participation with clear resolution rules and transparent payouts.

## Key Features

* **Market Creation**: Anyone can create a market by defining a question, number of outcomes, and a resolution date.
* **Outcome Definition**: Market creators specify possible outcomes with short descriptions.
* **Staking Mechanism**: Users stake STX tokens on outcomes before the resolution block.
* **Market Resolution**: Once the resolution date passes, the market creator finalizes the winning outcome.
* **Payout Distribution**: Users who staked on the winning outcome claim proportional rewards.
* **Validation Checks**: Built-in error handling prevents invalid parameters, expired bets, and double claims.

## Contract Components

### Error Codes

* `ERR-NOT-FOUND` – Market or outcome not found.
* `ERR-UNAUTHORIZED` – Action attempted by an unauthorized user.
* `ERR-INVALID-PARAMS` – Invalid inputs (zero amounts, bad IDs, empty descriptions).
* `ERR-MARKET-RESOLVED` – Market already resolved.
* `ERR-MARKET-EXPIRED` – Market expired before staking attempt.
* `ERR-TOO-EARLY` – Market cannot be resolved before resolution block.
* `ERR-NO-POSITION` – User has no position in a market.
* `ERR-INSUFFICIENT-BALANCE` – Not enough balance to stake.
* `ERR-TRANSFER-FAILED` – STX transfer failed.

### Data Structures

* **Markets**: Stores metadata (creator, question, outcome count, resolution block, total staked, resolution status).
* **Outcomes**: Each outcome tied to a market, with description and total staked.
* **User Positions**: Tracks user stakes per market and outcome.
* **Market Counter**: Tracks total number of markets created.

## Functions

### Market Lifecycle

* `create-market (question outcome-count blocks-until-resolution)`
  Creates a new market with specified outcomes and resolution time.

* `define-outcome (market-id outcome-id description)`
  Market creator defines valid outcomes with descriptions.

* `stake-on-outcome (market-id outcome-id amount)`
  Users stake tokens on their chosen outcome. Funds are transferred to contract custody.

* `resolve-market (market-id winning-outcome)`
  Market creator finalizes the winning outcome once the resolution block has passed.

* `claim-winnings (market-id)`
  Users who staked on the winning outcome can claim proportional rewards.

### Read-Only Queries

* `get-market (market-id)` – Fetch full market details.
* `get-outcome (market-id outcome-id)` – Retrieve outcome details.
* `get-user-position (market-id outcome-id user)` – Check a user’s stake.
* `get-market-count` – Total number of markets created.
* `is-market-active (market-id)` – Check if a market is still open for staking.

## Usage Flow

1. **Market Creation**: Creator defines event question and resolution parameters.
2. **Outcome Definition**: Creator adds outcomes tied to the market.
3. **Staking Phase**: Users buy positions by staking STX before expiration.
4. **Resolution**: After resolution block, creator finalizes the winning outcome.
5. **Payouts**: Users claim winnings proportionally from the total staked pool.

## Security & Safeguards

* Prevents empty questions or outcomes.
* Disallows staking after resolution block.
* Ensures payouts are proportional and prevents overflow in reward calculation.
* Resets user positions after claiming to block double rewards.
* Only market creators can resolve their own markets.

OracleX brings open, trustless betting on future events, secured by blockchain transparency and automated payouts.
