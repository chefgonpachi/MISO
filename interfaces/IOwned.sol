pragma solidity ^0.6.9;

// ----------------------------------------------------------------------------
// White List interface
// ----------------------------------------------------------------------------

interface IOwned {
    function owner() external view returns (address) ;
    function isOwner() external view returns (bool) ;
    function transferOwnership(address _newOwner) external;
}
