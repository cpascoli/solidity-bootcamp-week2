// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;


import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IRewardToken } from "./tokens/RewardToken.sol";


/**
 *  @title NFT with 20 max supply
 *  @author Carlo Pascoli
 *  @notice A contract that can mint ERC20 tokens to NFT token holders who stake their NFTs.
 *          Users can send their NFTs and withdraw 10 ERC20 tokens every 24 hours.
 *
 */
contract TokenFarm is Ownable2Step, IERC721Receiver {

    uint256 constant public REWARD_PER_24H = 10;

    IERC721 public nftToken;
    IRewardToken public rewardToken;
    mapping (uint256 => address) public tokenToOwner;
    mapping (address => uint256) public ownerToTimeFarming;


    error TokenTransferNotApproved();
    error NotTheTokenOwner();
    error AlreadyDeposited();

    event Deposited(address indexed sender, uint256 tokenId);
    event Withdrawn(address indexed recipient, uint256 tokenId);
    event Claimed(address indexed recipient, uint256 amount);


    constructor(
        address nftTokenAddress,
        address rewardTokenAddress
    ) {
        nftToken = IERC721(nftTokenAddress);
        rewardToken = IRewardToken(rewardTokenAddress);
    }


    /// @notice withdraw 1 NFT from the contract
    function withdraw(uint256 tokenId) external {

        if (tokenToOwner[tokenId] != msg.sender) revert NotTheTokenOwner();

        delete tokenToOwner[tokenId];

        nftToken.safeTransferFrom(address(this), msg.sender, tokenId);

        emit Withdrawn(msg.sender, tokenId);
    }


    /// @notice Clain the ERC20 tokens for the NFT staked 
    function claimTokens(uint256 tokenId) external {

        // check that the NFT deposited belongs to the caller
        if (tokenToOwner[tokenId] != msg.sender) revert NotTheTokenOwner();

        // the time interval since the NFT was depoisted or the last claim
        uint256 farmingPeriod = block.timestamp - ownerToTimeFarming[msg.sender];

        // calculate the amount of tokens to mint to the staker
        uint256 secondsIn24h = 86_400;
        uint256 rewardTokenDecimals = 1e18;
        uint256 tokensToMint = farmingPeriod * REWARD_PER_24H * rewardTokenDecimals / secondsIn24h;
        ownerToTimeFarming[msg.sender] = block.timestamp;

        rewardToken.mint(msg.sender, tokensToMint);

        emit Claimed(msg.sender, tokensToMint);
    }




    /// @notice IERC721Receiver callback executed when safeTransferFrom is used to send the NFT to this contract
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {

        if(tokenToOwner[tokenId] != address(0)) revert AlreadyDeposited();

        tokenToOwner[tokenId] = from;
        ownerToTimeFarming[from] = block.timestamp;


        emit Deposited(msg.sender, tokenId);

        return IERC721Receiver.onERC721Received.selector;
    }


}