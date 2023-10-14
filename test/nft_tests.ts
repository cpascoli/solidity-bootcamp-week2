import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

import { expect } from "chai";

import { deployMyNFT, toUnits, toWei } from "./helpers/test_helpers";
import { formatUnits } from "ethers/lib/utils";


describe("NFT", function () {

    describe("ERC721", function () {

        describe("config", function () {
            it("has initial suppply of 0", async function () {
                const { myNFT } = await loadFixture(deployMyNFT);

                expect(await myNFT.totalSupply()).to.be.equal( 0 )
            });

            it("has Merkle root for the whitelist", async function () {
                const { myNFT, tree } = await loadFixture(deployMyNFT);

                expect (await myNFT.merkleRoot() ).to.be.equal(tree.root)
            });
        })

        describe("Max supply", function () {

            it("has max supply of 20 NFT", async function () {

                const { myNFT, user1} = await loadFixture(deployMyNFT);

                expect(await myNFT.MAX_SUPPLY()).to.be.equal( 20 );
            });

            it("can mint up to 20 NFT", async function () {

                const { myNFT, user1} = await loadFixture(deployMyNFT);
                const fullPrice = await myNFT.MINT_PRICE()

                // Mint 20 NFT at full price
                for await (let i of Array.from({length: 20}, (_, i) => i)) {
                    
                    await myNFT.mint(user1.address, 0, [], {value: fullPrice});
                }
                
                expect(await myNFT.totalSupply()).to.be.equal( 20 );

                // Minting more then the max supply reverts
                await expect( 
                    myNFT.mint(user1.address, 0, [], {value: fullPrice})
                ).to.be.revertedWithCustomError(myNFT, "MaxSupplyReached")
            });
        })

        describe("Merkle tree", function () {

            it("is a whitelisted addres when a valid proof is provided", async function () {
                const { myNFT, tree, user1, user2} = await loadFixture(deployMyNFT);

                // Generate proof for user1
                let proof;
                for (const [i, v] of tree.entries()) {
                    if (v[0] === user1.address) {
                        proof = tree.getProof(i);
                        break;
                    }
                }

                // Verify user1 address is included in the whitelisted set
                expect (await myNFT.isWhitelistedAddress(user1.address, proof, 1) ).to.be.true
                  
                // Verify user2 address is not included in the whitelisted set
                expect (await myNFT.isWhitelistedAddress(user2.address, proof, 2) ).to.be.false
            });

            it("is not a whitelisted address when a proof is not provided", async function () {
                const { myNFT, user2} = await loadFixture(deployMyNFT);

                // Verify user2 address is not included in the whitelisted set
                expect (await myNFT.isWhitelistedAddress(user2.address, [], 1) ).to.be.false
            });

        })

        describe("Whitelist", function () {

            it("apply discount to whitelisted address", async function () {
                const { myNFT, tree, user0, user1, user2} = await loadFixture(deployMyNFT);

                // Generate proof for user1
                let whitelistProof;
                for (const [i, v] of tree.entries()) {
                    if (v[0] === user1.address) {
                        whitelistProof = tree.getProof(i);
                        break;
                    }
                }

                const fullPrice = await myNFT.MINT_PRICE()
                const [ myPrice, whitelisted ] = await myNFT.priceForMint(user1.address, whitelistProof, 1);
                const discountedPrice = fullPrice.mul(8).div(10) // 20% discount

                expect( myPrice ).to.be.equal( discountedPrice )

                // Mint 1 NFT at discounted price
                await myNFT.mint(user1.address, 1, whitelistProof, {value: discountedPrice});

                // verity that have 1 NFT
                expect( await myNFT.balanceOf(user1.address) ) .to.be.equal( 1 )
            });

            it("does not apply discount to non whitelisted address", async function () {
                const { myNFT, tree, user2} = await loadFixture(deployMyNFT);
                const fullPrice = await myNFT.MINT_PRICE()
                const [myPrice, whitelisted] = await myNFT.priceForMint(user2.address, [], 2);

                expect( myPrice ).to.be.equal( fullPrice )

                 // Mint 1 NFT at full price
                await myNFT.mint(user2.address, 0, [], {value: fullPrice});

                // verity that have 1 NFT
                expect( await myNFT.balanceOf(user2.address) ) .to.be.equal( 1 )
            });

            it("cannot mint again to a whitelisted address", async function () {
                const { myNFT, tree, user1, user2 } = await loadFixture(deployMyNFT);

                // Generate proof for user1
                let whitelistProof;
                for (const [i, v] of tree.entries()) {
                    if (v[0] === user1.address) {
                        whitelistProof = tree.getProof(i);
                        break;
                    }
                }

                const fullPrice = await myNFT.MINT_PRICE()
                const [ myPrice, whitelisted ] = await myNFT.priceForMint(user1.address, whitelistProof, 1);
                const discountedPrice = fullPrice.mul(8).div(10) // 20% discount

                expect( myPrice ).to.be.equal( discountedPrice )

                // Mint 1 NFT at discounted price
                await myNFT.mint(user1.address, 1, whitelistProof, {value: discountedPrice});

                // Verity that trying to mint another NFT reverts
                await expect( 
                    myNFT.mint(user1.address, 1, whitelistProof, {value: discountedPrice})
                ).to.be.revertedWithCustomError(myNFT, "AddressAlreadyMinted")

            });


        })

    })

});