use core::traits::Into;
use core::option::OptionTrait;
use core::array::ArrayTrait;
use starknet::ContractAddress;

// Core types for the ASOZ system

#[derive(Copy, Drop, Serde, PartialEq)]
struct Address {
    pk: u256,
    sk: u256
}

#[derive(Copy, Drop, Serde, PartialEq)]
struct AuditAddress {
    upk: u256,
    usk: u256,
    revocation_key: u256
}

#[derive(Copy, Drop, Serde)]
struct Commitment {
    value: u256,
    rand: u256,
    pk: u256,
    cm: u256
}

#[derive(Copy, Drop, Serde)]
struct Transaction {
    cm_old1: u256,
    cm_old2: u256,
    cm_new: u256,
    sn_1: u256,
    sn_2: u256,
    requation: u256,
    c_value: (u256, u256),
    c_content: (u256, u256),
    c_sender: (u256, u256),
    c_receiver: (u256, u256),
    proof: (u256, u256, u256, u256, u256, u256),
    p_new: u256
}

#[derive(Copy, Drop, Serde)]
struct ZkProof {
    a: u256,
    z1: u256,
    z2: u256,
    z3: u256,
    c: u256
}

#[derive(Copy, Drop, Serde)]
struct RingSignature {
    c: u256,
    s: Array<u256>
}

#[derive(Copy, Drop, Serde)]
struct AuditData {
    value: u256,
    pk_sender: u256,
    pk_receiver: u256,
    timestamp: u64,
    auditor: ContractAddress
}

#[derive(Copy, Drop, Serde)]
struct Parameters {
    g: u256,
    h: u256,
    threshold: u32,
    min_stake: u256,
    audit_period: u64
}

#[derive(Copy, Drop, Serde)]
struct ShareInfo {
    index: u32,
    value: u256,
    verification_value: u256
}

#[derive(Copy, Drop, Serde)]
struct MerkleProof {
    root: u256,
    leaf: u256,
    path: Array<(bool, u256)>
}

#[derive(Copy, Drop, Serde)]
struct AuditorInfo {
    address: ContractAddress,
    stake: u256,
    reputation: u256,
    last_active: u64,
    shares: Array<ShareInfo>,
    status: AuditorStatus
}

#[derive(Copy, Drop, Serde, PartialEq)]
enum AuditorStatus {
    Active,
    Suspended,
    Revoked
}

#[derive(Copy, Drop, Serde)]
struct RevocationCertificate {
    key_hash: u256,
    timestamp: u64,
    signatures: Array<(ContractAddress, Array<u256>)>
}

// Error types for the system
#[derive(Copy, Drop, Serde, PartialEq)]
enum Error {
    InvalidInput,
    InvalidProof,
    InvalidSignature,
    InvalidCommitment,
    InvalidTransaction,
    InvalidAuditor,
    InsufficientStake,
    UnauthorizedAccess,
    AlreadyExists,
    NotFound,
    RevocationError,
    SystemError
}

// Events for the system
#[event]
#[derive(Drop, starknet::Event)]
enum Event {
    AddressCreated: AddressCreated,
    AuditAddressCreated: AuditAddressCreated,
    TransactionCreated: TransactionCreated,
    TransactionVerified: TransactionVerified,
    AuditorRegistered: AuditorRegistered,
    AuditorRevoked: AuditorRevoked,
    StakeUpdated: StakeUpdated,
    ParametersUpdated: ParametersUpdated
}

#[derive(Drop, starknet::Event)]
struct AddressCreated {
    #[key]
    address: ContractAddress,
    pk: u256
}

#[derive(Drop, starknet::Event)]
struct AuditAddressCreated {
    #[key]
    address: ContractAddress,
    upk: u256
}

#[derive(Drop, starknet::Event)]
struct TransactionCreated {
    #[key]
    tx_hash: u256,
    cm_new: u256,
    timestamp: u64
}

#[derive(Drop, starknet::Event)]
struct TransactionVerified {
    #[key]
    tx_hash: u256,
    auditor: ContractAddress,
    status: bool
}

#[derive(Drop, starknet::Event)]
struct AuditorRegistered {
    #[key]
    address: ContractAddress,
    stake: u256,
    timestamp: u64
}

#[derive(Drop, starknet::Event)]
struct AuditorRevoked {
    #[key]
    address: ContractAddress,
    reason: u8,
    timestamp: u64
}

#[derive(Drop, starknet::Event)]
struct StakeUpdated {
    #[key]
    address: ContractAddress,
    old_stake: u256,
    new_stake: u256
}

#[derive(Drop, starknet::Event)]
struct ParametersUpdated {
    g: u256,
    h: u256,
    threshold: u32,
    min_stake: u256,
    audit_period: u64
}
