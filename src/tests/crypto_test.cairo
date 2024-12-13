use core::traits::Into;
use core::option::OptionTrait;
use core::array::ArrayTrait;

use super::super::crypto::field::{Fp, Fp2, FieldOps};
use super::super::crypto::curve::{G1Point, G2Point, CurveOps};
use super::super::crypto::pairing::{Fp12, PairingOps};

#[test]
fn test_field_operations() {
    // Test Fp operations
    let a = Fp { value: 5 };
    let b = Fp { value: 3 };

    let sum = a.add(b);
    assert(sum.value == 8, 'Invalid Fp addition');

    let product = a.mul(b);
    assert(product.value == 15, 'Invalid Fp multiplication');

    let inv = a.inv();
    let product = a.mul(inv);
    assert(product.value == 1, 'Invalid Fp inversion');

    // Test Fp2 operations
    let a = Fp2 {
        c0: Fp { value: 2 },
        c1: Fp { value: 3 }
    };
    let b = Fp2 {
        c0: Fp { value: 1 },
        c1: Fp { value: 1 }
    };

    let sum = a.add(b);
    assert(sum.c0.value == 3, 'Invalid Fp2 addition c0');
    assert(sum.c1.value == 4, 'Invalid Fp2 addition c1');

    let product = a.mul(b);
    assert(product.c0.value == -1, 'Invalid Fp2 multiplication c0');
    assert(product.c1.value == 5, 'Invalid Fp2 multiplication c1');
}

#[test]
fn test_curve_operations() {
    // Test G1 operations
    let P = G1Point {
        x: Fp { value: 1 },
        y: Fp { value: 2 },
        z: Fp { value: 1 }
    };

    let Q = G1Point {
        x: Fp { value: 3 },
        y: Fp { value: 4 },
        z: Fp { value: 1 }
    };

    let sum = P.add(Q);
    assert(sum.is_on_curve(), 'Invalid G1 addition');

    let double = P.double();
    assert(double.is_on_curve(), 'Invalid G1 doubling');

    // Test G2 operations
    let P2 = G2Point {
        x: Fp2 {
            c0: Fp { value: 1 },
            c1: Fp { value: 0 }
        },
        y: Fp2 {
            c0: Fp { value: 2 },
            c1: Fp { value: 0 }
        },
        z: Fp2 {
            c0: Fp { value: 1 },
            c1: Fp { value: 0 }
        }
    };

    let Q2 = G2Point {
        x: Fp2 {
            c0: Fp { value: 3 },
            c1: Fp { value: 0 }
        },
        y: Fp2 {
            c0: Fp { value: 4 },
            c1: Fp { value: 0 }
        },
        z: Fp2 {
            c0: Fp { value: 1 },
            c1: Fp { value: 0 }
        }
    };

    let sum = P2.add(Q2);
    assert(sum.is_on_curve(), 'Invalid G2 addition');

    let double = P2.double();
    assert(double.is_on_curve(), 'Invalid G2 doubling');
}

#[test]
fn test_pairing_operations() {
    // Create test points
    let P = G1Point {
        x: Fp { value: 1 },
        y: Fp { value: 2 },
        z: Fp { value: 1 }
    };

    let Q = G2Point {
        x: Fp2 {
            c0: Fp { value: 1 },
            c1: Fp { value: 0 }
        },
        y: Fp2 {
            c0: Fp { value: 2 },
            c1: Fp { value: 0 }
        },
        z: Fp2 {
            c0: Fp { value: 1 },
            c1: Fp { value: 0 }
        }
    };

    // Test ate pairing
    let e = PairingOps::ate_pairing(P, Q);
    
    // Test bilinearity property: e(aP, Q) = e(P, Q)^a
    let a = 3;
    let aP = P.mul(a);
    let e1 = PairingOps::ate_pairing(aP, Q);
    let e2 = e.pow(a);
    
    assert(e1.c0.c0.value == e2.c0.c0.value, 'Invalid pairing bilinearity');
    assert(e1.c1.c0.value == e2.c1.c0.value, 'Invalid pairing bilinearity');

    // Test final exponentiation
    let f = PairingOps::final_exponentiation(e);
    assert(f.c0.c0.value != 0 || f.c1.c0.value != 0, 'Invalid final exponentiation');
}
