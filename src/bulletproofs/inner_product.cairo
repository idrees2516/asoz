use core::traits::Into;
use core::option::OptionTrait;
use core::array::ArrayTrait;
use super::super::constants::{PRIME, G, H};
use super::super::crypto::utils::{pow_mod, generate_random_u256, hash_u256};

// Advanced Inner Product Argument implementation
#[derive(Drop, Serde)]
struct InnerProductProof {
    l_vec: Array<u256>,
    r_vec: Array<u256>,
    a_final: u256,
    b_final: u256
}

trait InnerProductTrait {
    fn prove(
        a: Array<u256>,
        b: Array<u256>,
        g_vec: Array<u256>,
        h_vec: Array<u256>,
        u: u256
    ) -> InnerProductProof;
    
    fn verify(
        proof: InnerProductProof,
        g_vec: Array<u256>,
        h_vec: Array<u256>,
        u: u256,
        p: u256
    ) -> bool;
}

impl InnerProductProtocol of InnerProductTrait {
    fn prove(
        a: Array<u256>,
        b: Array<u256>,
        g_vec: Array<u256>,
        h_vec: Array<u256>,
        u: u256
    ) -> InnerProductProof {
        assert(a.len() == b.len(), 'Vector lengths must match');
        assert(a.len() == g_vec.len(), 'Generator length mismatch');
        assert(g_vec.len() == h_vec.len(), 'Generator length mismatch');
        assert(is_power_of_two(a.len()), 'Length must be power of 2');

        let mut n = a.len();
        let mut g = g_vec;
        let mut h = h_vec;
        let mut a_vec = a;
        let mut b_vec = b;
        let mut l_vec = ArrayTrait::new();
        let mut r_vec = ArrayTrait::new();

        while n > 1 {
            let n_half = n / 2;
            
            // Split vectors
            let (a_l, a_r) = split_vector(a_vec, n_half);
            let (b_l, b_r) = split_vector(b_vec, n_half);
            let (g_l, g_r) = split_vector(g, n_half);
            let (h_l, h_r) = split_vector(h, n_half);

            // Compute L and R terms
            let c_l = inner_product(a_l, b_r);
            let c_r = inner_product(a_r, b_l);

            let l = compute_commitment(
                g_r,
                h_l,
                a_l,
                b_r,
                u,
                c_l
            );

            let r = compute_commitment(
                g_l,
                h_r,
                a_r,
                b_l,
                u,
                c_r
            );

            // Store L and R
            l_vec.append(l);
            r_vec.append(r);

            // Generate challenge
            let x = hash_to_field(l, r);
            let x_inv = mod_inverse(x, PRIME).unwrap();

            // Update vectors for next round
            a_vec = combine_vectors(a_l, a_r, x, x_inv);
            b_vec = combine_vectors(b_l, b_r, x_inv, x);
            g = combine_generators(g_l, g_r, x_inv, x);
            h = combine_generators(h_l, h_r, x, x_inv);

            n = n_half;
        }

        InnerProductProof {
            l_vec,
            r_vec,
            a_final: a_vec[0],
            b_final: b_vec[0]
        }
    }

    fn verify(
        proof: InnerProductProof,
        g_vec: Array<u256>,
        h_vec: Array<u256>,
        u: u256,
        p: u256
    ) -> bool {
        let n = g_vec.len();
        assert(is_power_of_two(n), 'Length must be power of 2');
        
        let mut g = g_vec;
        let mut h = h_vec;
        let mut p_prime = p;

        // Verify each round
        let mut i = 0;
        while i < proof.l_vec.len() {
            let l = proof.l_vec[i];
            let r = proof.r_vec[i];
            
            // Generate challenge
            let x = hash_to_field(l, r);
            let x_inv = mod_inverse(x, PRIME).unwrap();
            
            // Update commitment
            p_prime = update_commitment(
                p_prime,
                l,
                r,
                x,
                x_inv
            );

            // Update generators
            let n_half = g.len() / 2;
            let (g_l, g_r) = split_vector(g, n_half);
            let (h_l, h_r) = split_vector(h, n_half);
            
            g = combine_generators(g_l, g_r, x_inv, x);
            h = combine_generators(h_l, h_r, x, x_inv);

            i += 1;
        }

        // Final verification
        let g_final = g[0];
        let h_final = h[0];
        let expected = compute_final_commitment(
            g_final,
            h_final,
            proof.a_final,
            proof.b_final,
            u,
            inner_product(
                array![proof.a_final],
                array![proof.b_final]
            )
        );

        expected == p_prime
    }
}

