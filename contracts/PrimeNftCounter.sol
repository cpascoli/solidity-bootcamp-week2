// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;


import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Enumerable } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

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
    /// are owned by that address with tokenIDs that are prime numbers.
    function countPrimes(address owner) external view returns (uint256 primes) {

        uint256 balance = nftToken.balanceOf(owner);
        uint256 i;

        for (; i < balance;) {

            uint256 n = nftToken.tokenOfOwnerByIndex(owner, i);

            // If n is divisible by 2 or 3 it's not prime.
            // even numbers can be efficiently determinred checking their last bit: n & uint256(1) == 0
            bool notPrimes = (n == 1) || (n > 3 && ( (n & uint256(1)) == 0 || n % 3 == 0 ));

            if (!notPrimes) {
                // For every number a, between 5 and sqrt(n),  
                // check if n is divisible by a or a + 2, skipping numbers divisible by 3.
               
                bool notPrimeFound = false;
                uint256 j=5;
                uint256 max = Math.sqrt(balance);

                for (; j <= max;) {
                    if (n != j && n % j == 0) {
                        notPrimeFound = true;
                        break;
                    }

                    unchecked {
                        // skips multiples of 2 and 3
                        j += (j+2 % 3 == 0) ? 4 : 2;
                    }
                }
                if (!notPrimeFound) {
                    unchecked {
                        ++primes;
                    }
                }
            }

            unchecked {
                ++i;
            }
        }
    }

}