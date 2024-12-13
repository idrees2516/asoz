use core::traits::Into;
use core::option::OptionTrait;
use core::array::ArrayTrait;
use super::super::constants::{PRIME, G, H};
use super::utils::{pow_mod, generate_random_u256, hash_u256};

#[derive(Drop, Serde)]
struct StealthAddress {
    public_spend_key: u256,
    public_view_key: u256
}

#[derive(Drop, Serde)]
struct StealthKeys {
    spend_key: u256,
    view_key: u256
}

#[derive(Drop, Serde)]
struct OneTimeAddress {
    address: u256,
    tx_public_key: u256
}

trait StealthAddressTrait {
    fn generate_stealth_keys() -> StealthKeys;
    
    fn create_stealth_address(keys: StealthKeys) -> StealthAddress;
    
    fn generate_one_time_address(
        stealth_address: StealthAddress,
        sender_private_key: u256
    ) -> OneTimeAddress;
    
    fn recover_one_time_private_key(
        one_time_address: OneTimeAddress,
        stealth_keys: StealthKeys
    ) -> Option<u256>;
    
    fn verify_ownership(
        one_time_address: OneTimeAddress,
        stealth_address: StealthAddress
    ) -> bool;
}

impl StealthAddressProtocol of StealthAddressTrait {
    fn generate_stealth_keys() -> StealthKeys {
        let spend_key = generate_random_u256();
        let view_key = generate_random_u256();
        
        StealthKeys {
            spend_key,
            view_key
        }
    }
    
    fn create_stealth_address(keys: StealthKeys) -> StealthAddress {
        let public_spend_key = pow_mod(G, keys.spend_key, PRIME);
        let public_view_key = pow_mod(G, keys.view_key, PRIME);
        
        StealthAddress {
            public_spend_key,
            public_view_key
        }
    }
    
    fn generate_one_time_address(
        stealth_address: StealthAddress,
        sender_private_key: u256
    ) -> OneTimeAddress {
        // Generate transaction public key
        let tx_public_key = pow_mod(G, sender_private_key, PRIME);
        
        // Generate shared secret
        let shared_secret = pow_mod(
            stealth_address.public_view_key,
            sender_private_key,
            PRIME
        );
        
        // Generate one-time address
        let hs = hash_to_scalar(shared_secret, tx_public_key);
        let address = compute_one_time_address(
            stealth_address.public_spend_key,
            hs
        );
        
        OneTimeAddress {
            address,
            tx_public_key
        }
    }
    
    fn recover_one_time_private_key(
        one_time_address: OneTimeAddress,
        stealth_keys: StealthKeys
    ) -> Option<u256> {
        // Recover shared secret
        let shared_secret = pow_mod(
            one_time_address.tx_public_key,
            stealth_keys.view_key,
            PRIME
        );
        
        // Derive one-time private key
        let hs = hash_to_scalar(shared_secret, one_time_address.tx_public_key);
        let private_key = derive_one_time_private_key(
            stealth_keys.spend_key,
            hs
        );
        
        // Verify derived key
        let public_key = pow_mod(G, private_key, PRIME);
        if public_key == one_time_address.address {
            Option::Some(private_key)
        } else {
            Option::None
        }
    }
    
    fn verify_ownership(
        one_time_address: OneTimeAddress,
        stealth_address: StealthAddress
    ) -> bool {
        // Verify address format
        if !verify_address_format(one_time_address.address) {
            return false;
        }
        
        // Verify public key format
        if !verify_public_key_format(one_time_address.tx_public_key) {
            return false;
        }
        
        // Verify stealth address components
        verify_stealth_address_components(stealth_address)
    }
}

// Helper functions
fn compute_one_time_address(
    public_spend_key: u256,
    hs: u256
) -> u256 {
    (pow_mod(G, hs, PRIME) * public_spend_key) % PRIME
}

fn derive_one_time_private_key(
    spend_key: u256,
    hs: u256
) -> u256 {
    (hs + spend_key) % (PRIME - 1)
}

fn verify_address_format(address: u256) -> bool {
    // Verify address is in prime field
    address < PRIME
}

fn verify_public_key_format(public_key: u256) -> bool {
    // Verify public key is valid curve point
    public_key < PRIME && is_on_curve(public_key)
}

fn verify_stealth_address_components(
    stealth_address: StealthAddress
) -> bool {
    // Verify both keys are valid curve points
    verify_public_key_format(stealth_address.public_spend_key) &&
    verify_public_key_format(stealth_address.public_view_key)
}

fn is_on_curve(point: u256) -> bool {
    // Implement curve equation check
    // y^2 = x^3 + 7 (secp256k1)
    let y2 = (point * point * point + 7) % PRIME;
    has_square_root(y2, PRIME)
}

fn has_square_root(n: u256, p: u256) -> bool {
    if n == 0 {
        return true;
    }
    
    let power = (p - 1) / 2;
    pow_mod(n, power, p) == 1
}

fn hash_to_scalar(a: u256, b: u256) -> u256 {
    hash_u256(a, b) % (PRIME - 1)
}
