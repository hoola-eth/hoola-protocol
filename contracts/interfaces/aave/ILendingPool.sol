// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import './ILendingPoolAddressesProvider.sol';
import './DataTypes.sol';

interface ILendingPool {

 function deposit(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
  ) external;


  function withdraw(
    address asset,
    uint256 amount,
    address to
  ) external returns (uint256);


  function borrow(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    uint16 referralCode,
    address onBehalfOf
  ) external;


  function repay(
    address asset,
    uint256 amount,
    uint256 rateMode,
    address onBehalfOf
  ) external returns (uint256);


  function swapBorrowRateMode(address asset, uint256 rateMode) external;

  function getReserveNormalizedIncome(address asset) external view returns(uint);

}