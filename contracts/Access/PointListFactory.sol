pragma solidity 0.6.12;


import "../Utils/Owned.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../Utils/CloneFactory.sol";
import "../../interfaces/IERC20.sol";
import "../../interfaces/IOwned.sol";
import "../../interfaces/IPointList.sol";
import "../Utils/SafeTransfer.sol";


// ----------------------------------------------------------------------------
// MISO PointList Factory
//
// Appropriated from BokkyPooBahs Fixed Supply Token 👊 Factory
//
// ----------------------------------------------------------------------------

contract PointListFactory is  Owned, CloneFactory, SafeTransfer {
    using SafeMath for uint;

    address public pointListTemplate;

    address public newAddress;
    uint256 public minimumFee;
    mapping(address => bool) public isChild;
    address[] public lists;


    event PointListDeployed(address indexed operator, address indexed addr, address pointList, address owner);
    event FactoryDeprecated(address _newAddress);
    event MinimumFeeUpdated(uint oldFee, uint newFee);
    
    function initPointListFactory( address _pointListTemplate, uint256 _minimumFee) public  {
        _initOwned(msg.sender);
        pointListTemplate = _pointListTemplate;
        minimumFee = _minimumFee;
    }

    function numberOfChildren() public view returns (uint) {
        return lists.length;
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

    function deployPointList(
        address _listOwner,
        address[] memory _accounts,
        uint256[] memory _amounts

    )
        public payable returns (address pointList)
    {
        require(msg.value >= minimumFee);
        pointList = createClone(pointListTemplate);
        if (_accounts.length > 0) {
            IPointList(pointList).initPointList(address(this));
            IPointList(pointList).setPoints(_accounts, _amounts);
            IOwned(pointList).transferOwnership(_listOwner);
        } else {
            IPointList(pointList).initPointList(_listOwner);          
        }
        isChild[address(pointList)] = true;
        lists.push(address(pointList));
        emit PointListDeployed(msg.sender, address(pointList), pointListTemplate, _listOwner);
        if (msg.value > 0) {
            payable(owner()).transfer(msg.value);
        }
    }

    // footer functions
    function transferAnyERC20Token(address tokenAddress, uint256 tokens) public returns (bool success) {
        require(isOwner());
        _safeTransfer(tokenAddress, owner(), tokens);
        return true;
    }
    
    receive () external payable {
        revert();
    }
}