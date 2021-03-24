pragma solidity 0.6.12;

interface IMisoMarket {

    function initMarket(
        bytes calldata data
    ) external;

    function getMarkets() external view returns(address[] memory);

    function getMarketTemplateId(address _auction) external view returns(uint64);
}
