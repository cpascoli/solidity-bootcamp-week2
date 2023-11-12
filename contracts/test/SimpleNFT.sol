// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract SimpleNFT is ERC721 {

    uint256 public tokenId;

    constructor() ERC721("Simple NFT Token", "ST") { }

    function mint(address recipient) external payable {
        super._safeMint(recipient, ++tokenId);
    }
}
