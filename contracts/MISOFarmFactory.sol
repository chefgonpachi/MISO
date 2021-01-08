pragma solidity ^0.6.9;

import "./Utils/CloneFactory.sol";
import "../interfaces/IMisoFarm.sol";
import "./Access/MISOAccessControls.sol";


contract MISOFarmFactory is CloneFactory {

    MISOAccessControls public accessControls;

    bool private initialised;
    address[] public farms;
    uint256 public farmTemplateId;
    
    mapping(uint256 => address) private farmTemplates;
    mapping(address => bool) public isChildFarm;


    // GP: Add more data to events
    event MisoInitFarmFactory(address sender);
    event FarmCreated(address indexed owner, address indexed addr, address token, uint256 startBlock, address farmTemplate);
    event FarmTemplateAdded(address newFarm, uint256 templateId);
    event FarmTemplateRemoved(address farm, uint256 templateId);

    constructor() public {
    }

    function initMISOFarmFactory(address _accessControls) external  {
        require(!initialised);
        initialised = true;
        accessControls = MISOAccessControls(_accessControls);
        emit MisoInitFarmFactory(msg.sender);
    }

    function createFarm(
            address _rewards,
            uint256 _rewardsPerBlock,
            uint256 _startBlock,
            address _devaddr,
            address _accessControls,
            uint256 _templateId
    ) external returns (address farm) {
        require(farmTemplates[_templateId] != address(0));
        farm = createClone(farmTemplates[_templateId]);
        isChildFarm[address(farm)] = true;
        farms.push(address(farm));
        IMisoFarm(farm).initFarm(_rewards, _rewardsPerBlock, _startBlock, _devaddr, _accessControls);
        emit FarmCreated(msg.sender, address(farm), _rewards, _startBlock, farmTemplates[_templateId]);
    }

    function addFarmTemplate(address _template) external {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "MISOFarmFactory.addFarmTemplate: Sender must be operator"
        );
        // GP: Check exisiting / duplicates
        farmTemplateId++;
        farmTemplates[farmTemplateId] = _template;
        emit FarmTemplateAdded(_template, farmTemplateId);
    }

    function removeFarmTemplate(uint256 _templateId) external {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "MISOFarmFactory.removeFarmTemplate: Sender must be operator"
        );
        require(farmTemplates[_templateId] != address(0));
        address template = farmTemplates[_templateId];
        farmTemplates[_templateId] = address(0);
        emit FarmTemplateRemoved(template, _templateId);
    }

    // getter functions
    function getFarmTemplate(uint256 templateId) public view returns (address farmTemplate) {
        return farmTemplates[templateId];
    }

    function numberOfFarms() public view returns (uint256) {
        return farms.length;
    }

    // GP: Replace this with a mapping to avoid gas limits
    function getTemplateId(address _farmTemplate) public view returns (uint256) {
        for(uint i = 1; i <= farmTemplateId; i++) {
            if(farmTemplates[i] == _farmTemplate) {
                return i;
            }
        }
    }

}
