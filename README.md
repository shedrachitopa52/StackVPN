A trustless, decentralized VPN protocol built on the Stacks blockchain using Clarity.
ClariNet allows node providers to monetize their bandwidth and users to securely purchase VPN sessions without intermediaries.
It ensures transparent payments, reputation tracking, and accountability through staking and smart contract logic.

🚀 Features
🛰 Node Management

Register a VPN node with minimum stake requirement.

Update node parameters (price, bandwidth, region).

Activate or deactivate availability.

Withdraw stake (only when inactive).

🔐 VPN Sessions

Users can start prepaid VPN sessions by block intervals.

Sessions track start block, end block, duration, and payment.

Unused prepaid balance is refunded automatically.

Providers receive payments instantly after session end.

💰 Payments & Earnings

Node operators earn STX for completed sessions.

Secure withdrawals of accumulated earnings.

Slashing mechanism to penalize misbehavior (admin-enforced).

⭐ Reputation System

Users can rate nodes (1–5) after sessions.

Ratings aggregate into an average score per provider.

Reputation influences trustworthiness & user choice.

⚙️ Governance & Security

Admin functions: slashing bad actors, ownership transfer, and emergency withdrawals.

Contract is fully transparent with on-chain event logging.

📦 Contract Structure
;; Core Modules:
- Node Registration & Updates
- Session Lifecycle (start, end, refund)
- Earnings & Withdrawals
- Ratings & Reputation
- Stake Management & Slashing

📊 Data Models

nodes → Stores node metadata, stake, status.

sessions → Tracks active and completed VPN sessions.

earnings → Accumulated STX earnings per provider.

ratings → User ratings and aggregated scores.

🛠 Usage
1. Register as a Node
(register-node price bandwidth region stake)

2. Start a VPN Session
(start-session node-id blocks-prepaid)

3. End Session
(end-session session-id)

4. Rate a Node
(rate-node node-id rating)

5. Withdraw Earnings
(withdraw-earnings amount to)

✅ Error Handling

Common error codes:

u100 → Insufficient STX

u101 → Not authorized (not owner)

u102 → Invalid session or node

u103 → Node inactive

u104 → Transfer failed

🧭 Future Improvements

Oracle-based randomized slashing / proof-of-misbehavior.

Integration with Decentralized Identity (DID) for node reputation.

DAO governance for protocol upgrades.
