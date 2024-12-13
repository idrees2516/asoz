use core::traits::Into;
use core::option::OptionTrait;
use super::field::{Fp, Fp2, FieldOps};
use super::curve::{G1Point, G2Point, CurveOps};

// BN254 pairing implementation
#[derive(Copy, Drop, Serde)]
struct Fp12 {
    c0: Fp2,
    c1: Fp2,
    c2: Fp2,
    c3: Fp2,
    c4: Fp2,
    c5: Fp2
}

trait PairingOps {
    fn ate_pairing(P: G1Point, Q: G2Point) -> Fp12;
    fn final_exponentiation(f: Fp12) -> Fp12;
}

impl Fp12Impl of FieldOps<Fp12> {
    fn add(self: Fp12, other: Fp12) -> Fp12 {
        Fp12 {
            c0: self.c0.add(other.c0),
            c1: self.c1.add(other.c1),
            c2: self.c2.add(other.c2),
            c3: self.c3.add(other.c3),
            c4: self.c4.add(other.c4),
            c5: self.c5.add(other.c5)
        }
    }

    fn sub(self: Fp12, other: Fp12) -> Fp12 {
        Fp12 {
            c0: self.c0.sub(other.c0),
            c1: self.c1.sub(other.c1),
            c2: self.c2.sub(other.c2),
            c3: self.c3.sub(other.c3),
            c4: self.c4.sub(other.c4),
            c5: self.c5.sub(other.c5)
        }
    }

    fn mul(self: Fp12, other: Fp12) -> Fp12 {
        // Karatsuba multiplication for Fp12
        let a0 = self.c0.mul(other.c0);
        let a1 = self.c1.mul(other.c1);
        let a2 = self.c2.mul(other.c2);
        let a3 = self.c3.mul(other.c3);
        let a4 = self.c4.mul(other.c4);
        let a5 = self.c5.mul(other.c5);

        let t0 = self.c0.add(self.c1);
        let t1 = other.c0.add(other.c1);
        let b0 = t0.mul(t1).sub(a0).sub(a1);

        let t0 = self.c1.add(self.c2);
        let t1 = other.c1.add(other.c2);
        let b1 = t0.mul(t1).sub(a1).sub(a2);

        let t0 = self.c2.add(self.c3);
        let t1 = other.c2.add(other.c3);
        let b2 = t0.mul(t1).sub(a2).sub(a3);

        let t0 = self.c3.add(self.c4);
        let t1 = other.c3.add(other.c4);
        let b3 = t0.mul(t1).sub(a3).sub(a4);

        let t0 = self.c4.add(self.c5);
        let t1 = other.c4.add(other.c5);
        let b4 = t0.mul(t1).sub(a4).sub(a5);

        let t0 = self.c5.add(self.c0);
        let t1 = other.c5.add(other.c0);
        let b5 = t0.mul(t1).sub(a5).sub(a0);

        Fp12 {
            c0: a0.add(b5),
            c1: b0,
            c2: b1,
            c3: b2,
            c4: b3,
            c5: b4
        }
    }

    fn div(self: Fp12, other: Fp12) -> Fp12 {
        let inv = other.inv();
        self.mul(inv)
    }

    fn inv(self: Fp12) -> Fp12 {
        // Inversion using the tower field structure
        let t0 = self.c0.mul(self.c0);
        let t1 = self.c1.mul(self.c1);
        let t2 = self.c2.mul(self.c2);
        let t3 = self.c3.mul(self.c3);
        let t4 = self.c4.mul(self.c4);
        let t5 = self.c5.mul(self.c5);

        let u0 = t0.add(t2).add(t4);
        let u1 = t1.add(t3).add(t5);

        let t = u0.mul(u0).add(u1.mul(u1));
        let t_inv = t.inv();

        let v0 = u0.mul(t_inv);
        let v1 = u1.mul(t_inv).mul(Fp2 {
            c0: Fp { value: BN254_MODULUS - 1 },
            c1: Fp { value: 0 }
        });

        Fp12 {
            c0: self.c0.mul(v0).sub(self.c1.mul(v1)),
            c1: self.c1.mul(v0).add(self.c0.mul(v1)),
            c2: self.c2.mul(v0).sub(self.c3.mul(v1)),
            c3: self.c3.mul(v0).add(self.c2.mul(v1)),
            c4: self.c4.mul(v0).sub(self.c5.mul(v1)),
            c5: self.c5.mul(v0).add(self.c4.mul(v1))
        }
    }

