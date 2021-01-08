pragma solidity ^0.6.9;

// GP Make a whitelist but instead of adding and removing, set an uint amount for a address
// mapping(address => uint256) public points;

// This amount can be added or removed by an operator
// There is a total points preserved
// Can update an array of points
import "@openzeppelin/contracts/math/SafeMath.sol";


import "./MISOAccessControls.sol";


contract PointList  {
    using SafeMath for uint;

    mapping(address => uint256) public points;
    MISOAccessControls public accessControls;
    bool private initialised;
    uint256 public totalPoints;

    event PointsUpdated(address indexed account, uint256 oldPoints, uint256 newPoints);

    constructor() public {
    }

    function initPointList(address _accessControls) public  {
        require(!initialised, "Already initialised");
        accessControls = MISOAccessControls(_accessControls);
        initialised = true;
    }

    function isInPointList(address account) public view  returns (bool) {
        return points[account] > 0 ;
    }

    function setPoints(
        address[] memory accounts,
        uint256[] memory amounts
    ) 
        external 
    {  
        require(
            accessControls.hasOperatorRole(msg.sender),
            "PointList.setPoints: Sender must be operator"
        );
        require(accounts.length != 0);
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