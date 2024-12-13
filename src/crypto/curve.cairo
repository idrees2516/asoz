use core::traits::Into;
use core::option::OptionTrait;
use super::field::{Fp, Fp2, FieldOps};

// BN254 curve implementation
const CURVE_B: felt252 = 3;

#[derive(Copy, Drop, Serde)]
struct G1Point {
    x: Fp,
    y: Fp,
    z: Fp
}

#[derive(Copy, Drop, Serde)]
struct G2Point {
    x: Fp2,
    y: Fp2,
    z: Fp2
}

trait CurveOps<T> {
    fn double(self: T) -> T;
    fn add(self: T, other: T) -> T;
    fn mul(self: T, scalar: felt252) -> T;
    fn is_on_curve(self: T) -> bool;
    fn to_affine(self: T) -> T;
}

impl G1PointImpl of CurveOps<G1Point> {
    fn double(self: G1Point) -> G1Point {
        if self.z.value == 0 {
            return self;
        }

        // Doubling formulas for BN254 G1
        let xx = self.x.mul(self.x);
        let yy = self.y.mul(self.y);
        let zz = self.z.mul(self.z);
        let yyyy = yy.mul(yy);
        
        let s = self.x.add(yy).mul(self.x.add(yy))
            .sub(xx).sub(yyyy).mul(Fp { value: 2 });
        
        let m = xx.mul(Fp { value: 3 });
        let t = m.mul(m).sub(s.mul(Fp { value: 2 }));
        
        let new_x = t;
        let new_y = m.mul(s.sub(t)).sub(yyyy.mul(Fp { value: 8 }));
        let new_z = self.y.mul(self.z).mul(Fp { value: 2 });

        G1Point { x: new_x, y: new_y, z: new_z }
    }

    fn add(self: G1Point, other: G1Point) -> G1Point {
        if self.z.value == 0 {
            return other;
        }
        if other.z.value == 0 {
            return self;
        }

        // Addition formulas for BN254 G1
        let z1z1 = self.z.mul(self.z);
        let z2z2 = other.z.mul(other.z);
        let u1 = self.x.mul(z2z2);
        let u2 = other.x.mul(z1z1);
        let s1 = self.y.mul(other.z).mul(z2z2);
        let s2 = other.y.mul(self.z).mul(z1z1);
        
        if u1.value == u2.value {
            if s1.value == s2.value {
                return self.double();
            }
            return G1Point {
                x: Fp { value: 0 },
                y: Fp { value: 1 },
                z: Fp { value: 0 }
            };
        }

        let h = u2.sub(u1);
        let i = h.mul(Fp { value: 2 }).mul(h);
        let j = h.mul(i);
        let r = s2.sub(s1).mul(Fp { value: 2 });
        let v = u1.mul(i);
        
        let new_x = r.mul(r).sub(j).sub(v.mul(Fp { value: 2 }));
        let new_y = r.mul(v.sub(new_x)).sub(s1.mul(j).mul(Fp { value: 2 }));
        let new_z = h.mul(self.z).mul(other.z).mul(Fp { value: 2 });

        G1Point { x: new_x, y: new_y, z: new_z }
    }

    fn mul(self: G1Point, scalar: felt252) -> G1Point {
        let mut result = G1Point {
            x: Fp { value: 0 },
            y: Fp { value: 1 },
            z: Fp { value: 0 }
        };
        let mut temp = self;
        let mut s = scalar;

        while s > 0 {
            if s & 1 == 1 {
                result = result.add(temp);
            }
            temp = temp.double();
            s >>= 1;
        }

        result
    }

    fn is_on_curve(self: G1Point) -> bool {
        let affine = self.to_affine();
        if affine.z.value == 0 {
            return true;
        }

        let y2 = affine.y.mul(affine.y);
        let x3 = affine.x.mul(affine.x).mul(affine.x);
        let b = Fp { value: CURVE_B };
        
        y2.value == (x3.add(b)).value
    }

    fn to_affine(self: G1Point) -> G1Point {
        if self.z.value == 0 {
            return self;
        }

        let z_inv = self.z.inv();
        let z_inv_squared = z_inv.mul(z_inv);
        let z_inv_cubed = z_inv_squared.mul(z_inv);
        
        G1Point {
            x: self.x.mul(z_inv_squared),
            y: self.y.mul(z_inv_cubed),
            z: Fp { value: 1 }
        }
    }
}

