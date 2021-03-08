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
import "../interfaces/IMisoToken.sol";
import "./Access/MISOAccessControls.sol";
import "../interfaces/IERC20.sol";
import "./Utils/SafeTransfer.sol";

contract MISOTokenFactory is CloneFactory, SafeTransfer{
    
    /// @notice Responsible for access rights to the contract
    MISOAccessControls public accessControls;

    /// @notice Whether token factory has been initialized or not.
    bool private initialised;

    /// @notice Struct to track Token template.
    struct Token {
        bool exists;
        uint256 templateId;
        uint256 index;
    }

    /// @notice Mapping from auction address created through this contract to Auction struct.
    mapping(address => Token) public tokenInfo;

    /// @notice Array of tokens created using the factory.
    address[] public tokens;

    /// @notice Template id to track respective token template.
    uint256 public tokenTemplateId;

    /// @notice Mapping from token template id to token template address.
    mapping(uint256 => address) private tokenTemplates;

    /// @notice mapping from token template address to token template id
    mapping(address => uint256) private tokenTemplateToId;

    /// @notice Minimum fee to create a token through the factory.
    uint256 public minimumFee;
    uint256 public integratorFeePct;

    /// @notice Any MISO dividends collected are sent here.
    address payable public misoDiv;

    /// @notice Event emitted when first initializing Miso Token Factory.
    event MisoInitTokenFactory(address sender);

    /// @notice Event emitted when a token is created using template id.
    event TokenCreated(address indexed owner, address indexed addr, address tokenTemplate);
    
    /// @notice event emitted when a token is initialized using template id
    event TokenInitialized(address indexed addr, uint256 templateId, bytes data);

    /// @notice Event emitted when a token template is added.
    event TokenTemplateAdded(address newToken, uint256 templateId);

    /// @notice Event emitted when a token template is removed.
    event TokenTemplateRemoved(address token, uint256 templateId);

    constructor() public {
    }

    /**
     * @notice Single gateway to initialize the MISO Token Factory with proper address.
     * @dev Can only be initialized once.
     * @param _accessControls Sets address to get the access controls from.
     */
    /// @dev GP: Add fee inits.
    function initMISOTokenFactory(address _accessControls) external  {
        /// @dev Maybe missing require message?
        require(!initialised);
        initialised = true;
        accessControls = MISOAccessControls(_accessControls);
        emit MisoInitTokenFactory(msg.sender);
    }

    /**
     * @notice Sets the minimum fee.
     * @param _amount Fee amount.
     */
    function setMinimumFee(uint256 _amount) public {
        require(
            accessControls.hasAdminRole(msg.sender),
            "MISOTokenFactory: Sender must be operator"
        );
        minimumFee = _amount;
    }

    /**
     * @notice Sets integrator fee percentage.
     * @param _amount Percentage amount.
     */
    function setIntegratorFeePct(uint256 _amount) public {
        require(
            accessControls.hasAdminRole(msg.sender),
            "MISOTokenFactory: Sender must be operator"
        );
        /// @dev this is out of 1000, ie 25% = 250
        require(
            _amount <= 1000, 
            "MISOTokenFactory: Range is from 0 to 1000"
        );
        integratorFeePct = _amount;
    }

    /**
     * @notice Sets dividend address.
     * @param _divaddr Dividend address.
     */
    function setDividends(address payable _divaddr) public  {
        require(
            accessControls.hasAdminRole(msg.sender),
            "MISOTokenFactory: Sender must be operator"
        );
        misoDiv = _divaddr;
    }

    /**
     * @notice Creates a token corresponding to template id and transfers fees.
     * @dev Initializes token with parameters passed
     * @param _templateId Template id of token to create.
     * @param _integratorFeeAccount Address to pay the fee to.
     * @return token Token address.
     */
    function deployToken(
        uint256 _templateId,
        address payable _integratorFeeAccount
    )
        public payable returns (address token)
    {
        require(msg.value >= minimumFee, "MISOTokenFactory: Failed to transfer minimumFee");
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
        /// @dev GP: Triple check the token index is correct.
        tokenInfo[address(token)] = Token(true, _templateId, tokens.length);
        tokens.push(address(token));
        emit TokenCreated(msg.sender, address(token), tokenTemplates[_templateId]);
    }

    /**
     * @notice Creates a token corresponding to template id.
     * @dev Initializes token with parameters passed.
     * @param _templateId Template id of token to create.
     * @param _integratorFeeAccount Address to pay the fee to.
     * @param _data Data to be passed to the token contract for init.
     * @return token Token address.
     */
    function createToken(
        uint256 _templateId,
        address payable _integratorFeeAccount,
        bytes calldata _data
    )
        external payable returns (address token)
    {
        token = deployToken(_templateId, _integratorFeeAccount);
        IMisoToken(token).initToken(_data);
        uint256 initialTokens = IERC20(token).balanceOf(address(this));
        if (initialTokens > 0 ) {
            _safeTransfer(token, msg.sender, initialTokens);
        }

        emit TokenInitialized(address(token), _templateId, _data);
    }

    /**
     * @notice Function to add a token template to create through factory.
     * @dev Should have operator access.
     * @param _template Token template to create a token.
     */
    function addTokenTemplate(address _template) external {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "MISOTokenFactory: Sender must be operator"
        );
        require(tokenTemplateToId[_template] == 0);
        tokenTemplateId++;
        tokenTemplates[tokenTemplateId] = _template;
        tokenTemplateToId[_template] = tokenTemplateId;
        emit TokenTemplateAdded(_template, tokenTemplateId);
    }

    /**
     * @notice Function to remove a token template.
     * @dev Should have operator access.
     * @param _templateId Refers to template that is to be deleted.
    */
    function removeTokenTemplate(uint256 _templateId) external {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "MISOTokenFactory: Sender must be operator"
        );
        require(tokenTemplates[_templateId] != address(0));
        address template = tokenTemplates[_templateId];
        tokenTemplates[_templateId] = address(0);
        delete tokenTemplateToId[template];
        emit TokenTemplateRemoved(template, _templateId);
    }

    /**
     * @notice Get the address based on template ID.
     * @param _templateId Token template ID.
     * @return Address of the required template ID.
     */
    function getTokenTemplate(uint256 _templateId) public view returns (address ) {
        return tokenTemplates[_templateId];
    }

    /**
     * @notice Get the ID based on template address.
     * @param _tokenTemplate Token template address.
     * @return ID of the required template address.
     */
    function getTemplateId(address _tokenTemplate) public view returns (uint256) {
        return tokenTemplateToId[_tokenTemplate];
    }

    /**
     * @notice Get the total number of tokens in the factory.
     * @return Token count.
     */
    function numberOfTokens() public view returns (uint256) {
        return tokens.length;
    }
}
