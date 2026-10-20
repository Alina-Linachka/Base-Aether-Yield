// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;
interface IAetherYieldPool {
    function stakeAssets(uint256 amount) external;
    function harvestYield() external returns (uint256);
    function withdrawPrincipal() external;
}
