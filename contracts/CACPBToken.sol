// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import './token/ERC20/ERC20.sol';

// 第二期
contract CACPBToken is ERC20 {
   constructor(address _publisher, uint _miningPoolAmount) public ERC20("CACPBToken", "CACPB") {
     _mint(_publisher, _miningPoolAmount);
   }
}
