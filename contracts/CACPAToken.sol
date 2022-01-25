// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import './token/ERC20/ERC20.sol';

// 第一期
contract CACPAToken is ERC20 {
   constructor(address _publisher, uint _miningPoolAmount) public ERC20("CACPAToken", "CACPA") {
     _mint(_publisher, _miningPoolAmount);
   }
}