// Helper functions
fn is_power_of_two(n: usize) -> bool {
    n != 0 && (n & (n - 1)) == 0
}

fn split_vector(vec: Array<u256>, mid: usize) -> (Array<u256>, Array<u256>) {
    let mut left = ArrayTrait::new();
    let mut right = ArrayTrait::new();
    
    let mut i = 0;
    while i < mid {
        left.append(vec[i]);
        i += 1;
    }
    
    while i < vec.len() {
        right.append(vec[i]);
        i += 1;
    }
    
    (left, right)
}

fn inner_product(a: Array<u256>, b: Array<u256>) -> u256 {
    let mut result = 0;
    let mut i = 0;
    
    while i < a.len() {
        result = (result + (a[i] * b[i]) % PRIME) % PRIME;
        i += 1;
    }
    
    result
}

fn compute_commitment(
    g: Array<u256>,
    h: Array<u256>,
    a: Array<u256>,
    b: Array<u256>,
    u: u256,
    c: u256
) -> u256 {
    let mut result = pow_mod(u, c, PRIME);
    let mut i = 0;
    
    while i < g.len() {
        result = (result * pow_mod(g[i], a[i], PRIME)) % PRIME;
        result = (result * pow_mod(h[i], b[i], PRIME)) % PRIME;
        i += 1;
    }
    
    result
}

fn combine_vectors(
    left: Array<u256>,
    right: Array<u256>,
    x: u256,
    x_inv: u256
) -> Array<u256> {
    let mut result = ArrayTrait::new();
    let mut i = 0;
    
    while i < left.len() {
        let combined = (
            (left[i] * x) % PRIME +
            (right[i] * x_inv) % PRIME
        ) % PRIME;
        result.append(combined);
        i += 1;
    }
    
    result
}

fn combine_generators(
    left: Array<u256>,
    right: Array<u256>,
    x: u256,
    x_inv: u256
) -> Array<u256> {
    let mut result = ArrayTrait::new();
    let mut i = 0;
    
    while i < left.len() {
        let combined = (
            pow_mod(left[i], x, PRIME) *
            pow_mod(right[i], x_inv, PRIME)
        ) % PRIME;
        result.append(combined);
        i += 1;
    }
    
    result
}

fn update_commitment(
    p: u256,
    l: u256,
    r: u256,
    x: u256,
    x_inv: u256
) -> u256 {
    (
        (pow_mod(l, x_inv * x_inv, PRIME) *
        pow_mod(p, x * x_inv, PRIME) *
        pow_mod(r, x * x, PRIME))
    ) % PRIME
}

fn compute_final_commitment(
    g: u256,
    h: u256,
    a: u256,
    b: u256,
    u: u256,
    c: u256
) -> u256 {
    (
        (pow_mod(g, a, PRIME) *
        pow_mod(h, b, PRIME) *
        pow_mod(u, c, PRIME))
    ) % PRIME
}

fn hash_to_field(a: u256, b: u256) -> u256 {
    hash_u256(a, b)
}

fn mod_inverse(a: u256, m: u256) -> Option<u256> {
    if m == 0 {
        return Option::None;
    }

    let mut a = a as i256;
    let mut m = m as i256;
    let mut x = 1;
    let mut y = 0;
    let mut x1 = 0;
    let mut y1 = 1;
    let mut q = 0;
    let mut tmp = 0;

    while a > 1 {
        q = a / m;
        tmp = a;
        a = m;
        m = tmp % m;
        tmp = x;
        x = x1;
        x1 = tmp - q * x1;
        tmp = y;
        y = y1;
        y1 = tmp - q * y1;
    }

    if x < 0 {
        x += m;
    }

    Option::Some(x as u256)
}
