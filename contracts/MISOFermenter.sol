pragma solidity 0.6.12;


// ------------------------------------------------------------------------
// ████████████████████████████████████████████████████████████████████████
// ████████████████████████████████████████████████████████████████████████
// ███████ Instant ████████████████████████████████████████████████████████
// ███████████▀▀▀████████▀▀▀███████▀█████▀▀▀▀▀▀▀▀▀▀█████▀▀▀▀▀▀▀▀▀▀█████████
// ██████████ ▄█▓┐╙████╙ ▓█▄ ▓█████ ▐███  ▀▀▀▀▀▀▀▀████▌ ▓████████▓ ╟███████
// ███████▀╙ ▓████▄ ▀▀ ▄█████ ╙▀███ ▐███▀▀▀▀▀▀▀▀▀  ████ ╙▀▀▀▀▀▀▀▀╙ ▓███████
// ████████████████████████████████████████████████████████████████████████
// ████████████████████████████████████████████████████████████████████████
// ████████████████████████████████████████████████████████████████████████
// ------------------------------------------------------------------------


// GP: Token escrow, lock up tokens for a period of time
import "./Utils/CloneFactory.sol";
import "./Utils/Owned.sol";
import "./Access/MISOAccessControls.sol";

contract MISOFermenter is Owned, CloneFactory {

    /// @notice Responsible for access rights to the contract.
    MISOAccessControls public accessControls;

    /// @notice Whether farm factory has been initialized or not.
    bool private initialised;

    /// @notice Struct to track Fermenter template.
    struct Fermenter{
        bool exists;
        uint256 templateId;
        uint256 index;
    }

    /// @notice Escrows created using the factory.
    address[] public escrows;

    /// @notice Template id to track respective escrow template.
    uint256 public escrowTemplateId;

    /// @notice Mapping from template id to escrow template address.
    mapping(uint256 => address) private escrowTemplates;

    /// @notice mapping from escrow template address to escrow template id
    mapping(address => uint256) private escrowTemplateToId;

    /// @notice mapping from escrow address to struct Fermenter
    mapping(address => Fermenter) public isChildEscrow;

    /// @notice Event emitted when first initializing MISO fermenter.
    event MisoInitFermenter(address sender);

    /// @notice Event emitted when escrow template added.
    event EscrowTemplateAdded(address newTemplate, uint256 templateId);

    /// @notice Event emitted when escrow template is removed.
    event EscrowTemplateRemoved(address template, uint256 templateId);

    /// @notice Event emitted when escrow is created.
    event EscrowCreated(address indexed owner, address indexed addr,address escrowTemplate);

    /**
     * @notice Single gateway to initialize the MISO Market with proper address.
     * @dev Can only be initialized once.
     * @param _accessControls Sets address to get the access controls from.
     */
    function _initMISOFermenter(address _accessControls) external {
        /// @dev Maybe missing require message?
        require(!initialised);
        initialised = true;
        accessControls = MISOAccessControls(_accessControls);
        emit MisoInitFermenter(msg.sender);
    }

    /**
     * @notice Creates a new escrow corresponding to template Id.
     * @param _templateId Template id of the escrow to create.
     * @return newEscrow Escrow address.
     */
    function createEscrow(uint256 _templateId) external returns (address newEscrow) {
        /// @dev Maybe missing require message?
        require(escrowTemplates[_templateId]!= address(0));
        newEscrow = createClone(escrowTemplates[_templateId]);
        isChildEscrow[address(newEscrow)] = Fermenter(true,_templateId,escrows.length-1);
        escrows.push(newEscrow);
        emit EscrowCreated(msg.sender,address(newEscrow),escrowTemplates[_templateId]);
    }

    /**
     * @notice Function to add a escrow template to create through factory.
     * @dev Should have operator access.
     * @param _escrowTemplate Escrow template to create a token.
     */
    function addEscrowTemplate(address _escrowTemplate) external onlyOwner{
         require(
            accessControls.hasOperatorRole(msg.sender),
            "MISOFermenter: Sender must be operator"
        );
        escrowTemplateId++;
        escrowTemplates[escrowTemplateId] = _escrowTemplate;
        escrowTemplateToId[_escrowTemplate] = escrowTemplateId;
        emit EscrowTemplateAdded(_escrowTemplate, escrowTemplateId);
    }

    /**
     * @notice Function to remove a escrow template.
     * @dev Should have operator access.
     * @param _templateId Refers to template that is to be deleted.
     */
    function removeEscrowTemplate(uint256 _templateId) external {
        require(escrowTemplates[_templateId] != address(0));
        address template = escrowTemplates[_templateId];
        escrowTemplates[_templateId] = address(0);
        delete escrowTemplateToId[template];
        emit EscrowTemplateRemoved(template, _templateId);
    }

    /**
     * @notice Get the address of the escrow template based on template ID.
     * @param _templateId Escrow template ID.
     * @return Address of the required template ID.
     */
    function getEscrowTemplate(uint256 _templateId) public view returns (address) {
        return escrowTemplates[_templateId];
    }

    /**
     * @notice Get the ID based on template address.
     * @param _escrowTemplate Escrow template address.
     * @return templateId ID of the required template address.
     */
    function getTemplateId(address _escrowTemplate) public view returns (uint256 templateId) {
        return escrowTemplateToId[_escrowTemplate];
    }

    /**
     * @notice Get the total number of escrows in the factory.
     * @return Escrow count.
     */
    function numberOfTokens() public view returns (uint256) {
        return escrows.length;
    }


}
