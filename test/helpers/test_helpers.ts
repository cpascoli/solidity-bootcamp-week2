import { ethers } from "hardhat";
import {  BigNumber } from "ethers";
import { time } from "@nomicfoundation/hardhat-network-helpers";
import { StandardMerkleTree } from "@openzeppelin/merkle-tree";


export type Bid = { price: number, timestamp: number }
export const day = 24 * 60 * 60;

/**
 * Increases the time of the test blockchain by the given number of seconds
 * @param secs the number of seconds to wait
 */
export const waitSeconds = async  (secs: number) => {
	const ts = (await time.latest()) + secs
	await time.increaseTo(ts)
}

/**
 * Converts from wei to units.
 * @param amount the amount in wei to convert in units
 * @returns the amount in units as a number
 */
export const toUnits = (amount: BigNumber) : number => {
    return Number(ethers.utils.formatUnits(amount, 18));
}

/**
 * Converts from units to wei.
 * @param units the amount of units to convert in wei
 * @returns the unit value in wei as a BigNumber
 */
export const toWei = (units: number) : BigNumber => {
    return ethers.utils.parseUnits( units.toString(), 18); 
}

/**
 * @returns the timestamp of the last mined block.
 */
export const getLastBlockTimestamp = async () => {
    return (await ethers.provider.getBlock(await ethers.provider.getBlockNumber())).timestamp
}

/**
 * @returns an object containing an instance of the MyNFT contract
 */
export const deployMyNFT = async () => {

    const [ owner, user0, user1, user2 ] = await ethers.getSigners();

    const MAX_SUPPLY = 20;
    const FEE_NUMERATOR = 250; // 2.5% fee
    const DISCOUNT_PERCENTAGE = 2000; // 20% discount
    const MINT_PRICE = toWei( 0.1 ); // 0.1 ETH

    const MyNFT = await ethers.getContractFactory("MyNFT")
    const myNFT = await MyNFT.deploy(MAX_SUPPLY, FEE_NUMERATOR, DISCOUNT_PERCENTAGE, MINT_PRICE)

    await myNFT.enablePublicMint(true)

    // enable address whitelist

    // (1) define the values in the Merkle tree as the whitelisted addresses
    // each leaf in the Merkle tree includes the whitelisted address and associated index
    const values = [
        [user0.address, 0],
        [user1.address, 1]
    ];

    // (2) build the Merkle tree
    const tree = StandardMerkleTree.of(values, ["address", "uint256"]);

    // set the Merkle root for the whitelisted addresses
    await myNFT.setWhiteListMerkleRoot(tree.root)

    return { myNFT, tree, owner, user0, user1, user2 };
}


/**
 * @returns an object containing an instance of the MyNFT contract
 */

export const deployTokenFarm = async () => {

   const  { myNFT, owner, user0, user1, user2 } = await deployMyNFT()

    const RewardToken = await ethers.getContractFactory("RewardToken")
    const rewardToken = await RewardToken.deploy()

    const TokenFarm = await ethers.getContractFactory("TokenFarm")
    const tokenFarm = await TokenFarm.deploy(myNFT.address, rewardToken.address)

    await rewardToken.transferOwnership(tokenFarm.address)

    // Mint 1 NFT to user0
    const fullPrice = await myNFT.MINT_PRICE()
    await myNFT.mint(user0.address, 0, [], {value: fullPrice});

    return { tokenFarm, myNFT, rewardToken, owner, user0, user1, user2 };
}




/**
 * @returns an object containing an instance of the PrimeNftCounter contract
 */

export const deployPrimeNftCounter = async () => {

    const  { myNFT, owner, user0, user1, user2 } = await deployMyNFT()
 
     const PrimeNftCounter = await ethers.getContractFactory("PrimeNftCounter")
     const primeNftCounter = await PrimeNftCounter.deploy(myNFT.address)
 
     
     return { primeNftCounter, myNFT, owner, user0, user1, user2 };
 }
 