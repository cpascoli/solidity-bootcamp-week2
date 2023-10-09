// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;


import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Enumerable } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import "hardhat/console.sol";


/**
 *  @title Prime NFT counter.
 *  @author Carlo Pascoli
 *  @notice A smart contract that has a function which accepts an address and returns
 *          how many NFTs are owned by that address which have tokenIDs that are prime numbers.
 *
 */
contract PrimeNftCounter {

    IERC721Enumerable public nftToken;

    constructor(address nftTokenAddress ) {
        nftToken = IERC721Enumerable(nftTokenAddress);
    }


    /// @notice function which accepts an address and returns how many NFTs
    ///         are owned by that address which have tokenIDs that are prime numbers.
    function countPrimes(address owner) external view returns (uint256 primes) {

        uint256 balance = nftToken.balanceOf(owner);
       
        uint notPrimes;
        uint256 i;

        for (; i < balance;) {

            uint256 n = nftToken.tokenOfOwnerByIndex(owner, i);

            // Check if the number n is divisible by 2 or 3. If so, it's not prime.
            if (n == 1 || n > 3 && (n % 2 == 0 || n % 3 == 0)) { 
                ++notPrimes;
            } else {
                // For every number a between 5 and sqrt(n) check 
                // if n is divisible by a or a + 2 skipping number divisible by 3
                uint256 j=5;

                for (; j <= Math.sqrt(balance);) {
                    if (n % j == 0) {
                        unchecked {
                            ++notPrimes;
                        }
                        break;
                    }

                    unchecked {
                        j += (j+2 % 3 == 0) ? 4 : 2;
                    }
                }
            }

            unchecked {
                ++i;
            }
        }

        unchecked {
            primes = balance - notPrimes;
        }
    }


}