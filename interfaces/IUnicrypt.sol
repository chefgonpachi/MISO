pragma solidity ^0.6.9;

interface IUnicrypt{
    event Received(address, uint);
    event onDeposit(address, uint256, uint256);
    event onWithdraw(address, uint256);

    function updateFee(uint256 numerator, uint256 denominator) external;
    function calculateFee(uint256 amount) external view returns (uint256);
    function depositTokenMultipleEpochs(address token, uint256[] memory amounts, uint256[] memory dates) external payable;


    function depositToken(address token, uint256 amount, uint256 unlock_date) external payable;
    function withdrawToken(address token, uint256 amount) external;
    function getWithdrawableBalance(address token, address user) external view returns (uint256);
    function getUserTokenInfo (address token, address user) external view returns (uint256, uint256, uint256);
    function getUserVestingAtIndex (address token, address user, uint index) external view returns (uint256, uint256);
    function getTokenReleaseLength (address token) external view returns (uint256);
    function getTokenReleaseAtIndex (address token, uint index) external view returns (uint256, uint256);
    function lockedTokensLength() external view returns (uint);
}