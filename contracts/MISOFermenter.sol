pragma solidity ^0.6.9;

// GP: Use clone factory to save user gas
// GP: Token escrow, lock up tokens for a period of time
import "./Utils/CloneFactory.sol";
import "./Utils/Owned.sol";

contract MISOFermenter is Owned, CloneFactory{

    bool private initialised; 
    struct Fermenter{
        bool exists;
        uint256 templateId;
        uint256 index;
    }


    address[] public escrows;
    uint256 public escrowTemplateId;
    
    mapping(uint256 => address) private escrowTemplates;
    mapping(address => Fermenter) public isChildEscrow;
    
    event MisoInitFermenter(address sender);

    // GP: Add more data to events
    event EscrowTemplateAdded(address newTemplate, uint256 templateId);
    event EscrowTemplateRemoved(address template, uint256 templateId);
    event EscrowCreated(address indexed owner, address indexed addr,address escrowTemplate);

    function _initMISOFermenter() external {
        require(!initialised);
        initialised = true;
        escrowTemplateId = 0;
        emit MisoInitFermenter(msg.sender);
    }

    // Sample functions
    function createEscrow(uint256 _templateId) external returns (address newEscrow){
        require(escrowTemplates[_templateId]!= address(0));
        newEscrow = createClone(escrowTemplates[_templateId]);
        isChildEscrow[address(newEscrow)] = Fermenter(true,_templateId,escrows.length-1);
        escrows.push(newEscrow);
        emit EscrowCreated(msg.sender,address(newEscrow),escrowTemplates[_templateId]);
    }
    function addEscrowTemplate(address _escrowTemplate) external onlyOwner{
    //        require(!isChildEscrow[_escrowTemplate].exists);
        escrowTemplateId++;
        escrowTemplates[escrowTemplateId] = _escrowTemplate;
        emit EscrowTemplateAdded(_escrowTemplate, escrowTemplateId);
    }
    function removeEscrowTemplate(uint256 _templateId) external {
        require(escrowTemplates[_templateId] != address(0));
        address template = escrowTemplates[_templateId];
        escrowTemplates[_templateId] = address(0);
        emit EscrowTemplateRemoved(template, _templateId);
    }

    // getter functions
    function getEscrowTemplate(uint256 _templateId) public view returns (address escrowTemplate) {
        return escrowTemplates[_templateId];
    }
    function getTemplateId(address _escrowTemplate) public view returns (uint256 templateId) {}


}
