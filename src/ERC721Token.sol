// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ERC721Token is ERC721("ERC721TOKEN", "ERC721") {
    uint256 counter;

    function mint(address _addr) external {
        _mint(_addr, counter++);
    }
}