    fn pow(self: Fp12, exp: felt252) -> Fp12 {
        if exp == 0 {
            return Fp12 {
                c0: Fp2 {
                    c0: Fp { value: 1 },
                    c1: Fp { value: 0 }
                },
                c1: Fp2 {
                    c0: Fp { value: 0 },
                    c1: Fp { value: 0 }
                },
                c2: Fp2 {
                    c0: Fp { value: 0 },
                    c1: Fp { value: 0 }
                },
                c3: Fp2 {
                    c0: Fp { value: 0 },
                    c1: Fp { value: 0 }
                },
                c4: Fp2 {
                    c0: Fp { value: 0 },
                    c1: Fp { value: 0 }
                },
                c5: Fp2 {
                    c0: Fp { value: 0 },
                    c1: Fp { value: 0 }
                }
            };
        }

        let mut result = self;
        let mut base = self;
        let mut e = exp;

        while e > 1 {
            if e & 1 == 1 {
                result = result.mul(base);
            }
            base = base.mul(base);
            e >>= 1;
        }

        result
    }

    fn sqrt(self: Fp12) -> Option<Fp12> {
        // Not implemented for Fp12 as it's not needed for pairing
        Option::None
    }

    fn legendre(self: Fp12) -> felt252 {
        // Not implemented for Fp12 as it's not needed for pairing
        0
    }
}

impl PairingImpl of PairingOps {
    fn ate_pairing(P: G1Point, Q: G2Point) -> Fp12 {
        // Convert points to affine coordinates
        let P_affine = P.to_affine();
        let Q_affine = Q.to_affine();

        // Miller loop
        let mut f = Fp12 {
            c0: Fp2 {
                c0: Fp { value: 1 },
                c1: Fp { value: 0 }
            },
            c1: Fp2 {
                c0: Fp { value: 0 },
                c1: Fp { value: 0 }
            },
            c2: Fp2 {
                c0: Fp { value: 0 },
                c1: Fp { value: 0 }
            },
            c3: Fp2 {
                c0: Fp { value: 0 },
                c1: Fp { value: 0 }
            },
            c4: Fp2 {
                c0: Fp { value: 0 },
                c1: Fp { value: 0 }
            },
            c5: Fp2 {
                c0: Fp { value: 0 },
                c1: Fp { value: 0 }
            }
        };

        let mut T = Q_affine;
        let mut miller_loop_bits = 0x44E992_u64; // BN254 parameter

        while miller_loop_bits > 0 {
            f = f.mul(f);
            f = f.mul(line_function(T, T, P_affine));

            T = T.double();

            if miller_loop_bits & 1 == 1 {
                f = f.mul(line_function(T, Q_affine, P_affine));
                T = T.add(Q_affine);
            }

            miller_loop_bits >>= 1;
        }

        f
    }

    fn final_exponentiation(f: Fp12) -> Fp12 {
        // Hard part of the final exponentiation
        let mut t0 = f.pow((BN254_MODULUS - 1) / 3);
        let mut t1 = f.pow((BN254_MODULUS - 1) / 2);
        
        // Compute the final result
        t0.mul(t1)
    }
}

// Helper function for the Miller loop
fn line_function(R: G2Point, Q: G2Point, P: G1Point) -> Fp12 {
    // Compute the line function evaluation
    let slope = compute_slope(R, Q);
    let v = compute_vertical(R);
    
    evaluate_line(slope, v, P)
}

fn compute_slope(R: G2Point, Q: G2Point) -> Fp2 {
    if R.x.c0.value == Q.x.c0.value && R.x.c1.value == Q.x.c1.value {
        // Point doubling case
        let xx = R.x.mul(R.x);
        let yy = R.y.mul(R.y);
        
        let s = xx.mul(Fp2 {
            c0: Fp { value: 3 },
            c1: Fp { value: 0 }
        }).div(yy.mul(Fp2 {
            c0: Fp { value: 2 },
            c1: Fp { value: 0 }
        }));
        
        s
    } else {
        // Point addition case
        let s = Q.y.sub(R.y).div(Q.x.sub(R.x));
        s
    }
}

fn compute_vertical(R: G2Point) -> Fp2 {
    R.x
}

fn evaluate_line(slope: Fp2, v: Fp2, P: G1Point) -> Fp12 {
    // Line evaluation at point P
    let t0 = slope.mul(Fp2 {
        c0: P.x,
        c1: Fp { value: 0 }
    });
    let t1 = v.mul(Fp2 {
        c0: P.y,
        c1: Fp { value: 0 }
    });
    
    Fp12 {
        c0: t0,
        c1: t1,
        c2: Fp2 {
            c0: Fp { value: 0 },
            c1: Fp { value: 0 }
        },
        c3: Fp2 {
            c0: Fp { value: 0 },
            c1: Fp { value: 0 }
        },
        c4: Fp2 {
            c0: Fp { value: 0 },
            c1: Fp { value: 0 }
        },
        c5: Fp2 {
            c0: Fp { value: 0 },
            c1: Fp { value: 0 }
        }
    }
}
