// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import './token/ERC20/ERC20.sol';

// 常态轮
contract CACPToken is ERC20 {
   constructor(address _publisher, uint _miningPoolAmount) public ERC20("CACPToken", "CACP") {
     _mint(msg.sender, _miningPoolAmount / 2);
     _mint(_publisher, _miningPoolAmount / 2);
   }
}
