pragma solidity ^0.6.9;

interface IMisoLiquidity {
    function initPoolLiquidity(
            address accessControls,
            address token,
            address WETH,
            address factory,
            address owner,
            address wallet,
            uint256 duration,
            uint256 launchwindow,
            uint256 deadline,
            uint256 locktime
    )
        external;
}