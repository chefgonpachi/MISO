pragma solidity ^0.6.9;


import "../Utils/Owned.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../Utils/CloneFactory.sol";
import "../../interfaces/IERC20.sol";
import "../../interfaces/IOwned.sol";
import "../../interfaces/IWhiteList.sol";


// ----------------------------------------------------------------------------
// MISO WhiteList Factory
//
//
// Appropriated from BokkyPooBah's Fixed Supply Token 👊 Factory
//
// ----------------------------------------------------------------------------

contract WhiteListFactory is  Owned, CloneFactory {
    using SafeMath for uint;

    address public whiteListTemplate;

    address public newAddress;
    uint256 public minimumFee = 0.1 ether;
    mapping(address => bool) public isChild;
    address[] public children;


    event WhiteListDeployed(address indexed operator, address indexed addr, address whiteList, address owner);
    event FactoryDeprecated(address _newAddress);
    event MinimumFeeUpdated(uint oldFee, uint newFee);
    
    function initWhiteListFactory( address _whiteListTemplate, uint256 _minimumFee) public  {
        _initOwned(msg.sender);
        whiteListTemplate = _whiteListTemplate;
        minimumFee = _minimumFee;
    }

    function numberOfChildren() public view returns (uint) {
        return children.length;
    }
    function deprecateFactory(address _newAddress) public {
        require(isOwner());
        require(newAddress == address(0));
        emit FactoryDeprecated(_newAddress);
        newAddress = _newAddress;
    }
    function setMinimumFee(uint256 _minimumFee) public {
        require(isOwner());
        emit MinimumFeeUpdated(minimumFee, _minimumFee);
        minimumFee = _minimumFee;
    }

    function deployWhiteList(
        address _listOwner,
        address[] memory _whiteListed
    )
        public payable returns (address whiteList)
    {
        require(msg.value >= minimumFee);
        whiteList = createClone(whiteListTemplate);
        IWhiteList(whiteList).initWhiteList(address(this));
        IWhiteList(whiteList).addWhiteList(_whiteListed);
        IOwned(whiteList).transferOwnership(_listOwner);
        isChild[address(whiteList)] = true;
        children.push(address(whiteList));
        emit WhiteListDeployed(msg.sender, address(whiteList), whiteListTemplate, _listOwner);
        if (msg.value > 0) {
            payable(owner()).transfer(msg.value);
        }
    }

    // footer functions
    function transferAnyERC20Token(address tokenAddress, uint256 tokens) public returns (bool success) {
        require(isOwner());
        return IERC20(tokenAddress).transfer(owner(), tokens);
    }
    receive () external payable {
        revert();
    }
}