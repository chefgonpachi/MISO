pragma solidity 0.6.12;

interface IMisoAuction {


    function initAuction(
        address _funder,
        address _token,
        uint256 _tokenSupply,
        uint256 _startDate,
        uint256 _endDate,
        address _paymentCurrency,
        uint256 _startPrice,
        uint256 _minimumPrice,
        address _operator,
        address _pointList,
        address payable _wallet
    ) external;

    function finalize() external;
}
