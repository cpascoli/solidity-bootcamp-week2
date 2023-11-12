// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { ERC721Enumerable } from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ERC2981 } from "@openzeppelin/contracts/token/common/ERC2981.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { BitMaps } from "@openzeppelin/contracts/utils/structs/BitMaps.sol";


/**
 *  @title NFT with whitelist for sale price discount
 *  @author Carlo Pascoli
 *  @notice NFT minting contract with whitelist of addresses that get a discount on the minting price.
 *          BitMaps are used to prevent multiple mints from the same whitelisted addresses.
 *
 */
contract MyNFT is ERC721Enumerable, ERC2981, Ownable2Step {

    using BitMaps for BitMaps.BitMap;

    uint256 public constant DISCOUNT_PERCENTAGE_DENOMINATOR = 1e4;

    uint256 public immutable MINT_PRICE; // in wei
    uint96 public immutable MAX_SUPPLY;
    uint96 public immutable FEE_NUMERATOR; // uses 10000 denumerator
    uint96 public immutable DISCOUNT_PERCENTAGE; // includes DISCOUNT_PERCENTAGE_DENOMINATOR decimals


    /// @notice the Id of the last NFT minted
    uint256 public tokenId;

    /// @notice the root of the merkle tree used to verify white-listed addresses
    bytes32 public merkleRoot;

    /// @notice is mint is enabled
    bool isPublicMintEnabled;

    /// @notice Bitmap to keep track of addresses who already minted  
    BitMaps.BitMap private mintedAddresses;

    // Errors
    error MaxSupplyReached();
    error AddressAlreadyMinted();
    error WrongPrice(uint256 sent, uint256 expected);
    error MintNotEnabled();
    error NoBots();
    error ZeroAddress();

    // Events
    event MerkleRootSet(bytes32 root);
    event Withdrawn(address indexed recipient, uint256 amount);
    event PublicMintEnabledChanged(bool isEnabled);


    constructor(
        uint96 maxSupply, 
        uint96 feeNumerator,
        uint96 discountPercentage,
        uint256 mintPrice
    ) ERC721("My NFT Token", "MT") {

        MAX_SUPPLY = maxSupply;
        FEE_NUMERATOR = feeNumerator;
        DISCOUNT_PERCENTAGE = discountPercentage;
        MINT_PRICE = mintPrice;

        super._setDefaultRoyalty(msg.sender, FEE_NUMERATOR);
    }



    /// @notice mint to an address with an optionl discount
    /// @param recipient The recipient of the NFT that could be whitelisted or not.
    /// @param index An optional index of the address provided in the list of whitelisted addresses.
    /// @param merkleProof An optional proof that can be provided to prove the address is whitelisted. 
    function mint(address recipient, uint256 index, bytes32[] calldata merkleProof) external payable {

        // determine the price of the NFT based on the whiteist status of the recipient address
        (uint256 price, bool whitelisted) = priceForMint(recipient, merkleProof, index);

        // check if a whitelisted address did already mint and remember that.
        if (whitelisted){
            if (mintedAddresses.get(index)) revert AddressAlreadyMinted();
            mintedAddresses.set(index);
        }
      
        mintAtPrice(recipient, price);
    }


    /// @notice Set the root of the Merkle tree used to verify the whitelisted addresses
    /// @param _merkleRoot The merkle root of the list of whitelisted addresses
    function setWhiteListMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;

        emit MerkleRootSet(merkleRoot);
    }

 
    /// @notice allow the owner to withdraw the ETH from the contract
    /// @param amount The amount of ETH to withdraw. If 0 is passed witwithdraw the full balance.
    function withdraw(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();

        uint256 amountToWithdraw = amount == 0 ? address(this).balance : amount;
        
        if (amountToWithdraw == 0) return;

        emit Withdrawn(to, amount);
        (bool success, ) = to.call{ value: amountToWithdraw }("");

        require(success, "Could not send ETH");
    }


    /// @notice Allow the owner to enable and disable the public mint
    /// @param enableMint True if public mint should be enabled, false otherwise
    function enablePublicMint(bool enableMint) external onlyOwner {
        isPublicMintEnabled = enableMint;

        emit PublicMintEnabledChanged(enableMint);
    }


    ////// Public functions //////

    /// @notice The price for the mint for the given address (can be discounted if a valid proof is provided)
    /// @param addr An address that could be whitelisted or not.
    /// @param merkleProof An optional proof that can be provided to prove the address is whitelisted. 
    /// @param addr An address that could be whitelisted or not.
    /// @dev the index is associated to the whitelisted address and included in the proof verification
    function priceForMint(address addr, bytes32[] calldata merkleProof, uint256 index) public view returns (uint256 price, bool whitelisted) {
        
        whitelisted = isWhitelistedAddress(addr, merkleProof, index);
        
        uint256 discount = whitelisted ? MINT_PRICE * DISCOUNT_PERCENTAGE / DISCOUNT_PERCENTAGE_DENOMINATOR : 0;
        
        price = MINT_PRICE - discount;
    }


    /// @notice Returns true if the provided interfaceId is supported
    /// @param interfaceId An interface Id
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }


    /// @notice Verifies that the address is included in the set of whitelistesd addresses
    /// @param addr An address to check
    /// @param merkleProof The Merkle proof for the address provided. Can be empty for non whitelisted addresses.
    /// @param index The index for the address in the whitelist (when a merkleProof is provided)
    function isWhitelistedAddress(address addr, bytes32[] calldata merkleProof, uint256 index) public view returns (bool) {
        
        // if no proof is provided the address is not whitelisted
        if (merkleProof.length == 0) return false;

        // Verify the merkle proof.
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(addr, index))));

        return MerkleProof.verifyCalldata(merkleProof, merkleRoot, leaf);
    }


    /// @notice Intenal mint function
    /// @param to The address receiving the NFT
    /// @param price The price of the NFT to mint
    function mintAtPrice(address to, uint256 price) internal  {

        // performs various pre-mint checks
        if (totalSupply() == MAX_SUPPLY) revert MaxSupplyReached(); // max supply not reached
        if (!isPublicMintEnabled) revert MintNotEnabled(); // mint is enabled
        if (msg.sender != tx.origin) revert NoBots(); //  minter is EOA
        if (msg.value != price) revert WrongPrice(msg.value, price); // correct price was paid

        // Mint the NFT
        super._safeMint(to, ++tokenId);
    }

}
