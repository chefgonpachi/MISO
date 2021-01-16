pragma solidity ^0.6.9;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./Access/MISOAccessControls.sol";
import "../interfaces/IERC20.sol";

// DO NOT USE YET
// GP Move tokens based on points/ weightings to a list of destinations 
// Basically dividends without transfers
// Keeps track of token points for each address
// About to withdraw tokens for a user 
// keeps track of tokens for multiple withdraw/deposits
// Updates token balances with a balanceOf(this) so tokens can be sent here without contract calls
// Have the optional ablitiy to let public withdraws for some addresses (eg: to vault, trustlessly)

contract MISOSplitter {

    using SafeMath for uint256;


    bool private initialised;
    MISOAccessControls public accessControls;

    mapping(address => uint256) public points;
    uint256 public totalPoints;

    event MisoInitSplitter(address sender);
    event SetPoints(address indexed account, uint256 oldPoints, uint256 newPoints);

    constructor() public {
    }

    function initMISOSplitter(address _accessControls) external {
        require(!initialised);
        accessControls = MISOAccessControls(_accessControls);
        
        initialised = true;
        emit MisoInitSplitter(msg.sender);
    }

    function setPoints(address _recipient, uint256 _points) external {
        uint256 currentPoints = points[_recipient];
        points[_recipient] = _points;
        totalPoints = totalPoints.sub(currentPoints).add(_points);
        emit SetPoints(_recipient, currentPoints, _points);
    }

}