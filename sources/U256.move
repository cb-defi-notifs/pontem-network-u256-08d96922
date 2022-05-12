/// The implementation of large numbers written in Move language.
/// Code derived from original work by Andrew Poelstra <apoelstra@wpsoftware.net>
///
/// Rust Bitcoin Library
/// Written in 2014 by
///	   Andrew Poelstra <apoelstra@wpsoftware.net>
///
/// To the extent possible under law, the author(s) have dedicated all
/// copyright and related and neighboring rights to this software to
/// the public domain worldwide. This software is distributed without
/// any warranty.
///
/// Simplified implemntation by Parity Team - https://github.com/paritytech/parity-common/blob/master/uint/src/uint.rs
///
/// Would be nice to help with the following TODO list:
/// * Refactoring.
/// * Gas optimisation.
/// * Still missing Div func.
/// * More tests.
module Sender::U256 {
    use Std::Vector;

    // Errors.
    /// When can't cast `U256` to `u128` (e.g. number too large).
    const EU128_OVERFLOW: u64 = 0;

    // Constants.

    /// Max `u64` value.
    const MAX_U64: u128 = 18446744073709551615;

    /// Max `u128` value.
    const MAX_u128: u128 = 340282366920938463463374607431768211455;

    /// Total words in `U256` (64 * 4 = 256).
    const WORDS: u64 = 4;

    // Data structs.

    /// The `U256` resource.
    /// Contains 4 u64 numbers inside in vector `ret`.
    struct U256 has copy, drop, store {
        ret: vector<u64>,
    }

    // Public functions.

    /// Adds two U256 and returns sum.
    public fun add(a: U256, b: U256): U256 {
        let ret = Vector::empty<u64>();
        let carry = 0u64;

        let i = 0;
        while (i < WORDS) {
            let a1 = *Vector::borrow(&a.ret, i);
            let b1 = *Vector::borrow(&b.ret, i);

            if (carry != 0) {
                let (res1, is_overflow1) = overflowing_add(a1, b1);
                let (res2, is_overflow2) = overflowing_add(res1, carry);
                Vector::push_back(&mut ret, res2);

                carry = 0;
                if (is_overflow1) {
                    carry = carry + 1;
                };

                if (is_overflow2) {
                    carry = carry + 1;
                }
            } else {
                let (res,is_overflow) = overflowing_add(a1, b1);
                Vector::push_back(&mut ret, res);

                carry = 0;
                if (is_overflow) {
                    carry = 1;
                };
            };

            i = i + 1;
        };

        U256 { ret }
    }

    /// Convert `U256` to `u128` value if possible (otherwise it aborts).
    public fun as_u128(a: U256): u128 {
        let a1 = *Vector::borrow(&a.ret, 0);
        let a2 = *Vector::borrow(&a.ret, 1);
        let z = *Vector::borrow(&a.ret, 2);

        assert!(z == 0, EU128_OVERFLOW);

        ((a2 as u128) << 64) + (a1 as u128)
    }

    /// Returns a `U256` from `u128` value.
    public fun from_u128(val: u128): U256 {
        let (a2, a1) = split_u128(val);

        let ret = Vector::singleton<u64>(a1);
        Vector::push_back(&mut ret, a2);
        Vector::push_back(&mut ret, 0);
        Vector::push_back(&mut ret, 0);

        U256 { ret }
    }

    /// Multiples two `U256`, returns result.
    public fun mul(a: U256, b: U256): U256 {
        let ret = Vector::empty<u64>();

        let i = 0;
        while (i < WORDS * 2) {
            Vector::push_back(&mut ret, 0);
            i = i + 1;
        };

        let i = 0;
        while (i < WORDS) {
            let carry = 0u64;
            let b1 = *Vector::borrow(&b.ret, i);

            let j = 0;
            while (j < WORDS) {
                let a1 = *Vector::borrow(&a.ret, j);

                if (a1 != 0 || carry != 0) {
                    let (hi, low) = split_u128((a1 as u128) * (b1 as u128));

                    let overflow = {
                        let existing_low = Vector::borrow_mut(&mut ret, i + j);
                        let (low, o) = overflowing_add(low, *existing_low);
                        *existing_low = low;
                        if (o) {
                            1
                        } else {
                            0
                        }
                    };

                    carry = {
                        let existing_hi = Vector::borrow_mut(&mut ret, i + j + 1);
                        let hi = hi + overflow;
                        let (hi, o0) = overflowing_add(hi, carry);
                        let (hi, o1) = overflowing_add(hi, *existing_hi);
                        *existing_hi = hi;

                        if (o0 || o1) {
                            1
                        } else {
                            0
                        }
                    };
                };

                j = j + 1;
            };

            i = i + 1;
        };

        // TODO: probably check zeros in ret[4..] and see if overflow happened and abort?

        let final = Vector::empty<u64>();
        let i = 0;
        while (i < WORDS) {
            Vector::push_back(&mut final, *Vector::borrow(&ret, i));
            i = i + 1;
        };

        U256 { ret: final }
    }

