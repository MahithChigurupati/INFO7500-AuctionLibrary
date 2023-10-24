// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Token is ERC20("ERC20TOKEN", "ERC20") {
    function mint(address _addr, uint256 _amount) external {
        _mint(_addr, _amount);
    }
}
