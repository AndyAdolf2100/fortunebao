// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.22 <0.9.0;
import {SafeMath} from "./utils/math/SafeMath.sol";
contract FortunbaoConfig {
  using SafeMath for uint;
  uint constant internal TO_WEI = 1000000000000000000;   // 1e18

  // 转换成Wei为单位
  function _toWei(uint _number) internal view returns (uint) {
    return _number.mul(TO_WEI);
  }


}
