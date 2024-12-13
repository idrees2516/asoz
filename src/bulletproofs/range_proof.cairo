use core::traits::Into;
use core::option::OptionTrait;
use core::array::ArrayTrait;
use super::super::constants::{PRIME, G, H};
use super::super::crypto::utils::{pow_mod, generate_random_u256, hash_u256};
use super::inner_product::{InnerProductProof, InnerProductTrait, InnerProductProtocol};

#[derive(Drop, Serde)]
struct RangeProof {
    a: u256,
    s: u256,
    t1: u256,
    t2: u256,
    tau_x: u256,
    mu: u256,
    t: u256,
    ip_proof: InnerProductProof
}

trait RangeProofTrait {
    fn prove(
        v: u256,
        gamma: u256,
        g_vec: Array<u256>,
        h_vec: Array<u256>,
        g: u256,
        h: u256,
        u: u256,
        bits: u32
    ) -> RangeProof;

    fn verify(
        proof: RangeProof,
        commitment: u256,
        g_vec: Array<u256>,
        h_vec: Array<u256>,
        g: u256,
        h: u256,
        u: u256,
        bits: u32
    ) -> bool;
}

impl RangeProofProtocol of RangeProofTrait {
    fn prove(
        v: u256,
        gamma: u256,
        g_vec: Array<u256>,
        h_vec: Array<u256>,
        g: u256,
        h: u256,
        u: u256,
        bits: u32
    ) -> RangeProof {
        // Convert value to binary vector
        let a_l = value_to_bits(v, bits);
        let mut a_r = ArrayTrait::new();
        let mut i = 0;
        while i < bits {
            a_r.append((a_l[i] - 1) * (-1));
            i += 1;
        }

        // Generate random blinding vectors
        let mut alpha = generate_random_u256();
        let mut rho = generate_random_u256();
        let mut s_l = generate_random_vector(bits);
        let mut s_r = generate_random_vector(bits);
        let mut tau1 = generate_random_u256();
        let mut tau2 = generate_random_u256();

        // Compute commitments
        let a = compute_vector_commitment(
            g_vec,
            h_vec,
            a_l,
            a_r,
            alpha
        );

        let s = compute_vector_commitment(
            g_vec,
            h_vec,
            s_l,
            s_r,
            rho
        );

        // Generate challenge
        let y = hash_to_challenge(a, s);
        let z = hash_to_challenge(y, u256::zero());

        // Compute polynomials
        let t1 = compute_t1(
            a_l,
            a_r,
            s_l,
            s_r,
            y,
            z
        );

        let t2 = compute_t2(
            s_l,
            s_r,
            y
        );

        // Compute blinding factors
        let tau_x = compute_tau_x(
            tau1,
            tau2,
            z,
            gamma
        );

        let mu = compute_mu(
            alpha,
            rho,
            y
        );

        // Compute final polynomial
        let t = compute_t(t1, t2);

        // Generate inner product proof
        let ip_proof = InnerProductProtocol::prove(
            a_l,
            s_r,
            g_vec,
            h_vec,
            u
        );

        RangeProof {
            a,
            s,
            t1,
            t2,
            tau_x,
            mu,
            t,
            ip_proof
        }
    }

    fn verify(
        proof: RangeProof,
        commitment: u256,
        g_vec: Array<u256>,
        h_vec: Array<u256>,
        g: u256,
        h: u256,
        u: u256,
        bits: u32
    ) -> bool {
        // Verify commitment consistency
        let y = hash_to_challenge(proof.a, proof.s);
        let z = hash_to_challenge(y, u256::zero());

        // Verify polynomial commitments
        let t_commit = compute_polynomial_commitment(
            g,
            h,
            proof.t,
            proof.tau_x
        );

        let expected_commit = compute_expected_commitment(
            commitment,
            g,
            h,
            proof.t1,
            proof.t2,
            z
        );

        if t_commit != expected_commit {
            return false;
        }

        // Verify inner product proof
        let ip_valid = InnerProductProtocol::verify(
            proof.ip_proof,
            g_vec,
            h_vec,
            u,
            proof.t
        );

        if !ip_valid {
            return false;
        }

        // Verify range
        verify_range_constraints(
            proof.t,
            proof.t1,
            proof.t2,
            z,
            y,
            bits
        )
    }
}

