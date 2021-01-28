pragma solidity ^0.6.9;

import "./Utils/CloneFactory.sol";
import "../interfaces/IMisoFarm.sol";
import "./Access/MISOAccessControls.sol";


contract MISOFarmFactory is CloneFactory {
    
    /// @notice Responsible for access rights to the contract
    MISOAccessControls public accessControls;

    bool private initialised;

    /// @notice Farms created using the factory
    address[] public farms;

    /// @notice Template id to track respective farm template
    uint256 public farmTemplateId;

    /// @notice mapping from template id to farm template address
    mapping(uint256 => address) private farmTemplates;

    ///@notice Tracks if a farm is made by the factory
    mapping(address => bool) public isChildFarm;
    mapping(address => uint256) public templateId;

    /// @notice Minimum fee to create a farm through the factory
    uint256 public minimumFee;
    uint256 public tokenFee;

    ///@notice Any donations if set are sent here
    address payable public misoDiv;


    ///@notice event emitted when first initializing the Miso Farm Factory
    event MisoInitFarmFactory(address sender);

    ///@notice event emitted when a farm is created using template id
    event FarmCreated(address indexed owner, address indexed addr, address farmTemplate);
    
    ///@notice event emitted when farm template is added to factory
    event FarmTemplateAdded(address newFarm, uint256 templateId);

    ///@notice event emitted when farm template is removed
    event FarmTemplateRemoved(address farm, uint256 templateId);

    constructor() public {
    }

    /**
     * @dev Single gateway to initialize the MISO Farm factory with proper address
     * @dev Can only be initialized once
    */
    function initMISOFarmFactory(
        address _accessControls,
        address payable _misoDiv,
        uint256 _minimumFee,
        uint256 _tokenFee
    ) 
        external
    {
        require(!initialised);
        initialised = true;
        misoDiv = _misoDiv;
        minimumFee = _minimumFee;
        tokenFee = _tokenFee;
        accessControls = MISOAccessControls(_accessControls);
        emit MisoInitFarmFactory(msg.sender);
    }


    function setMinimumFee(uint256 _amount) public {
        require(
            accessControls.hasAdminRole(msg.sender),
            "MISOFarmFactory.setminimumFee: Sender must be operator"
        );
        minimumFee = _amount;
    }
    
    function setTokenFee(uint256 _amount) public {
        require(
            accessControls.hasAdminRole(msg.sender),
            "MISOFarmFactory.setTokenFee: Sender must be operator"
        );
        tokenFee = _amount;
    }

    function setDividends(address payable _divaddr) public  {
        require(
            accessControls.hasAdminRole(msg.sender),
            "MISOFarmFactory.setDev: Sender must be operator"
        );
        misoDiv = _divaddr;
    }

    /** 
     * @dev Deploys a farm corresponding to the _templateId
     * @param _templateId Template id of the farm to create
    */
    function deployFarm(
        uint256 _templateId
    )
        public
        payable
        returns (address farm)
    {
        require(msg.value >= minimumFee, 'Failed to transfer minimumFee');
        require(farmTemplates[_templateId] != address(0));
        farm = createClone(farmTemplates[_templateId]);
        isChildFarm[address(farm)] = true;
        farms.push(address(farm));
        emit FarmCreated(msg.sender, address(farm), farmTemplates[_templateId]);
        if (msg.value > 0) {
            misoDiv.transfer(msg.value);
        }
    }

    /** 
     * @dev Creates a farm corresponding to the _templateId
     * @dev Initializes farm with the parameters passed
     * @param _templateId Template id of the farm to create
     * @param _data Data to be passed to the farm contract for init
    */
    function createFarm(
        uint256 _templateId,
        bytes calldata _data
    )
        external
        payable
        returns (address farm)
    {
        farm = deployFarm(_templateId);
        IMisoFarm(farm).initFarm(_data);
    }


    /**
     * @dev Function to add a farm template to create through factory
     * @dev Should have operator access
     * @param _template Farm template to create a farm
    */
    function addFarmTemplate(address _template) external {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "MISOFarmFactory.addFarmTemplate: Sender must be operator"
        );
        require(templateId[_template] == 0);
        farmTemplateId++;
        farmTemplates[farmTemplateId] = _template;
        templateId[_template] = farmTemplateId;
        emit FarmTemplateAdded(_template, farmTemplateId);
    }

     /**
     * @dev Function to remove a farm template
     * @dev Should have operator access
     * @param _templateId Refers to template that is to be deleted
    */
    function removeFarmTemplate(uint256 _templateId) external {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "MISOFarmFactory.removeFarmTemplate: Sender must be operator"
        );
        require(farmTemplates[_templateId] != address(0));
        address template = farmTemplates[_templateId];
        farmTemplates[_templateId] = address(0);
        delete templateId[template];
        emit FarmTemplateRemoved(template, _templateId);
    }

 
    /// @dev Get the address of the farm template
    function getFarmTemplate(uint256 _farmTemplate) public view returns (address farmTemplate) {
        return farmTemplates[_farmTemplate];
    }

    /// @dev Get the total number of farms in the factory
    function numberOfFarms() public view returns (uint256) {
        return farms.length;
    }


}
