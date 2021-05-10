pragma solidity 0.6.12;

contract Receiver {

    fallback() external payable {}
    function sendTo() external payable returns (bool) { return true; }
    function transfer(uint256 amount) external payable returns (bool) { return true; }
	
}
