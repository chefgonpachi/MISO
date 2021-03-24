pragma solidity 0.6.12;


import "../Utils/Owned.sol";
import "../OpenZeppelin/math/SafeMath.sol";
import "../Utils/CloneFactory.sol";
import "../../interfaces/IERC20.sol";
import "../../interfaces/IOwned.sol";
import "../../interfaces/IPointList.sol";
import "../Utils/SafeTransfer.sol";
import "./MISOAccessControls.sol";


// ----------------------------------------------------------------------------
// MISO PointList Factory
//
// Appropriated from BokkyPooBahs Fixed Supply Token Factory
//
// ----------------------------------------------------------------------------

contract PointListFactory is  CloneFactory, SafeTransfer {
    using SafeMath for uint;

    /// @notice Responsible for access rights to the contract
    MISOAccessControls public accessControls;
    /// @notice Whether market has been initialized or not.
    bool private initialised;

    address public pointListTemplate;
    address public newAddress;
    uint256 public minimumFee;
    mapping(address => bool) public isChild;
    address[] public lists;

    /// @notice Any MISO dividends collected are sent here.
    address payable public misoDiv;

    event PointListDeployed(address indexed operator, address indexed addr, address pointList, address owner);
    event FactoryDeprecated(address _newAddress);
    event MinimumFeeUpdated(uint oldFee, uint newFee);
    event MisoInitPointListFactory();

    function initPointListFactory(address _accessControls, address _pointListTemplate, uint256 _minimumFee) public  {
        require(!initialised);
        accessControls = MISOAccessControls(_accessControls);
        pointListTemplate = _pointListTemplate;
        minimumFee = _minimumFee;
        initialised = true;
        emit MisoInitPointListFactory();
    }

    function numberOfChildren() public view returns (uint) {
        return lists.length;
    }

    function deprecateFactory(address _newAddress) public {
        require(
            accessControls.hasAdminRole(msg.sender),
            "PointListFactory: Sender must be admin"
        );
        require(newAddress == address(0));
        emit FactoryDeprecated(_newAddress);
        newAddress = _newAddress;
    }
    function setMinimumFee(uint256 _minimumFee) public {
        require(
            accessControls.hasAdminRole(msg.sender),
            "PointListFactory: Sender must be admin"
        );
        emit MinimumFeeUpdated(minimumFee, _minimumFee);
        minimumFee = _minimumFee;
    }

    /**
     * @notice Sets dividend address.
     * @param _divaddr Dividend address.
     */
    function setDividends(address payable _divaddr) public  {
        require(
            accessControls.hasAdminRole(msg.sender),
            "MISOTokenFactory: Sender must be opadminerator"
        );
        misoDiv = _divaddr;
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
            MISOAccessControls(pointList).addOperatorRole(address(this));
            IPointList(pointList).setPoints(_accounts, _amounts);
            MISOAccessControls(pointList).addAdminRole(_listOwner);
            MISOAccessControls(pointList).removeAdminRole(address(this));

        } else {
            IPointList(pointList).initPointList(_listOwner);          
        }
        isChild[address(pointList)] = true;
        lists.push(address(pointList));
        emit PointListDeployed(msg.sender, address(pointList), pointListTemplate, _listOwner);
        if (msg.value > 0) {
            misoDiv.transfer(msg.value);
        }
    }

    // footer functions
    function transferAnyERC20Token(address tokenAddress, uint256 tokens) public returns (bool success) {
        require(
            accessControls.hasAdminRole(msg.sender),
            "PointListFactory: Sender must be operator"
        );
        _safeTransfer(tokenAddress, misoDiv, tokens);
        return true;
    }
    
    receive () external payable {
        revert();
    }
}