// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;


import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IRewardToken } from "./token/RewardToken.sol";


/**
 *  @title A farming contract for users who stake their NFTs.
 *  @author Carlo Pascoli
 *  @notice A contract that can mint ERC20 tokens to NFT token holders who stake their NFTs.
 *          Users can send their NFTs and withdraw 10 ERC20 tokens every 24 hours.
 *
 */
contract TokenFarm is Ownable2Step, IERC721Receiver {

    uint256 constant public REWARD_PER_24H = 10;

    IERC721 public immutable nftToken;
    IRewardToken public immutable rewardToken;
    mapping (uint256 => address) public tokenToOwner;
    mapping (address => uint256) public ownerToTimeFarming;


    error TokenTransferNotApproved();
    error NotTheTokenOwner();
    // error AlreadyDeposited();
    error InvalidCaller();

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
        delete ownerToTimeFarming[msg.sender];

        emit Withdrawn(msg.sender, tokenId);

        nftToken.safeTransferFrom(address(this), msg.sender, tokenId);
    }


    /// @notice Clain the ERC20 tokens for the NFT staked 
    function claimTokens(uint256 tokenId) external {

        // check that the NFT deposited belongs to the caller
        if (tokenToOwner[tokenId] != msg.sender) revert NotTheTokenOwner();

        uint256 toMint = claimableTokens(msg.sender);

        // update last claim timestamp
        ownerToTimeFarming[msg.sender] = block.timestamp;

        emit Claimed(msg.sender, toMint);

        // mint tokens to the caller
        rewardToken.mint(msg.sender, toMint);
    }


    /// @notice IERC721Receiver callback executed when safeTransferFrom is used to send the NFT to this contract
    function onERC721Received(
        address /*operator*/,
        address from,
        uint256 tokenId,
        bytes calldata /*data*/
    ) external returns (bytes4) {

        // ensure the caller is the nft contract
        if(msg.sender != address(nftToken)) revert InvalidCaller();

        tokenToOwner[tokenId] = from;
        ownerToTimeFarming[from] = block.timestamp;

        emit Deposited(msg.sender, tokenId);

        return IERC721Receiver.onERC721Received.selector;
    }


    /// @notice Returns the amount of tokens claimable by the given address
    function claimableTokens(address addr) public view returns (uint256 tokensToMint) {

        // if there is no record of the address farming return 0
        uint256 claimIntervalStart = ownerToTimeFarming[addr];
        if (claimIntervalStart == 0) return 0;

        // the time interval since the NFT was depoisted or the last claim
        uint256 farmingPeriod = block.timestamp - claimIntervalStart;

        // calculate the amount of tokens to mint to the staker
        uint256 secondsIn24h = 1 days;
        uint256 rewardTokenDecimals = 1e18;
        
        tokensToMint = farmingPeriod * REWARD_PER_24H * rewardTokenDecimals / secondsIn24h;
    }

}