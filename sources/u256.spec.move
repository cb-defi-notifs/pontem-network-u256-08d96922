spec u256::u256 {
    spec fun max_u256(): num {
        (U128_MAX << 128) + U128_MAX
    }

    spec fun num_val(a: U256): num {
        a.v0 + (a.v1 << 64) + (a.v2 << 128) + (a.v3 << 192)
    }

    spec max {
        aborts_if false;
        ensures result.v0 == U64_MAX;
        ensures result.v1 == U64_MAX;
        ensures result.v2 == U64_MAX;
        ensures result.v3 == U64_MAX;
        ensures num_val(result) == max_u256();
    }

    spec get {
        pragma verify = false;

        aborts_if i > 3 with EWORDS_OVERFLOW;
        ensures i == 0 ==> result == a.v0;
        ensures i == 1 ==> result == a.v1;
        ensures i == 2 ==> result == a.v2;
        ensures i == 3 ==> result == a.v3;
    }

    spec put {
        pragma verify = false;

        aborts_if i > 3 with EWORDS_OVERFLOW;
        ensures i == 0 ==> a.v0 == val;
        ensures i == 1 ==> a.v1 == val;
        ensures i == 2 ==> a.v2 == val;
        ensures i == 3 ==> a.v3 == val;
    }

    spec zero {
        pragma verify = false;

        aborts_if false;
        ensures result.v0 == 0;
        ensures result.v1 == 0;
        ensures result.v2 == 0;
        ensures result.v3 == 0;
        ensures num_val(result) == 0;
    }

    spec from_u128 {
        pragma verify = false;

        aborts_if false;
        ensures num_val(result) == val;
    }

    spec from_u64 {
        pragma verify = false;

        aborts_if false;
        ensures num_val(result) == val;
    }

    spec compare {
        pragma verify = false;

        aborts_if false;
        ensures num_val(a) > num_val(b) ==> result == GREATER_THAN;
        ensures num_val(a) < num_val(b) ==> result == LESS_THAN;
        ensures num_val(a) == num_val(b) ==> result == EQUAL;
    }

    spec as_u128 {
        pragma verify = false;

        aborts_if num_val(a) > U128_MAX with ECAST_OVERFLOW;
        ensures result == num_val(a);
    }

    spec as_u64 {
        pragma verify = false;

        aborts_if num_val(a) > U64_MAX with ECAST_OVERFLOW;
        ensures result == num_val(a);
    }

    spec sub {
        pragma verify = false;
        ensures num_val(result) == num_val(a) - num_val(b);
    }

    spec mul {
        pragma verify = false;
        ensures num_val(result) == num_val(a) * num_val(b);
    }

    spec div {
        pragma verify = false;
    }

    spec shr {
        pragma verify = false;
        ensures num_val(result) == num_val(a) >> shift;
    }

    spec shl {
        pragma verify = false;
        ensures num_val(result) == num_val(a) << shift;
    }

    spec add {
        pragma verify = false;
        ensures num_val(result) == num_val(a) + num_val(b);
    }
}
