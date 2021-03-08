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

import "./Utils/CloneFactory.sol";
import "../interfaces/IMisoTemplate.sol";
import "./Access/MISOAccessControls.sol";
import "../interfaces/IERC20.sol";


contract MISOFactory is CloneFactory {
    
    /// @notice Responsible for access rights to the contract
    MISOAccessControls public accessControls;

    bool private initialised;

    /// @notice Struct to track Token template
    struct Token {
        bool exists;
        uint256 templateId;
        uint256 index;
    }
    
    /// @notice mapping from auction created through this contract to Auction struct
    mapping(address => Token) public tokenInfo;

    /// @notice Tokens created using the factory
    address[] public tokens;

    /// @notice Template id to track respective token template
    uint256 public tokenTemplateId;
    
    /// @notice mapping from template id to token template address
    mapping(uint256 => address) private tokenTemplates;

    /// @notice Tracks if a token is made by the factory
    mapping(address => uint256) public templateId;


    /// @notice Minimum fee to create a token through the factory
    uint256 public minimumFee;
    uint256 public integratorFeePct;

    ///@notice Any MISO dividends collected are sent here
    address payable public misoDiv;

    /// @notice event emitted when first initializing Miso Token Factory
    event MisoInitFactory(address sender);

    /// @notice event emitted when a token is created using template id
    event TemplateDeployed(address indexed owner, address indexed addr, address tokenTemplate);
    
    /// @notice event emitted when a token template is added
    event TemplateAdded(address newToken, uint256 templateId);

    /// @notice event emitted when a token template is removed
    event TemplateRemoved(address token, uint256 templateId);

    constructor() public {
    }

    /**
     * @dev Single gateway to initialize the MISO Token Factory with proper address
     * @dev Can only be initialized once
     // GP: Add fee inits
    */
    function initMISOFactory(address _accessControls) external  {
        require(!initialised);
        initialised = true;
        accessControls = MISOAccessControls(_accessControls);
        emit MisoInitFactory(msg.sender);
    }

    function setMinimumFee(uint256 _amount) public {
        require(
            accessControls.hasAdminRole(msg.sender),
            "MISOFactory: Sender must be operator"
        );
        minimumFee = _amount;
    }
    
    function setIntegratorFeePct(uint256 _amount) public {
        require(
            accessControls.hasAdminRole(msg.sender),
            "MISOFactory: Sender must be operator"
        );
        /// @dev this is out of 1000, ie 25% = 250
        require(
            _amount <= 1000, 
            "MISOFactory: Range is from 0 to 1000"
        );
        integratorFeePct = _amount;
    }   
    
    function setDividends(address payable _divaddr) public  {
        require(
            accessControls.hasAdminRole(msg.sender),
            "MISOFactory: Sender must be operator"
        );
        misoDiv = _divaddr;
    }

    /**
     * @dev Creates a token corresponding to template id
     * @dev Initializes token with parameters passed
     * @param _templateId Template id of token to create 
     */
    function deployTemplate(
        uint256 _templateId,
        address payable _integratorFeeAccount
    )
        public
        payable
        returns (address token)
    {
        require(msg.value >= minimumFee, 'MISOFactory: Failed to transfer minimumFee');
        require(tokenTemplates[_templateId] != address(0));
        uint256 integratorFee;
        uint256 misoFee = msg.value;
        if (_integratorFeeAccount != address(0) && _integratorFeeAccount != misoDiv) {
            integratorFee = misoFee * integratorFeePct / 1000;
            misoFee = misoFee - integratorFee;
        }
        if (misoFee > 0) {
            misoDiv.transfer(misoFee);
        }
        if (integratorFee > 0) {
            _integratorFeeAccount.transfer(integratorFee);
        }
        token = createClone(tokenTemplates[_templateId]);
        tokenInfo[address(token)] = Token(true, _templateId, tokens.length);
        tokens.push(address(token));
        emit TemplateDeployed(msg.sender, address(token), tokenTemplates[_templateId]);
   
    }

    /**
     * @dev Creates a token corresponding to template id
     * @dev Initializes token with parameters passed
     * @param _templateId Template id of token to create 
     */
    function createContract(
        uint256 _templateId,
        address payable _integratorFeeAccount,
        bytes calldata _data
    )
        external
        payable
        returns (address addr)
    {
        addr = deployTemplate(_templateId, _integratorFeeAccount);
        IMisoTemplate(addr).initData(_data);
    }



    /**
     * @dev Function to add a token template to create through factory
     * @dev Should have operator access
     * @param _template Token template to create a token
    */
    function addTemplate(address _template) external {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "MISOFactory: Sender must be operator"
        );
        require(templateId[_template] == 0);
        tokenTemplateId++;
        tokenTemplates[tokenTemplateId] = _template;
        templateId[_template] = tokenTemplateId;
        emit TemplateAdded(_template, tokenTemplateId);
    }

    /**
     * @dev Function to remove a token template
     * @dev Should have operator access
     * @param _templateId Refers to template that is to be deleted
    */
    function removeTemplate(uint256 _templateId) external {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "MISOFactory: Sender must be operator"
        );
        require(tokenTemplates[_templateId] != address(0));
        address template = tokenTemplates[_templateId];
        tokenTemplates[_templateId] = address(0);
        delete templateId[template];
        emit TemplateRemoved(template, _templateId);
    }

    /// @dev Get the address of the token template
    function getTemplate(uint256 _templateId) public view returns (address template) {
        return tokenTemplates[_templateId];
    }
    
    /// @dev Get the total number of contract in the factory
    function contractsDeployed() public view returns (uint256) {
        return tokens.length;
    }

    /// @dev Get the template ID in the factory
    function getTemplateId(address _tokenTemplate) public view returns (uint256) {
        return templateId[_tokenTemplate];
    }

}
