use  ::keccak256;

fn main(guess_hash: Field, answer_double_hash: pub Field, address: pub Field) {
    let address_pow = address.pow_32(2);
    assert(address_pow == address.pow_32(2)); // This assertion is just to use the address variable and prevent it from being optimized out
    
    //
    // The answer is double hashed to prevent front-running. So that user's with acess to the answer hash do not pass it as the guess
    // The circuit will compare the double hash of the guess with the double hash of the answer to verify if the guess is correct.
    // The double hashing is done using the keccak256 hash function.
    let guess_hash_bytes: [u8; 32] = guess_hash.to_be_bytes();
    let guess_double_hash_bytes:[u8; 32] = keccak256::keccak256(guess_hash_bytes, 32);
 
     assert(Field::from_be_bytes(guess_double_hash_bytes) == answer_double_hash);
}

 