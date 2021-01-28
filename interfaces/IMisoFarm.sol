pragma solidity ^0.6.9;

interface IMisoFarm {
    function initFarm(
        address rewards,
        uint256 rewardsPerBlock,
        uint256 startBlock,
        address devAddr,
        address accessControls
    ) external;

    function initFarm(
        bytes calldata data
    ) external;

}