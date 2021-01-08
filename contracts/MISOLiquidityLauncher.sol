pragma solidity ^0.6.9;

import "./Utils/CloneFactory.sol";
import "../interfaces/IMisoLiquidity.sol";
import "./Access/MISOAccessControls.sol";


contract MISOLiquidityLauncher is CloneFactory {

    MISOAccessControls public accessControls;

    bool private initialised;
    address[] public launchers;
    uint256 public launcherTemplateId;
    
    mapping(uint256 => address) private launcherTemplates;
    mapping(address => bool) public isChildLiquidityLauncher;


    // GP: Add more data to events for The Graph
    event MisoInitLiquidityLauncher(address sender);
    event LiquidityLauncherCreated(address indexed owner, address indexed addr,  address launcherTemplate);
    event LiquidityTemplateAdded(address newLauncher, uint256 templateId);
    event LiquidityTemplateRemoved(address launcher, uint256 templateId);

    constructor() public {
    }

    function initMISOLiquidityLauncher(address _accessControls) external  {
        require(!initialised);
        initialised = true;
        accessControls = MISOAccessControls(_accessControls);
        emit MisoInitLiquidityLauncher(msg.sender);
    }

    function createLiquidityLauncher(
            uint256 _templateId
    ) external returns (address launcher) {
        require(launcherTemplates[_templateId] != address(0));
        launcher = createClone(launcherTemplates[_templateId]);
        isChildLiquidityLauncher[address(launcher)] = true;
        launchers.push(address(launcher));
        emit LiquidityLauncherCreated(msg.sender, address(launcher), launcherTemplates[_templateId]);
    }

    function addLiquidityLauncherTemplate(address _template) external {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "MISOLiquidityLauncher.addLiquidityLauncherTemplate: Sender must be operator"
        );
        // GP: Check exisiting / duplicates
        launcherTemplateId++;
        launcherTemplates[launcherTemplateId] = _template;
        emit LiquidityTemplateAdded(_template, launcherTemplateId);
    }

    function removeLiquidityLauncherTemplate(uint256 _templateId) external {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "MISOLiquidityLauncher.removeLiquidityLauncherTemplate: Sender must be operator"
        );
        require(launcherTemplates[_templateId] != address(0));
        address template = launcherTemplates[_templateId];
        launcherTemplates[_templateId] = address(0);
        emit LiquidityTemplateRemoved(template, _templateId);
    }

    // getter functions
    function getLiquidityLauncherTemplate(uint256 templateId) public view returns (address launcherTemplate) {
        return launcherTemplates[templateId];
    }

    function numberOfLiquidityLauncherContracts() public view returns (uint256) {
        return launchers.length;
    }

    // GP: Replace this with a mapping to avoid gas limits
    function getTemplateId(address _launcherTemplate) public view returns (uint256) {
        for(uint i = 1; i <= launcherTemplateId; i++) {
            if(launcherTemplates[i] == _launcherTemplate) {
                return i;
            }
        }
    }

}
