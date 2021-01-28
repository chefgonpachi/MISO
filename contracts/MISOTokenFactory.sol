pragma solidity ^0.6.9;

import "./Utils/CloneFactory.sol";
import "../interfaces/IMisoToken.sol";
import "./Access/MISOAccessControls.sol";
import "../interfaces/IERC20.sol";


contract MISOTokenFactory is CloneFactory {
    
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


    /// @notice Minimum fee to create a farm through the factory
    uint256 public minimumFee;
    uint256 public tokenFee;

    ///@notice Any donations if set are sent here
    address payable public misoDiv;


    /// @notice event emitted when first initializing Miso Token Factory
    event MisoInitTokenFactory(address sender);

    /// @notice event emitted when a token is created using template id
    event TokenCreated(address indexed owner, address indexed addr, address tokenTemplate);
    
    /// @notice event emitted when a token template is added
    event TokenTemplateAdded(address newToken, uint256 templateId);

    /// @notice event emitted when a token template is removed
    event TokenTemplateRemoved(address token, uint256 templateId);

    constructor() public {
    }

    /**
     * @dev Single gateway to initialize the MISO Token Factory with proper address
     * @dev Can only be initialized once
     // GP: Add fee inits
    */
    function initMISOTokenFactory(address _accessControls) external  {
        require(!initialised);
        initialised = true;
        accessControls = MISOAccessControls(_accessControls);
        emit MisoInitTokenFactory(msg.sender);
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
     * @dev Creates a token corresponding to template id
     * @dev Initializes token with parameters passed
     * @param _templateId Template id of token to create 
     */
    function deployToken(
        uint256 _templateId
    )
        public
        payable
        returns (address token)
    {
        require(msg.value >= minimumFee, 'Failed to transfer minimumFee');
        require(tokenTemplates[_templateId] != address(0));
        token = createClone(tokenTemplates[_templateId]);
        // GP: triple chek the token index is correct
        tokenInfo[address(token)] = Token(true, _templateId, tokens.length - 1);
        tokens.push(address(token));
        emit TokenCreated(msg.sender, address(token), tokenTemplates[_templateId]);
        if (msg.value > 0) {
            misoDiv.transfer(msg.value);
        }
    }

    /**
     * @dev Creates a token corresponding to template id
     * @dev Initializes token with parameters passed
     * @param _templateId Template id of token to create 
     */
    function createToken(
        uint256 _templateId,
        bytes calldata _data
    )
        external
        payable
        returns (address token)
    {
        token = deployToken(_templateId);
        IMisoToken(token).initToken(_data);
        uint256 initialTokens = IERC20(token).balanceOf(address(this));
        if (initialTokens > 0 ) {
            IERC20(token).transfer(msg.sender, initialTokens);
        }
    }



    /**
     * @dev Function to add a token template to create through factory
     * @dev Should have operator access
     * @param _template Token template to create a token
    */
    function addTokenTemplate(address _template) external {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "MISOTokenFactory.addTokenTemplate: Sender must be operator"
        );
        require(templateId[_template] == 0);
        tokenTemplateId++;
        tokenTemplates[tokenTemplateId] = _template;
        templateId[_template] = tokenTemplateId;
        emit TokenTemplateAdded(_template, tokenTemplateId);
    }

    /**
     * @dev Function to remove a token template
     * @dev Should have operator access
     * @param _templateId Refers to template that is to be deleted
    */
    function removeTokenTemplate(uint256 _templateId) external {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "MISOTokenFactory.removeTokenTemplate: Sender must be operator"
        );
        require(tokenTemplates[_templateId] != address(0));
        address template = tokenTemplates[_templateId];
        tokenTemplates[_templateId] = address(0);
        delete templateId[template];
        emit TokenTemplateRemoved(template, _templateId);
    }

    /// @dev Get the address of the token template
    function getTokenTemplate(uint256 _templateId) public view returns (address tokenTemplate) {
        return tokenTemplates[_templateId];
    }
    
    /// @dev Get the total number of tokens in the factory
    function numberOfTokens() public view returns (uint256) {
        return tokens.length;
    }

    /// @dev Get the template ID in the factory
    function getTemplateId(address _tokenTemplate) public view returns (uint256) {
        return templateId[_tokenTemplate];
    }

}
