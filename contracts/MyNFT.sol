// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

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

    uint96 public immutable MAX_SUPPLY;
    uint96 public immutable FEE_NUMERATOR;  // uses 10000 denumerator
    uint256 public immutable MINT_PRICE;     // in wei
    uint96 public immutable DISCOUNT_PERCENTAGE; // uses _feeDenominator()


    /// @notice the Id of the last NFT minted
    uint256 public tokenId;

    /// @notice the root of the merkle tree used to verify white-listed addresses
    bytes32 public merkleRoot;

    /// @notice is mint is enabled
    bool isPublicMintEnabled;

    /// @notice Bitmap to keep track of addresses who already minted  
    BitMaps.BitMap private mintedAddresses;


    error MaxSupplyReached();
    error AddressAlreadyMinted();
    error WrongPrice(uint256 sent, uint256 expected);
    error MintNotEnabled();
    error NoBots();


    event MerkleRootSet(bytes32 root);
    event Minted(uint256 identifier);


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


    /// @notice Only owner function able to mint an NFT for free to the provided address
    function mintToOwner() external onlyOwner {
        mintAtPrice(msg.sender, 0);
    }


    /// @notice mint to an address with an optionl discount
    function mint(address to, uint256 index, bytes32[] calldata merkleProof) external payable {

        // check if have already minted
       

        // determine price for mint
        (uint256 price, bool whitelisted) = priceForMint(to, merkleProof, index);

        // rememmber the address did mint
        if (whitelisted){
            if (mintedAddresses.get(index)) revert AddressAlreadyMinted();
            mintedAddresses.set(index);
        }
      
        mintAtPrice(to, price);
    }


    /// @notice Set the root of the Merkle tree used to verify the whitelisted addresses
    function setWhiteListMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;

        emit MerkleRootSet(merkleRoot);
    }

 
    /// @notice allow the owner to withdraw the ETH from the contract
    /// @param amount The amount of ETH to withdraw. If 0 is passed witwithdraw the full balance.
    function withdraw(address to, uint256 amount) external onlyOwner {
        uint256 amountToWithdraw = amount == 0 ? address(this).balance : amount;

        (bool success, ) = payable(to).call{ value: amountToWithdraw }("");
        
        require(success, "Could not send ETH");
    }


    /// @notice allow the owner to enable and disable the public mint
    /// @param enableMint true if public mint has to be enabled, false otherwise
    function enablePublicMint(bool enableMint) external onlyOwner {
        isPublicMintEnabled = enableMint;
    }


    ////// Public functions //////

    /// @notice the price for the mint for the given address (can be discounted if a valid proof is provided)
    /// @dev the index is associated to the whitelisted address and included in the proof verification
    function priceForMint(address addr, bytes32[] calldata merkleProof, uint256 index) public view returns (uint256 price, bool whitelisted) {
        
        whitelisted = merkleProof.length > 0 && isWhitelistedAddress(addr, merkleProof, index);
        
        uint256 discount = whitelisted ? MINT_PRICE * DISCOUNT_PERCENTAGE / feeDenominator() : 0;
        
        price = MINT_PRICE - discount;
    }


    /// @notice returns true if the provided interfaceId is supported
    /// @param interfaceId An interface Id
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }


    /// @notice verifies that the address provided is included in the Merkle tree of the whitelistesd addresses
    /// @param addr The address to check
    /// @param merkleProof The Merkle proof for the address verify
    /// @param index The index for the address in whitelist if merkleProof is provided 
    function isWhitelistedAddress(address addr, bytes32[] calldata merkleProof, uint256 index) public view returns (bool) {
        // Verify the merkle proof.
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(addr, index))));

        return MerkleProof.verify(merkleProof, merkleRoot, leaf);
    }


    /// @notice intenal Mint function
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

        emit Minted(tokenId);
    }


    function feeDenominator() internal pure returns(uint96)  {
        return 10000;
    }

}
