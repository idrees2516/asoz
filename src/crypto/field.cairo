use core::traits::Into;
use core::option::OptionTrait;
use alexandria_math::powers;

// Advanced field arithmetic implementation for BN254 curve
const BN254_MODULUS: felt252 = 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47;

#[derive(Copy, Drop, Serde)]
struct Fp {
    value: felt252
}

trait FieldOps<T> {
    fn add(self: T, other: T) -> T;
    fn sub(self: T, other: T) -> T;
    fn mul(self: T, other: T) -> T;
    fn div(self: T, other: T) -> T;
    fn inv(self: T) -> T;
    fn pow(self: T, exp: felt252) -> T;
    fn sqrt(self: T) -> Option<T>;
    fn legendre(self: T) -> felt252;
}

impl FpImpl of FieldOps<Fp> {
    fn add(self: Fp, other: Fp) -> Fp {
        let sum = (self.value + other.value) % BN254_MODULUS;
        Fp { value: sum }
    }

    fn sub(self: Fp, other: Fp) -> Fp {
        let mut diff = self.value - other.value;
        if diff < 0 {
            diff += BN254_MODULUS;
        }
        Fp { value: diff }
    }

    fn mul(self: Fp, other: Fp) -> Fp {
        let prod = (self.value * other.value) % BN254_MODULUS;
        Fp { value: prod }
    }

    fn div(self: Fp, other: Fp) -> Fp {
        let inv = other.inv();
        self.mul(inv)
    }

    fn inv(self: Fp) -> Fp {
        // Extended Euclidean Algorithm for modular inverse
        let mut t = 0;
        let mut newt = 1;
        let mut r = BN254_MODULUS;
        let mut newr = self.value;

        while newr != 0 {
            let quotient = r / newr;
            (t, newt) = (newt, t - quotient * newt);
            (r, newr) = (newr, r - quotient * newr);
        }

        if t < 0 {
            t += BN254_MODULUS;
        }

        Fp { value: t }
    }

    fn pow(self: Fp, exp: felt252) -> Fp {
        if exp == 0 {
            return Fp { value: 1 };
        }

        let mut base = self;
        let mut result = Fp { value: 1 };
        let mut e = exp;

        while e > 0 {
            if e & 1 == 1 {
                result = result.mul(base);
            }
            base = base.mul(base);
            e >>= 1;
        }

        result
    }

    fn sqrt(self: Fp) -> Option<Fp> {
        // Tonelli-Shanks algorithm for square root in finite field
        if self.legendre() != 1 {
            return Option::None;
        }

        let mut q = BN254_MODULUS - 1;
        let mut s = 0;
        while q & 1 == 0 {
            s += 1;
            q >>= 1;
        }

        if s == 1 {
            let r = self.pow((BN254_MODULUS + 1) / 4);
            return Option::Some(r);
        }

        let mut z = Fp { value: 2 };
        while z.legendre() != -1 {
            z.value += 1;
        }

        let mut c = z.pow(q);
        let mut r = self.pow((q + 1) / 2);
        let mut t = self.pow(q);
        let mut m = s;

        while t.value != 1 {
            let mut i = 0;
            let mut tt = t;
            while tt.value != 1 {
                tt = tt.mul(tt);
                i += 1;
                if i == m {
                    return Option::None;
                }
            }

            let b = c.pow(1 << (m - i - 1));
            r = r.mul(b);
            c = b.mul(b);
            t = t.mul(c);
            m = i;
        }

        Option::Some(r)
    }

    fn legendre(self: Fp) -> felt252 {
        let pow = (BN254_MODULUS - 1) / 2;
        let result = self.pow(pow).value;
        if result == 0 {
            0
        } else if result == 1 {
            1
        } else {
            -1
        }
    }
}

// Extension field Fp2 implementation
#[derive(Copy, Drop, Serde)]
struct Fp2 {
    c0: Fp,
    c1: Fp
}

impl Fp2Impl of FieldOps<Fp2> {
    fn add(self: Fp2, other: Fp2) -> Fp2 {
        Fp2 {
            c0: self.c0.add(other.c0),
            c1: self.c1.add(other.c1)
        }
    }

    fn sub(self: Fp2, other: Fp2) -> Fp2 {
        Fp2 {
            c0: self.c0.sub(other.c0),
            c1: self.c1.sub(other.c1)
        }
    }

    fn mul(self: Fp2, other: Fp2) -> Fp2 {
        let a = self.c0.mul(other.c0);
        let b = self.c1.mul(other.c1);
        let c = self.c0.add(self.c1).mul(other.c0.add(other.c1));
        
        Fp2 {
            c0: a.sub(b),
            c1: c.sub(a).sub(b)
        }
    }

    fn div(self: Fp2, other: Fp2) -> Fp2 {
        let inv = other.inv();
        self.mul(inv)
    }

    fn inv(self: Fp2) -> Fp2 {
        let t0 = self.c0.mul(self.c0);
        let t1 = self.c1.mul(self.c1);
        let t2 = t0.add(t1);
        let t3 = t2.inv();
        
        Fp2 {
            c0: self.c0.mul(t3),
            c1: self.c1.mul(t3).mul(Fp { value: BN254_MODULUS - 1 })
        }
    }

    fn pow(self: Fp2, exp: felt252) -> Fp2 {
        if exp == 0 {
            return Fp2 {
                c0: Fp { value: 1 },
                c1: Fp { value: 0 }
            };
        }

        let mut base = self;
        let mut result = Fp2 {
            c0: Fp { value: 1 },
            c1: Fp { value: 0 }
        };
        let mut e = exp;

        while e > 0 {
            if e & 1 == 1 {
                result = result.mul(base);
            }
            base = base.mul(base);
            e >>= 1;
        }

        result
    }

    fn sqrt(self: Fp2) -> Option<Fp2> {
        // Complex square root algorithm
        let a = self.c0;
        let b = self.c1;
        
        if b.value == 0 {
            let sqrt_a = a.sqrt();
            match sqrt_a {
                Option::Some(r) => {
                    return Option::Some(Fp2 { c0: r, c1: Fp { value: 0 } });
                },
                Option::None => {
                    let neg_a = Fp { value: BN254_MODULUS - a.value };
                    let sqrt_neg_a = neg_a.sqrt();
                    match sqrt_neg_a {
                        Option::Some(r) => {
                            return Option::Some(Fp2 { c0: Fp { value: 0 }, c1: r });
                        },
                        Option::None => {
                            return Option::None;
                        }
                    }
                }
            }
        }

        let alpha = a.mul(a).add(b.mul(b));
        let sqrt_alpha = alpha.sqrt();
        
        match sqrt_alpha {
            Option::Some(r) => {
                let delta = r.add(a).div(Fp { value: 2 });
                let sqrt_delta = delta.sqrt();
                
                match sqrt_delta {
                    Option::Some(x) => {
                        let y = b.div(x.mul(Fp { value: 2 }));
                        Option::Some(Fp2 { c0: x, c1: y })
                    },
                    Option::None => Option::None
                }
            },
            Option::None => Option::None
        }
    }

    fn legendre(self: Fp2) -> felt252 {
        // Simplified Legendre symbol for Fp2
        let norm = self.c0.mul(self.c0).add(self.c1.mul(self.c1));
        norm.legendre()
    }
}
