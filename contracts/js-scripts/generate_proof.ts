import { Noir } from "@noir-lang/noir_js";
import { ethers } from "ethers"; 
import { UltraHonkBackend, Barretenberg, BackendOptions } from "@aztec/bb.js";
 import { fileURLToPath } from "url";
import path from "path";
import fs from 'fs'

// const cicuitPath = path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../circuit/target/zk_panagram.json');

const cicuitPath = path.resolve(__dirname,'../../circuit/target/zk_panagram.json');
const circuit = JSON.parse(fs.readFileSync(cicuitPath, 'utf8'))

export default async function generateProof():  Promise<any> {

    const inputsArray = process.argv.slice(2)

    try {

        const noir = new Noir(circuit)
        const options: BackendOptions = { threads: 1 };
        const api = await Barretenberg.new(options);
        const bb = new UltraHonkBackend(circuit.bytecode, api);

        const inputs = {
            // private input 
            guess_hash: inputsArray[0],
            // public input
            answer_hash: inputsArray[1],
            // 
            address: inputsArray[2] // the address of the user making the guess, passed as a public input to the circuit to prevent it from being optimized out during compilation
        }
        
        // Generate witness and return value by executing the circuit with the provided inputs
       const { witness} =  await noir.execute(inputs);
       
       // suppress console logs from the backend during proof generation to prevent logs from being returned as part of foundry ffi output
       const originalConsoleLog = console.log; // first store the original console.log function
       console.log = () => {}; // then override console.log to a no-op function to suppress logs
       // Generate the proof using the witness
       const proofdata = await bb.generateProof(witness, {verifierTarget: 'evm'});
        bb.verifyProof(proofdata) // verify the proof before returning it to ensure it's valid
       const { proof } = proofdata

       console.log = originalConsoleLog; // restore the original console.log function after proof generation is complete

       // ABI encode the proof to be sent to the smart contract
       const encodedProof = ethers.AbiCoder.defaultAbiCoder().encode(["bytes"],[proof])

       return encodedProof


    }catch(e) {
        console.error(e)
        throw e
    }

}

(async () =>  {
     try {
         const proof = await generateProof();
        process.stdout.write(proof)     
        process.exit(0)
     } catch(e) {
        console.error(e)
        process.exit(1)
     }
})()