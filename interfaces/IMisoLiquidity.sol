pragma solidity 0.6.12;

interface IMisoLiquidity {
    function initMisoLiquidity(
        address _token,
        address _WETH,
        address _factory,
        address _owner,
        address _wallet,
        uint256 _expiresIn,
        uint256 _launchwindow,
        uint256 _locktime
    ) external;
}