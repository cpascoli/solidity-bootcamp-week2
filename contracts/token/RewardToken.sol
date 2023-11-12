// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";


interface IRewardToken is IERC20 {

    function mint(address to, uint256 amount) external;
    
}

/**
 *  @title A basic ERC20 token
 *  @author Carlo Pascoli
 */
contract RewardToken is ERC20, Ownable, IRewardToken {
    
    constructor() ERC20("Reward Token", "RT") { }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

}
