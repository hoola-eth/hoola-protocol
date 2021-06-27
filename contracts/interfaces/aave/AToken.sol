// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface AToken{
    
    function balanceOf(address user) external view returns (uint);
    
    function scaledBalanceOf(address user) external view returns (uint256);
    
    function getScaledUserBalanceAndSupply(address user)external view returns (uint256, uint256);
}
