pragma solidity 0.6.12;

//----------------------------------------------------------------------------------
//    I n s t a n t
//
//        .:mmm.         .:mmm:.       .ii.  .:SSSSSSSSSSSSS.     .oOOOOOOOOOOOo.  
//      .mMM'':Mm.     .:MM'':Mm:.     .II:  :SSs..........     .oOO'''''''''''OOo.
//    .:Mm'   ':Mm.   .:Mm'   'MM:.    .II:  'sSSSSSSSSSSSSS:.  :OO.           .OO:
//  .'mMm'     ':MM:.:MMm'     ':MM:.  .II:  .:...........:SS.  'OOo:.........:oOO'
//  'mMm'        ':MMmm'         'mMm:  II:  'sSSSSSSSSSSSSS'     'oOOOOOOOOOOOO'  
//
//----------------------------------------------------------------------------------

import "./Utils/CloneFactory.sol";
import "../interfaces/IMisoLiquidity.sol";
import "./Access/MISOAccessControls.sol";

contract MISOLiquidityLauncher is CloneFactory {

    /// @notice Responsible for access rights to the contract.
    MISOAccessControls public accessControls;

    /// @notice Whether liquidity launcher has been initialized or not.
    bool private initialised;

    /// @notice All the launchers created using factory.
    address[] public launchers;

    /// @notice Template id to track respective launcher template.
    uint256 public launcherTemplateId;

    /// @notice Address for Wrapped Ether.
    address public WETH;

    /// @notice Mapping from template id to launcher template address.
    mapping(uint256 => address) private launcherTemplates;

    /// @notice mapping from liquidity template address to liquidity template id
    mapping(address => uint256) private liquidityTemplateToId;

    /// @notice Tracks if a launcher is made by the factory.
    mapping(address => bool) public isChildLiquidityLauncher;

    /// @notice Event emitted when first intializing the liquidity launcher.
    event MisoInitLiquidityLauncher(address sender);

    /// @notice Event emitted when launcher is created using template id.
    event LiquidityLauncherCreated(address indexed owner, address indexed addr, address launcherTemplate);

    /// @notice Event emitted when launcher template is added to factory.
    event LiquidityTemplateAdded(address newLauncher, uint256 templateId);

    /// @notice Event emitted when launcher template is removed.
    event LiquidityTemplateRemoved(address launcher, uint256 templateId);

    constructor() public {
    }

    /**
     * @notice Single gateway to initialize the MISO Liquidity Launcher with proper address.
     * @dev Can only be initialized once.
     * @param _accessControls Sets address to get the access controls from.
     * @param _WETH Sets the WETH address.
     */
    function initMISOLiquidityLauncher(address _accessControls, address _WETH) external {
        require(!initialised);
        initialised = true;
        accessControls = MISOAccessControls(_accessControls);
        require(_WETH != address(0), "MISOLiquidityLauncher.initMISOLiquidityLauncher: WETH cannot be set to zero");
 
        WETH = _WETH;
        emit MisoInitLiquidityLauncher(msg.sender);
    }

    /**
     * @notice Creates a liquidity launcher corresponding to _templateId.
     * @param _templateId Template id of the liquidity launcher to create.
     * @return launcher Liquidity launcher address.
     */
    function createLiquidityLauncher(uint256 _templateId) external returns (address launcher) {
        require(launcherTemplates[_templateId] != address(0), "MISOLiquidityLauncher.createLiquidityLauncher: Template does not exist");
        launcher = createClone(launcherTemplates[_templateId]);
        isChildLiquidityLauncher[address(launcher)] = true;
        launchers.push(address(launcher));
        emit LiquidityLauncherCreated(msg.sender, address(launcher), launcherTemplates[_templateId]);
    }

    /**
     * @notice Function to add a launcher template to create through factory.
     * @dev Should have operator access
     * @param _template Launcher template address.
    */
    function addLiquidityLauncherTemplate(address _template) external {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "MISOLiquidityLauncher: Sender must be operator"
        );
        require(liquidityTemplateToId[_template] == 0);
        // GP: Check exisiting / duplicates
        launcherTemplateId++;
        launcherTemplates[launcherTemplateId] = _template;
        liquidityTemplateToId[_template] = launcherTemplateId;
        
        emit LiquidityTemplateAdded(_template, launcherTemplateId);
    }

    /**
     * @dev Function to remove a launcher template from factory.
     * @dev Should have operator access.
     * @param _templateId Id of the template to be deleted.
     */
    function removeLiquidityLauncherTemplate(uint256 _templateId) external {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "MISOLiquidityLauncher: Sender must be operator"
        );
        require(launcherTemplates[_templateId] != address(0));
        address _template = launcherTemplates[_templateId];
        launcherTemplates[_templateId] = address(0);
        delete liquidityTemplateToId[_template];
        emit LiquidityTemplateRemoved(_template, _templateId);
    }

    /**
     * @notice Get the address based on launcher template ID.
     * @param _templateId Launcher template ID.
     * @return Address of the required template ID.
     */
    function getLiquidityLauncherTemplate(uint256 _templateId) external view returns (address) {
        return launcherTemplates[_templateId];
    }

    function getTemplateId(address _launcherTemplate) external view returns (uint256) {
        return liquidityTemplateToId[_launcherTemplate];
    }

    /**
     * @notice Get the total number of launchers in the contract.
     * @return Farms count.
     */
    function numberOfLiquidityLauncherContracts() external view returns (uint256) {
        return launchers.length;
    }
}
