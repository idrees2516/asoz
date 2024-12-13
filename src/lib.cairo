mod crypto {
    mod field;
    mod curve;
    mod pairing;
}

mod bulletproofs;
mod zksnark;
mod auditor;
mod key_management;
mod protocol;

#[cfg(test)]
mod tests {
    mod protocol_test;
    mod crypto_test;
}

use bulletproofs::BulletproofSystem;
use zksnark::SnarkSystem;
use auditor::AuditorFramework;
use key_management::KeyManagement;
use protocol::ASOZProtocol;

// Re-export core types and traits
pub use crypto::field::{Fp, Fp2, FieldOps};
pub use crypto::curve::{G1Point, G2Point, CurveOps};
pub use crypto::pairing::{Fp12, PairingOps};
