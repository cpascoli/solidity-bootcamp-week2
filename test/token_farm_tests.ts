import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

import { expect } from "chai";

import { deployTokenFarm, toUnits, toWei, waitSeconds } from "./helpers/test_helpers";
import { formatUnits } from "ethers/lib/utils";


describe("TokenFarm", function () {

    describe("config", function () {

        it("has the NFT Token", async function () {
            const { tokenFarm, myNFT } = await loadFixture(deployTokenFarm);

            expect( await tokenFarm.nftToken() ).to.be.equal( myNFT.address )
        });

        it("has the Reward Token", async function () {
            const { tokenFarm, rewardToken } = await loadFixture(deployTokenFarm);

            expect( await tokenFarm.rewardToken() ).to.be.equal( rewardToken.address )
        });

        it("owns the Reward Token", async function () {
            const { tokenFarm, rewardToken, owner } = await loadFixture(deployTokenFarm);

            expect( await rewardToken.owner() ).to.be.equal( tokenFarm.address )
        });
    })


    describe("deposit", function () {
        it("can deposit the NFT", async function () {

            const { tokenFarm, myNFT, rewardToken, owner, user0 } = await loadFixture(deployTokenFarm);
   
            // send NFT to the contract
            await myNFT.connect(user0)["safeTransferFrom(address,address,uint256)"](user0.address, tokenFarm.address, 1)

            expect( await myNFT.ownerOf(1) ).to.be.equal(tokenFarm.address)
        });
    })

    describe("withdraw", function () {
        it("can withdraw the NFT", async function () {

            const { tokenFarm, myNFT, rewardToken, owner, user0 } = await loadFixture(deployTokenFarm);
   
            // send NFT to the contract
            await myNFT.connect(user0)["safeTransferFrom(address,address,uint256)"](user0.address, tokenFarm.address, 1)

            // withraw the nft
            await tokenFarm.connect(user0).withdraw(1)

            expect( await myNFT.ownerOf(1) ).to.be.equal(user0.address)
        });
    })

    describe("claim rewards", function () {

        it("can claim 10 tokens after staking for 24h", async function () {

            const { tokenFarm, myNFT, rewardToken, owner, user0 } = await loadFixture(deployTokenFarm);
   
            // send NFT to the contract
            await myNFT.connect(user0)["safeTransferFrom(address,address,uint256)"](user0.address, tokenFarm.address, 1)

            // wait for 24h
            await waitSeconds(24 * 60 * 60)

            // claim the ERC20 token
            await tokenFarm.connect(user0).claimTokens(1);

            // verify to have received approximately 10 tokens 
            const balanceAfter = toUnits(await rewardToken.balanceOf(user0.address))

            expect( balanceAfter ).to.be.approximately(10, 0.001)
        });


        it("accounts for tokens already ckaimed when claiming again", async function () {

            const { tokenFarm, myNFT, rewardToken, owner, user0 } = await loadFixture(deployTokenFarm);
   
            // send NFT to the contract
            await myNFT.connect(user0)["safeTransferFrom(address,address,uint256)"](user0.address, tokenFarm.address, 1)

            // wait for 24h
            await waitSeconds(24 * 60 * 60)

            // claim the ERC20 token
            await tokenFarm.connect(user0).claimTokens(1);

            // verify to have received approximately 10 tokens 
            const balanceAfter1stClaim = toUnits(await rewardToken.balanceOf(user0.address))
            expect( balanceAfter1stClaim ).to.be.approximately(10, 0.001)

            // wait for 1h
            await waitSeconds(1 * 60 * 60)

            // claim again
            await tokenFarm.connect(user0).claimTokens(1);

            // verify that user0 received the expected amount of additional tokens 
            const tokensReceived = toUnits(await rewardToken.balanceOf(user0.address)) - balanceAfter1stClaim
            const expectedFarmed = 10 / 24 // tokens farmed in 1h

            expect( tokensReceived ).to.be.approximately(expectedFarmed, 0.001)

        });


    })

    

});