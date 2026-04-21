fn main(guess_hash: Field, answer_hash: pub Field, address: pub Field) {
    let address_pow = address.pow_32(2);
    assert(address_pow == address.pow_32(2)); // This assertion is just to use the address variable and prevent it from being optimized out
    assert(guess_hash == answer_hash);
}

 