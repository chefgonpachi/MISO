pragma solidity ^0.6.9;

// GP: Token escrow, lock up tokens for a period of time
import "./Utils/CloneFactory.sol";
import "./Utils/Owned.sol";
import "./Access/MISOAccessControls.sol";

contract MISOFermenter is Owned, CloneFactory{
    /// @notice Responsible for access rights to the contract
    MISOAccessControls public accessControls;

    bool private initialised; 
    struct Fermenter{
        bool exists;
        uint256 templateId;
        uint256 index;
    }

    /// @notice Escrows created using the factory
    address[] public escrows;

    /// @notice Template id to track respective escrow template
    uint256 public escrowTemplateId;
    
    /// @notice mapping from template id to escrow template address
    mapping(uint256 => address) private escrowTemplates;

    /// @notice mapping from escrow address to struct Fermenter
    mapping(address => Fermenter) public isChildEscrow;
    
    /// @notice event emitted when first initializing MISO fermenter
    event MisoInitFermenter(address sender);

    /// @notice event emitted when escrow template added
    event EscrowTemplateAdded(address newTemplate, uint256 templateId);

    /// @notice event emitted when escrow template is removed
    event EscrowTemplateRemoved(address template, uint256 templateId);

    /// @notice event emitted when escrow is created
    event EscrowCreated(address indexed owner, address indexed addr,address escrowTemplate);


     /**
     * @dev Single gateway to initialize the MISO Market with proper address
     * @dev Can only be initialized once
     */
    function _initMISOFermenter(address _accessControls) external {
        require(!initialised);
        initialised = true;
        accessControls = MISOAccessControls(_accessControls);
        emit MisoInitFermenter(msg.sender);
    }


    /**
     * @dev Creates a new escrow corresponding to template Id
     */
    function createEscrow(uint256 _templateId) external returns (address newEscrow){
        require(escrowTemplates[_templateId]!= address(0));
        newEscrow = createClone(escrowTemplates[_templateId]);
        isChildEscrow[address(newEscrow)] = Fermenter(true,_templateId,escrows.length-1);
        escrows.push(newEscrow);
        emit EscrowCreated(msg.sender,address(newEscrow),escrowTemplates[_templateId]);
    }


     /**
     * @dev Function to add a escrow template to create through factory
     * @dev Should have operator access
     * @param _escrowTemplate Escrow template to create a token
    */
    function addEscrowTemplate(address _escrowTemplate) external onlyOwner{
         require(
            accessControls.hasOperatorRole(msg.sender),
            "MISOTokenFactory.addEscrowTemplate: Sender must be operator"
        );
        escrowTemplateId++;
        escrowTemplates[escrowTemplateId] = _escrowTemplate;
        emit EscrowTemplateAdded(_escrowTemplate, escrowTemplateId);
    }

    /**
     * @dev Function to remove a escrow template
     * @dev Should have operator access
     * @param _templateId Refers to template that is to be deleted
    */
    function removeEscrowTemplate(uint256 _templateId) external {
        require(escrowTemplates[_templateId] != address(0));
        address template = escrowTemplates[_templateId];
        escrowTemplates[_templateId] = address(0);
        emit EscrowTemplateRemoved(template, _templateId);
    }

    /// @dev Get the address of the escrow template
    function getEscrowTemplate(uint256 _templateId) public view returns (address escrowTemplate) {
        return escrowTemplates[_templateId];
    }
    
    /// @dev Get the total number of escrows in the factory
    function numberOfTokens() public view returns (uint256) {
        return escrows.length;
    }

    function getTemplateId(address _escrowTemplate) public view returns (uint256 templateId) {}


}
