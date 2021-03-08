pragma solidity 0.6.12;

// GP Make a whitelist but instead of adding and removing, set an uint amount for a address
// mapping(address => uint256) public points;

// This amount can be added or removed by an operator
// There is a total points preserved
// Can update an array of points
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./MISOAccessControls.sol";
import "../../interfaces/IPointList.sol";


contract PointList is IPointList, MISOAccessControls {
    using SafeMath for uint;

    mapping(address => uint256) public points;

    bool private initialised;
    uint256 public totalPoints;

    event PointsUpdated(address indexed account, uint256 oldPoints, uint256 newPoints);

    constructor() public {
    }

    function initPointList(address _admin) public override {
        require(!initialised, "Already initialised");
        initAccessControls(_admin);
        initialised = true;
    }

    function isInList(address account) public view override returns (bool) {
        return points[account] > 0 ;
    }

    function hasPoints(address account, uint256 amount) public view override returns (bool) {
        return points[account] >= amount ;
    }

    function setPoints(
        address[] memory accounts,
        uint256[] memory amounts
    ) 
        external override
    {  
        require(
            hasOperatorRole(msg.sender),
            "PointList.setPoints: Sender must be operator"
        );
        require(accounts.length != 0);
        require(accounts.length == amounts.length);
        for (uint i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            uint256 amount = amounts[i];
            uint256 previousPoints = points[account];

            if (amount != previousPoints) {
                points[account] = amount;
                totalPoints = totalPoints.add(amount).sub(previousPoints);
                emit PointsUpdated(account, previousPoints, amount);
            }
        }
    }

}