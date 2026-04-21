compile cicuit  # we dont need `nargo check` since we do not need the Prover.toml 
And we do not need `nargo check` because we do not need to create the witness

compile the bytecode to circuit so we can generate the verifier contract

1. Generate solidity verifier 
> nargo compile

2. creat the verifier key for solidity verifer - uses keccak becaiuse it is more optimized for onchain hashing
>bb write_vk  -b ./target/zk_panagram.json -o ./target -t evm

3. Generate a solidity verifier smart contract 
> bb write_solidity_verifier -k ./target/vk -o ./verifier/Verifier.sol -t evm

4. Run the test
> Forge test -vvvv



##################To verify offchain 

0. Delete target folder
1. Generate prover file 
> nargo check 

1. generate witness
> nargo execute 

1. generate proof
> bb prove -b target/zk_panagram.json -w target/zk_panagram.gz --write_vk  -o ./target  

to verify the proof offchain

> bb verify -k ./target/vk -p ./target/proof