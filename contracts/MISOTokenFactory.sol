pragma solidity ^0.6.9;

import "./Utils/CloneFactory.sol";
import "../interfaces/IMisoToken.sol";
import "./Access/MISOAccessControls.sol";
import "../interfaces/IERC20.sol";


contract MISOTokenFactory is CloneFactory {
    
    /// @notice Responsible for access rights to the contract
    MISOAccessControls public accessControls;

    bool private initialised;

    /// @notice Tokens created using the factory
    address[] public tokens;

    /// @notice Template id to track respective token template
    uint256 public tokenTemplateId;
    
    /// @notice mapping from template id to token template address
    mapping(uint256 => address) private tokenTemplates;

    /// @notice Tracks if a token is made by the factory
    mapping(address => bool) public isChildToken;
    mapping(address => uint256) public templateId;

    /// @notice event emitted when first initializing Miso Token Factory
    event MisoInitTokenFactory(address sender);

    /// @notice event emitted when a token is created using template id
    event TokenCreated(address indexed owner, address indexed addr, string name, string symbol, address tokenTemplate);
    
    /// @notice event emitted when a token template is added
    event TokenTemplateAdded(address newToken, uint256 templateId);

    /// @notice event emitted when a token template is removed
    event TokenTemplateRemoved(address token, uint256 templateId);

    constructor() public {
    }

    /**
     * @dev Single gateway to initialize the MISO Token Factory with proper address
     * @dev Can only be initialized once
    */
    function initMISOTokenFactory(address _accessControls) external  {
        require(!initialised);
        initialised = true;
        accessControls = MISOAccessControls(_accessControls);
        emit MisoInitTokenFactory(msg.sender);
    }

    /**
     * @dev Creates a token corresponding to template id
     * @dev Initializes token with parameters passed
     * @param _name Name for the token
     * @param _symbol Symbol for the token
     * @param _templateId Template id of token to create 
     */
    function createToken(string memory _name, string memory _symbol, uint256 _templateId, address _owner, uint256 _initialSupply) external returns (address token) {
        require(tokenTemplates[_templateId] != address(0));
        token = createClone(tokenTemplates[_templateId]);
        isChildToken[address(token)] = true;
        tokens.push(address(token));
        IMisoToken(token).initToken(_name, _symbol, _owner, _initialSupply);
        if (_initialSupply > 0 ) {
            IERC20(token).transfer(msg.sender, _initialSupply);
        }
        emit TokenCreated(msg.sender, address(token), _name, _symbol, tokenTemplates[_templateId]);
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
        delete templateId[tokenTemplates[_templateId]];
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

    /// @dev Get the total number of tokens in the factory
    function getTemplateId(address _tokenTemplate) public view returns (uint256) {
        return templateId[_tokenTemplate];
    }

}