    /// Subtracts two `U256`, returns result.
    public fun sub(a: U256, b: U256): U256 {
        let ret = Vector::empty<u64>();

        let carry = 0u64;

        let i = 0;
        while (i < WORDS) {
            let a1 = *Vector::borrow(&a.ret, i);
            let b1 = *Vector::borrow(&b.ret, i);

            if (carry != 0) {
                let (res1, is_overflow1) = overflowing_sub(a1, b1);
                let (res2, is_overflow2) = overflowing_sub(res1, carry);
                Vector::push_back(&mut ret, res2);

                carry = 0;
                if (is_overflow1) {
                    carry = carry + 1;
                };

                if (is_overflow2) {
                    carry = carry + 1;
                }
            } else {
                let (res,is_overflow) = overflowing_sub(a1, b1);
                Vector::push_back(&mut ret, res);

                carry = 0;
                if (is_overflow) {
                    carry = 1;
                };
            };

            i = i + 1;
        };

        U256 { ret }
    }

    // Private functions.

    /// Similar to Rust `overflowing_add`.
    /// Returns a tuple of the addition along with a boolean indicating whether an arithmetic overflow would occur.
    /// If an overflow would have occurred then the wrapped value is returned.
    fun overflowing_add(a: u64, b: u64): (u64, bool) {
        let a128 = (a as u128);
        let b128 = (b as u128);

        let r = a128 + b128;
        if (r > MAX_U64) {
            // overflow
            let overflow = r - MAX_U64 - 1;
            ((overflow as u64), true)
        } else {
            (((a128 + b128) as u64), false)
        }
    }

    /// Similar to Rust `overflowing_sub`.
    /// Returns a tuple of the addition along with a boolean indicating whether an arithmetic overflow would occur.
    /// If an overflow would have occurred then the wrapped value is returned.
    fun overflowing_sub(a: u64, b: u64): (u64, bool) {
        if (a < b) {
            let r = b - a;
            ((MAX_U64 as u64) - r + 1, true)
        } else {
            (a - b, false)
        }
    }

    /// Extracts two `u64` from `u128`.
    fun split_u128(a: u128): (u64, u64) {
        let a1 = ((a >> 64) as u64);
        let a2 = ((a & 0xFFFFFFFFFFFFFFFF) as u64);

        (a1, a2)
    }


    // Tests.

    #[test]
    fun test_from_u128() {
        let i = 0;
        while (i < 1024) {
            let big = from_u128(i);
            assert!(as_u128(big) == i, 1);
            i = i + 1;
        };
    }

    #[test]
    fun test_add() {
        let a = from_u128(1000);
        let b = from_u128(500);

        let s = as_u128(add(a, b));
        assert!(s == 1500, 1);

        a = from_u128(MAX_U64);
        b = from_u128(MAX_U64);

        s = as_u128(add(a, b));
        assert!(s == (MAX_U64*2), 2);
    }

    #[test]
    fun test_sub() {
        let a = from_u128(1000);
        let b = from_u128(500);

        let s = as_u128(sub(a, b));
        assert!(s == 500, 0);

        let overflow = sub(from_u128(0), from_u128(1));
        let i = 0;
        while (i < WORDS) {
            let j = *Vector::borrow(&overflow.ret, i);
            assert!(j == (MAX_U64 as u64), 1);
            i = i + 1;
        }
    }

    #[test]
    #[expected_failure(abort_code = 0)]
    fun test_too_big_to_cast_to_u128() {
        let a = from_u128(MAX_u128);
        let b = from_u128(MAX_u128);

        let _ = as_u128(add(a, b));
    }

    #[test]
    fun test_overflowing_add() {
        let (n, z) = overflowing_add(10, 10);
        assert!(n == 20, 1);
        assert!(!z, 2);

        (n, z) = overflowing_add((MAX_U64 as u64), 1);
        assert!(n == 0, 3);
        assert!(z, 4);

        (n, z) = overflowing_add((MAX_U64 as u64), 10);
        assert!(n == 9, 5);
        assert!(z, 6);

        (n, z) = overflowing_add(5, 8);
        assert!(n == 13, 7);
        assert!(!z, 8);
    }

    #[test]
    fun test_overflowing_sub() {
        let (n, z) = overflowing_sub(10, 5);
        assert!(n == 5, 1);
        assert!(!z, 2);

        (n, z) = overflowing_sub(0, 1);
        assert!(n == (MAX_U64 as u64), 3);
        assert!(z, 4);

        (n, z) = overflowing_sub(10, 10);
        assert!(n == 0, 5);
        assert!(!z, 6);
    }

    #[test]
    fun test_split_u128() {
        let (a1, a2) = split_u128(100);
        assert!(a1 == 0, 0);
        assert!(a2 == 100, 1);

        (a1, a2) = split_u128(MAX_U64 + 1);
        assert!(a1 == 1, 2);
        assert!(a2 == 0, 3);
    }

    #[test]
    fun test_mul() {
        let a = from_u128(285);
        let b = from_u128(375);

        let c = as_u128(mul(a, b));
        assert!(c == 106875, 0);

        a = from_u128(0);
        b = from_u128(1);

        c = as_u128(mul(a, b));

        assert!(c == 0, 1);

        a = from_u128(MAX_U64);
        b = from_u128(2);

        c = as_u128(mul(a, b));

        assert!(c == 36893488147419103230, 2);
    }
}