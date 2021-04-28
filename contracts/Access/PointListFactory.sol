pragma solidity 0.6.12;

import "../Utils/Owned.sol";
import "../OpenZeppelin/math/SafeMath.sol";
import "../Utils/CloneFactory.sol";
import "../../interfaces/IERC20.sol";
import "../../interfaces/IPointList.sol";
import "../Utils/SafeTransfer.sol";
import "./MISOAccessControls.sol";


// ----------------------------------------------------------------------------
// MISO PointList Factory
//
// Appropriated from BokkyPooBahs Fixed Supply Token Factory
// ----------------------------------------------------------------------------

contract PointListFactory is CloneFactory, SafeTransfer {
    using SafeMath for uint;

    /// @notice Responsible for access rights to the contract.
    MISOAccessControls public accessControls;

    /// @notice Whether market has been initialized or not.
    bool private initialised;

    /// @notice Address of the point list template.
    address public pointListTemplate;

    /// @notice New point list address.
    address public newAddress;

    /// @notice Minimum fee number.
    uint256 public minimumFee;

    /// @notice Tracks if list is made by the factory.
    mapping(address => bool) public isChild;

    /// @notice An array of list addresses.
    address[] public lists;

    /// @notice Any MISO dividends collected are sent here.
    address payable public misoDiv;

    /// @notice Event emitted when point list is deployed.
    event PointListDeployed(address indexed operator, address indexed addr, address pointList, address owner);

    /// @notice Event emitted when factory is deprecated.
    event FactoryDeprecated(address newAddress);

    /// @notice Event emitted when minimum fee is updated.
    event MinimumFeeUpdated(uint oldFee, uint newFee);

    /// @notice Event emitted when point list factory is initialised.
    event MisoInitPointListFactory();

    /**
     * @notice Initializes point list factory variables.
     * @param _accessControls Access control contract address.
     * @param _pointListTemplate Point list template address.
     * @param _minimumFee Minimum fee number.
     */
    function initPointListFactory(address _accessControls, address _pointListTemplate, uint256 _minimumFee) public  {
        require(!initialised);
        accessControls = MISOAccessControls(_accessControls);
        pointListTemplate = _pointListTemplate;
        minimumFee = _minimumFee;
        initialised = true;
        emit MisoInitPointListFactory();
    }

    /**
     * @notice Gets the number of point lists created by factory.
     * @return uint Number of point lists.
     */
    function numberOfChildren() public view returns (uint) {
        return lists.length;
    }

    /**
     * @notice Deprecates factory.
     * @param _newAddress Blank address.
     */
    function deprecateFactory(address _newAddress) public {
        require(accessControls.hasAdminRole(msg.sender), "PointListFactory: Sender must be admin");
        require(newAddress == address(0));
        emit FactoryDeprecated(_newAddress);
        newAddress = _newAddress;
    }

    /**
     * @notice Sets minimum fee.
     * @param _minimumFee Minimum fee number.
     */
    function setMinimumFee(uint256 _minimumFee) public {
        require(accessControls.hasAdminRole(msg.sender), "PointListFactory: Sender must be admin");
        emit MinimumFeeUpdated(minimumFee, _minimumFee);
        minimumFee = _minimumFee;
    }

    /**
     * @notice Sets dividend address.
     * @param _divaddr Dividend address.
     */
    function setDividends(address payable _divaddr) public  {
        require(accessControls.hasAdminRole(msg.sender), "MISOTokenFactory: Sender must be Admin");
        misoDiv = _divaddr;
    }

    /**
     * @notice Deploys new point list.
     * @param _listOwner List owner address.
     * @param _accounts An array of account addresses.
     * @param _amounts An array of corresponding point amounts.
     * @return pointList Point list address.
     */
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

    /**
     * @notice Funtion for transfering any ERC20 token.
     * @param _tokenAddress Address to send from.
     * @param _tokens Number of tokens.
     * @return success True.
     */
    function transferAnyERC20Token(address _tokenAddress, uint256 _tokens) public returns (bool success) {
        require(accessControls.hasAdminRole(msg.sender), "PointListFactory: Sender must be operator");
        _safeTransfer(_tokenAddress, misoDiv, _tokens);
        return true;
    }

    receive () external payable {
        revert();
    }
}
