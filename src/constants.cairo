// Core system constants

// Cryptographic constants
const MERKLE_TREE_DEPTH: u32 = 32;
const PRIME: u256 = 36185027886661311069865932815214971204146908111094446254998549168858692987403_u256;
const SEC_P: u256 = 115792089237316195423570985008687907852837564279074904382605163141518161494337_u256;

// Generator points for the curve
const G: u256 = 2_u256;  // Base generator point
const H: u256 = 3_u256;  // Secondary generator point

// System parameters
const MIN_STAKE: u256 = 1000000000000000000_u256;  // Minimum stake required for auditors (1 ETH)
const MIN_REPUTATION: u256 = 100_u256;  // Minimum reputation required for active auditors
const AUDIT_PERIOD: u64 = 86400;  // Default audit period (24 hours)
const MAX_AUDITORS: u32 = 100;  // Maximum number of auditors in the system
const MIN_AUDITORS: u32 = 3;  // Minimum number of auditors required for the system
const DEFAULT_THRESHOLD: u32 = 2;  // Default threshold for auditor consensus

// Timeouts and delays
const KEY_REFRESH_PERIOD: u64 = 604800;  // Key refresh period (7 days)
const REVOCATION_DELAY: u64 = 3600;  // Delay before revocation takes effect (1 hour)
const CHALLENGE_PERIOD: u64 = 86400;  // Period for challenging a transaction (24 hours)
const RESPONSE_TIMEOUT: u64 = 3600;  // Timeout for auditor responses (1 hour)

// Economic parameters
const PENALTY_AMOUNT: u256 = 100000000000000000_u256;  // Penalty for misbehavior (0.1 ETH)
const REWARD_AMOUNT: u256 = 10000000000000000_u256;  // Reward for successful audit (0.01 ETH)
const MIN_TRANSACTION_VALUE: u256 = 1000000000000000_u256;  // Minimum transaction value (0.001 ETH)

// Protocol version
const PROTOCOL_VERSION: felt252 = 'ASOZ_v1.0';

// Error codes
const ERR_INVALID_INPUT: felt252 = 'Invalid input';
const ERR_INVALID_PROOF: felt252 = 'Invalid proof';
const ERR_INVALID_SIGNATURE: felt252 = 'Invalid signature';
const ERR_INVALID_COMMITMENT: felt252 = 'Invalid commitment';
const ERR_INVALID_TRANSACTION: felt252 = 'Invalid transaction';
const ERR_INVALID_AUDITOR: felt252 = 'Invalid auditor';
const ERR_INSUFFICIENT_STAKE: felt252 = 'Insufficient stake';
const ERR_UNAUTHORIZED: felt252 = 'Unauthorized access';
const ERR_ALREADY_EXISTS: felt252 = 'Already exists';
const ERR_NOT_FOUND: felt252 = 'Not found';
const ERR_REVOCATION_ERROR: felt252 = 'Revocation error';
const ERR_SYSTEM_ERROR: felt252 = 'System error';
