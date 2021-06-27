// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INFTVault {

 function _borrow(uint256 amount, address asset) external returns(uint256);   
 
 function _repay() external returns(uint256);

 function getLoanFees(uint256 amount, address user) external view returns(uint256);

 function _getNFT(address _to) external payable;

 
}