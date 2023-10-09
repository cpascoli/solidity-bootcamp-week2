import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

import { expect } from "chai";

import { deployPrimeNftCounter, toUnits, toWei, waitSeconds } from "./helpers/test_helpers";
import { formatUnits } from "ethers/lib/utils";


describe("NftCounter", function () {


    it("has the NFT Token", async function () {
        const { primeNftCounter, myNFT } = await loadFixture(deployPrimeNftCounter);

        expect( await primeNftCounter.nftToken() ).to.be.equal( myNFT.address )
    });

    it("count 0 prime nfts when have no nft", async function () {
        const { primeNftCounter, user1 } = await loadFixture(deployPrimeNftCounter);

        expect(await primeNftCounter.countPrimes(user1.address)).to.be.equal(0)
    });


    it("count 2 prime nfts for tokensIds from 10 to 13", async function () {
        const { primeNftCounter, myNFT, user1, user2 } = await loadFixture(deployPrimeNftCounter);

        const fullPrice = await myNFT.MINT_PRICE()

        // mint tokens from 1 to 9 to user1
        for await (let i of Array.from({length: 9}, (_, i) => i)) {
            await myNFT.mint(user1.address, 0, [], {value: fullPrice});
        }

        // mint tokens from 10 to 13 to user2
        for await (let i of Array.from({length: 4}, (_, i) => i+9)) {
            await myNFT.mint(user2.address, 0, [], {value: fullPrice});
        }

        expect(await primeNftCounter.countPrimes(user2.address)).to.be.equal(2)
    });


    it("count 8 prime nfts for tokensIds from 1 to 20", async function () {
        const { primeNftCounter, myNFT, user1, user2 } = await loadFixture(deployPrimeNftCounter);

        const fullPrice = await myNFT.MINT_PRICE()
        // mint tokens from 1 to 20 to user1
        for await (let i of Array.from({length: 20}, (_, i) => i)) {
            await myNFT.mint(user1.address, 0, [], {value: fullPrice});
        }

        expect(await primeNftCounter.countPrimes(user1.address)).to.be.equal(8)
    });
       

    it("count 2 prime nfts for tokensIds from 1 to 3", async function () {
        const { primeNftCounter, myNFT, user1, user2 } = await loadFixture(deployPrimeNftCounter);

        const fullPrice = await myNFT.MINT_PRICE()
        // mint tokens from 1 to 20 to user1
        for await (let i of Array.from({length: 3}, (_, i) => i)) {
            await myNFT.mint(user1.address, 0, [], {value: fullPrice});
        }

        expect(await primeNftCounter.countPrimes(user1.address)).to.be.equal(2)
    });

});