impl G2PointImpl of CurveOps<G2Point> {
    fn double(self: G2Point) -> G2Point {
        if self.z.c0.value == 0 && self.z.c1.value == 0 {
            return self;
        }

        // Doubling formulas for BN254 G2
        let xx = self.x.mul(self.x);
        let yy = self.y.mul(self.y);
        let zz = self.z.mul(self.z);
        let yyyy = yy.mul(yy);
        
        let s = self.x.add(yy).mul(self.x.add(yy))
            .sub(xx).sub(yyyy).mul(Fp2 {
                c0: Fp { value: 2 },
                c1: Fp { value: 0 }
            });
        
        let m = xx.mul(Fp2 {
            c0: Fp { value: 3 },
            c1: Fp { value: 0 }
        });
        let t = m.mul(m).sub(s.mul(Fp2 {
            c0: Fp { value: 2 },
            c1: Fp { value: 0 }
        }));
        
        let new_x = t;
        let new_y = m.mul(s.sub(t)).sub(yyyy.mul(Fp2 {
            c0: Fp { value: 8 },
            c1: Fp { value: 0 }
        }));
        let new_z = self.y.mul(self.z).mul(Fp2 {
            c0: Fp { value: 2 },
            c1: Fp { value: 0 }
        });

        G2Point { x: new_x, y: new_y, z: new_z }
    }

    fn add(self: G2Point, other: G2Point) -> G2Point {
        if self.z.c0.value == 0 && self.z.c1.value == 0 {
            return other;
        }
        if other.z.c0.value == 0 && other.z.c1.value == 0 {
            return self;
        }

        // Addition formulas for BN254 G2
        let z1z1 = self.z.mul(self.z);
        let z2z2 = other.z.mul(other.z);
        let u1 = self.x.mul(z2z2);
        let u2 = other.x.mul(z1z1);
        let s1 = self.y.mul(other.z).mul(z2z2);
        let s2 = other.y.mul(self.z).mul(z1z1);
        
        if u1.c0.value == u2.c0.value && u1.c1.value == u2.c1.value {
            if s1.c0.value == s2.c0.value && s1.c1.value == s2.c1.value {
                return self.double();
            }
            return G2Point {
                x: Fp2 {
                    c0: Fp { value: 0 },
                    c1: Fp { value: 0 }
                },
                y: Fp2 {
                    c0: Fp { value: 1 },
                    c1: Fp { value: 0 }
                },
                z: Fp2 {
                    c0: Fp { value: 0 },
                    c1: Fp { value: 0 }
                }
            };
        }

        let h = u2.sub(u1);
        let i = h.mul(Fp2 {
            c0: Fp { value: 2 },
            c1: Fp { value: 0 }
        }).mul(h);
        let j = h.mul(i);
        let r = s2.sub(s1).mul(Fp2 {
            c0: Fp { value: 2 },
            c1: Fp { value: 0 }
        });
        let v = u1.mul(i);
        
        let new_x = r.mul(r).sub(j).sub(v.mul(Fp2 {
            c0: Fp { value: 2 },
            c1: Fp { value: 0 }
        }));
        let new_y = r.mul(v.sub(new_x)).sub(s1.mul(j).mul(Fp2 {
            c0: Fp { value: 2 },
            c1: Fp { value: 0 }
        }));
        let new_z = h.mul(self.z).mul(other.z).mul(Fp2 {
            c0: Fp { value: 2 },
            c1: Fp { value: 0 }
        });

        G2Point { x: new_x, y: new_y, z: new_z }
    }

    fn mul(self: G2Point, scalar: felt252) -> G2Point {
        let mut result = G2Point {
            x: Fp2 {
                c0: Fp { value: 0 },
                c1: Fp { value: 0 }
            },
            y: Fp2 {
                c0: Fp { value: 1 },
                c1: Fp { value: 0 }
            },
            z: Fp2 {
                c0: Fp { value: 0 },
                c1: Fp { value: 0 }
            }
        };
        let mut temp = self;
        let mut s = scalar;

        while s > 0 {
            if s & 1 == 1 {
                result = result.add(temp);
            }
            temp = temp.double();
            s >>= 1;
        }

        result
    }

    fn is_on_curve(self: G2Point) -> bool {
        let affine = self.to_affine();
        if affine.z.c0.value == 0 && affine.z.c1.value == 0 {
            return true;
        }

        let y2 = affine.y.mul(affine.y);
        let x3 = affine.x.mul(affine.x).mul(affine.x);
        let b = Fp2 {
            c0: Fp { value: CURVE_B },
            c1: Fp { value: 0 }
        };
        
        y2.c0.value == x3.add(b).c0.value && y2.c1.value == x3.add(b).c1.value
    }

    fn to_affine(self: G2Point) -> G2Point {
        if self.z.c0.value == 0 && self.z.c1.value == 0 {
            return self;
        }

        let z_inv = self.z.inv();
        let z_inv_squared = z_inv.mul(z_inv);
        let z_inv_cubed = z_inv_squared.mul(z_inv);
        
        G2Point {
            x: self.x.mul(z_inv_squared),
            y: self.y.mul(z_inv_cubed),
            z: Fp2 {
                c0: Fp { value: 1 },
                c1: Fp { value: 0 }
            }
        }
    }
}
