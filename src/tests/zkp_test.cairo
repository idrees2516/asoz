use core::traits::Into;
use core::option::OptionTrait;
use core::array::ArrayTrait;
use core::debug::PrintTrait;

use super::super::constants::{PRIME, G, H};
use super::super::types::{Error, ZkProof};
use super::super::zkp::{ZkpTrait, ZkpSystem, RangeProofTrait, RangeProofSystem, NizkTrait, NizkSystem};
use super::super::crypto::utils::{pow_mod, generate_random_u256, hash_u256};

#[test]
fn test_membership_proof() {
    // Test parameters
    let pk = 123_u256;
    let sks = 456_u256;
    let p1 = 789_u256;
    let p2 = 321_u256;
    let sn1 = hash_u256(p1, sks);
    let sn2 = hash_u256(p2, sks);

    // Generate proof
    let proof = ZkpSystem::prove_membership(
        pk,
        sks,
        p1,
        p2,
        sn1,
        sn2,
        G,
        H
    ).unwrap();

    // Verify proof
    let result = ZkpSystem::verify_membership(
        proof,
        pk,
        sn1,
        sn2,
        G,
        H
    ).unwrap();

    assert(result == true, 'Membership proof failed');
}

#[test]
fn test_range_proof() {
    // Test parameters
    let value = 50_u256;
    let min = 0_u256;
    let max = 100_u256;

    // Generate proof
    let proof = RangeProofSystem::prove_range(
        value,
        min,
        max,
        G,
        H
    ).unwrap();

    // Calculate commitment
    let r = generate_random_u256();
    let commitment = pow_mod(G, value, PRIME) * pow_mod(H, r, PRIME) % PRIME;

    // Verify proof
    let result = RangeProofSystem::verify_range(
        proof,
        commitment,
        min,
        max,
        G,
        H
    ).unwrap();

    assert(result == true, 'Range proof failed');
}

#[test]
fn test_range_proof_out_of_bounds() {
    // Test parameters
    let value = 150_u256;  // Value outside range
    let min = 0_u256;
    let max = 100_u256;

    // Generate proof should fail
    let result = RangeProofSystem::prove_range(
        value,
        min,
        max,
        G,
        H
    );

    assert(result.is_err(), 'Range proof should fail');
}

#[test]
fn test_nizk_proof() {
    // Test parameters
    let statement = 123_u256;
    let witness = 456_u256;

    // Generate proof
    let proof = NizkSystem::prove(
        statement,
        witness,
        G,
        H
    ).unwrap();

    // Verify proof
    let result = NizkSystem::verify(
        proof,
        statement,
        G,
        H
    ).unwrap();

    assert(result == true, 'NIZK proof failed');
}

#[test]
fn test_membership_proof_invalid_params() {
    // Test parameters with invalid secret key
    let pk = 123_u256;
    let sks = 456_u256;
    let p1 = 789_u256;
    let p2 = 321_u256;
    let sn1 = hash_u256(p1, sks);
    let sn2 = hash_u256(p2, sks);

    // Generate proof with correct params
    let proof = ZkpSystem::prove_membership(
        pk,
        sks,
        p1,
        p2,
        sn1,
        sn2,
        G,
        H
    ).unwrap();

    // Verify proof with incorrect public key
    let wrong_pk = 999_u256;
    let result = ZkpSystem::verify_membership(
        proof,
        wrong_pk,
        sn1,
        sn2,
        G,
        H
    ).unwrap();

    assert(result == false, 'Invalid proof should fail');
}

#[test]
fn test_range_proof_edge_cases() {
    // Test edge case: value equals minimum
    let value = 0_u256;
    let min = 0_u256;
    let max = 100_u256;

    let proof = RangeProofSystem::prove_range(
        value,
        min,
        max,
        G,
        H
    ).unwrap();

    let r = generate_random_u256();
    let commitment = pow_mod(G, value, PRIME) * pow_mod(H, r, PRIME) % PRIME;

    let result = RangeProofSystem::verify_range(
        proof,
        commitment,
        min,
        max,
        G,
        H
    ).unwrap();

    assert(result == true, 'Min value range proof failed');

    // Test edge case: value equals maximum
    let value = max;
    let proof = RangeProofSystem::prove_range(
        value,
        min,
        max,
        G,
        H
    ).unwrap();

    let r = generate_random_u256();
    let commitment = pow_mod(G, value, PRIME) * pow_mod(H, r, PRIME) % PRIME;

    let result = RangeProofSystem::verify_range(
        proof,
        commitment,
        min,
        max,
        G,
        H
    ).unwrap();

    assert(result == true, 'Max value range proof failed');
}

#[test]
fn test_nizk_proof_malleability() {
    // Test parameters
    let statement = 123_u256;
    let witness = 456_u256;

    // Generate first proof
    let proof1 = NizkSystem::prove(
        statement,
        witness,
        G,
        H
    ).unwrap();

    // Generate second proof with same parameters
    let proof2 = NizkSystem::prove(
        statement,
        witness,
        G,
        H
    ).unwrap();

    // Verify both proofs are valid but different (non-malleable)
    let result1 = NizkSystem::verify(
        proof1,
        statement,
        G,
        H
    ).unwrap();

    let result2 = NizkSystem::verify(
        proof2,
        statement,
        G,
        H
    ).unwrap();

    assert(result1 == true, 'First NIZK proof failed');
    assert(result2 == true, 'Second NIZK proof failed');
    assert(proof1.c != proof2.c, 'Proofs should be different');
}
