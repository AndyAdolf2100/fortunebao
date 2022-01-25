// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import './token/ERC20/ERC20.sol';

// 模拟cac
contract CacToken is ERC20 {
   constructor() public ERC20("CACWorld", "CAC") {
     _mint(msg.sender, 20000000000000000000000000);
   }
}
