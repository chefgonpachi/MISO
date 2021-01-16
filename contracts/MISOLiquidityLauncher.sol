pragma solidity ^0.6.9;

import "./Utils/CloneFactory.sol";
import "../interfaces/IMisoLiquidity.sol";
import "./Access/MISOAccessControls.sol";


contract MISOLiquidityLauncher is CloneFactory {

    /// @notice Responsible for access rights to the contract
    MISOAccessControls public accessControls;

    bool private initialised;

    /// @notice Launchers created using factory
    address[] public launchers;

    ///@notice Template id  to track respective launcher template
    uint256 public launcherTemplateId;

    ///@notice Address for Wrapped Ether
    address public WETH;
    
    ///@notice mapping from template id to launcher template address
    mapping(uint256 => address) private launcherTemplates;

    ///@notice Tracks if a launcher in made by the factory
    mapping(address => bool) public isChildLiquidityLauncher;

    ///@notice event emitted when first intializing the liquidity launcher    
    event MisoInitLiquidityLauncher(address sender);
    
    ///@notice event emitted when launcher is created using template id
    event LiquidityLauncherCreated(address indexed owner, address indexed addr, address launcherTemplate);
   
    ///@notice event emitted when launcher template is added to factory
    event LiquidityTemplateAdded(address newLauncher, uint256 templateId);

    ///@notice event emitted when launcher template is removed
    event LiquidityTemplateRemoved(address launcher, uint256 templateId);

    constructor() public {
    }

     /**
     * @dev Single gateway to initialize the MISO Liquidity Launcher with proper address
     * @dev Can only be initialized once
    */
    function initMISOLiquidityLauncher(address _accessControls, address _WETH) external  {
        require(!initialised);
        initialised = true;
        accessControls = MISOAccessControls(_accessControls);
        WETH = _WETH;
        emit MisoInitLiquidityLauncher(msg.sender);
    }

    /**
     * @dev Creates a liquidity launcher coeresponding to _templateId   
    */
    function createLiquidityLauncher(
            uint256 _templateId

    ) external returns (address launcher) {
        require(launcherTemplates[_templateId] != address(0), "MISOLiquidityLauncher.createLiquidityLauncher: Template doesn't exist");

        launcher = createClone(launcherTemplates[_templateId]);
        isChildLiquidityLauncher[address(launcher)] = true;
        launchers.push(address(launcher));

        emit LiquidityLauncherCreated(msg.sender, address(launcher), launcherTemplates[_templateId]);
    }

    /**
     * @dev Function to add a launcher template to create through factory
     * @dev Should have operator access
     * @param _template Launcher template to create a launcher
    */
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

     /**
     * @dev Function to remove a launcher template from factory
     * @dev Should have operator access
     * @param _templateId Refers to template that is to be deleted
    */
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

    /// @dev Get the address of the launcher template
    function getLiquidityLauncherTemplate(uint256 templateId) public view returns (address launcherTemplate) {
        return launcherTemplates[templateId];
    }
    
    /// @dev Get the total number of launchers in the contract
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
