//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IArrakisFactoryV1 {
    function deployVault(
        address token0,
        address token1,
        uint24 uniFee,
        address manager,
        uint16 managerFee,
        int24 lowerTick,
        int24 upperTick
    ) external returns (address pool);

    function getTokenName(
        address token0,
        address token1
    ) external view returns (string memory);

    function upgradePools(address[] memory pools) external;

    function upgradePoolsAndCall(
        address[] memory pools,
        bytes[] calldata datas
    ) external;

    function makePoolsImmutable(address[] memory pools) external;

    function isPoolImmutable(address pool) external view returns (bool);

    function getGelatoPools() external view returns (address[] memory);

    function getDeployers() external view returns (address[] memory);

    function getPools(
        address deployer
    ) external view returns (address[] memory);

    function numPools() external view returns (uint256 result);

    function numDeployers() external view returns (uint256);

    function numPools(address deployer) external view returns (uint256);

    function getProxyAdmin(address pool) external view returns (address);
}