// Helper functions
fn value_to_bits(value: u256, bits: u32) -> Array<u256> {
    let mut result = ArrayTrait::new();
    let mut remaining = value;
    let mut i = 0;
    
    while i < bits {
        result.append(remaining & 1);
        remaining >>= 1;
        i += 1;
    }
    
    result
}

fn generate_random_vector(n: u32) -> Array<u256> {
    let mut result = ArrayTrait::new();
    let mut i = 0;
    
    while i < n {
        result.append(generate_random_u256());
        i += 1;
    }
    
    result
}

fn compute_vector_commitment(
    g_vec: Array<u256>,
    h_vec: Array<u256>,
    a: Array<u256>,
    b: Array<u256>,
    blinding: u256
) -> u256 {
    let mut result = pow_mod(H, blinding, PRIME);
    let mut i = 0;
    
    while i < g_vec.len() {
        result = (result * pow_mod(g_vec[i], a[i], PRIME)) % PRIME;
        result = (result * pow_mod(h_vec[i], b[i], PRIME)) % PRIME;
        i += 1;
    }
    
    result
}

fn compute_t1(
    a_l: Array<u256>,
    a_r: Array<u256>,
    s_l: Array<u256>,
    s_r: Array<u256>,
    y: u256,
    z: u256
) -> u256 {
    let mut result = 0;
    let mut i = 0;
    
    while i < a_l.len() {
        let term1 = (a_l[i] - z) * (a_r[i] + z * y.pow(i));
        let term2 = s_l[i] * y.pow(i) * (a_r[i] + z * y.pow(i));
        result = (result + term1 + term2) % PRIME;
        i += 1;
    }
    
    result
}

fn compute_t2(
    s_l: Array<u256>,
    s_r: Array<u256>,
    y: u256
) -> u256 {
    let mut result = 0;
    let mut i = 0;
    
    while i < s_l.len() {
        result = (result + s_l[i] * s_r[i] * y.pow(2 * i)) % PRIME;
        i += 1;
    }
    
    result
}

fn compute_tau_x(
    tau1: u256,
    tau2: u256,
    z: u256,
    gamma: u256
) -> u256 {
    (tau1 + tau2 * z * z + gamma * z.pow(3)) % PRIME
}

fn compute_mu(
    alpha: u256,
    rho: u256,
    y: u256
) -> u256 {
    (alpha + rho * y) % PRIME
}

fn compute_t(t1: u256, t2: u256) -> u256 {
    (t1 + t2) % PRIME
}

fn compute_polynomial_commitment(
    g: u256,
    h: u256,
    t: u256,
    tau_x: u256
) -> u256 {
    (pow_mod(g, t, PRIME) * pow_mod(h, tau_x, PRIME)) % PRIME
}

fn compute_expected_commitment(
    commitment: u256,
    g: u256,
    h: u256,
    t1: u256,
    t2: u256,
    z: u256
) -> u256 {
    let z2 = z * z % PRIME;
    let z3 = z2 * z % PRIME;
    
    (
        commitment * pow_mod(g, t1, PRIME) * 
        pow_mod(h, t2 * z2, PRIME)
    ) % PRIME
}

fn verify_range_constraints(
    t: u256,
    t1: u256,
    t2: u256,
    z: u256,
    y: u256,
    bits: u32
) -> bool {
    let z2 = z * z % PRIME;
    let z3 = z2 * z % PRIME;
    
    // Verify that t = t1 + t2 * z^2
    let expected_t = (t1 + t2 * z2) % PRIME;
    if t != expected_t {
        return false;
    }
    
    // Verify bit range
    if t >= (u256::one() << bits) {
        return false;
    }
    
    true
}

fn hash_to_challenge(a: u256, b: u256) -> u256 {
    hash_u256(a, b)
}
