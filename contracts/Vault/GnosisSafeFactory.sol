pragma solidity 0.6.12;


import "../../interfaces/IGnosisProxyFactory.sol";
import "../../interfaces/ISafeGnosis.sol";
import "../Access/MISOAccessControls.sol";
import "../../interfaces/IERC20.sol";

contract GnosisSafeFactory {
    
    ISafeGnosis public safeGnosis;
    IGnosisProxyFactory public proxyFactory;
    MISOAccessControls public accessControls;

    bool private initialised;    
    mapping(address => ISafeGnosis) userToProxy;

    event GnosisSafeCreated(address indexed user, address indexed proxy, address safeGnosis, address proxyFactory);
    event MisoInitGnosisVault(address sender);
    event SafeGnosisUpdated(address indexed sender, address oldSafeGnosis, address newSafeGnosis);
    event ProxyFactoryUpdated(address indexed sender, address oldProxyFactory, address newProxyFactory);


    function initGnosisVault(address _accessControls, address _safeGnosis, address _proxyFactory) public{
        require(!initialised);
        safeGnosis = ISafeGnosis(_safeGnosis);
        proxyFactory = IGnosisProxyFactory(_proxyFactory);
        accessControls = MISOAccessControls(_accessControls);
        initialised = true;
        emit MisoInitGnosisVault(msg.sender);

    }

    /// @dev Setup function sets initial storage of contract.
    function setSafeGnosis(address _safeGnosis) external {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "GnosisVault.setSafeGnosis: Sender must be operator"
        );
        address oldSafeGnosis = address(safeGnosis);
        safeGnosis = ISafeGnosis(_safeGnosis);
        emit SafeGnosisUpdated(msg.sender, oldSafeGnosis, address(safeGnosis));

    }
    
    function setProxyFactory(address _proxyFactory) external {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "GnosisVault.setProxyFactory: Sender must be operator"
        );
        address oldProxyFactory = address(proxyFactory);
        proxyFactory = IGnosisProxyFactory(_proxyFactory);
        emit ProxyFactoryUpdated(msg.sender, oldProxyFactory, address(proxyFactory));

    }
    

    /// @dev Setup function sets initial storage of contract.
    /// @param _owners List of Safe owners.
    /// @param _threshold Number of required confirmations for a Safe transaction.
    /// @param to Contract address for optional delegate call.
    /// @param data Data payload for optional delegate call.
    /// @param fallbackHandler Handler for fallback calls to this contract
    /// @param paymentToken Token that should be used for the payment (0 is ETH)
    /// @param payment Value that should be paid
    /// @param paymentReceiver Adddress that should receive the payment (or 0 if tx.origin)
    function createSafe(address[] calldata _owners,
        uint256 _threshold,
        address to,
        bytes calldata data,
        address fallbackHandler,
        address paymentToken,
        uint256 payment,
        address payable paymentReceiver
    ) 
        public
        returns (ISafeGnosis proxy)
    {

        bytes memory safeGnosisData = abi.encode("setup(address[],uint256,address,bytes,address,address,uint256,address)",
        _owners,_threshold,to,data,fallbackHandler,paymentToken,payment,paymentReceiver);
        proxy = proxyFactory.createProxy(
            safeGnosis,
            safeGnosisData
        );
        userToProxy[msg.sender] = proxy;
        emit GnosisSafeCreated(msg.sender, address(proxy), address(safeGnosis), address(proxyFactory));
        return proxy;
    }


    /// GP: Can we also use the proxy with a nonce? Incase we need it.
    /// GP: Can we have a simplifed version with a few things already set? eg an ETH by default verision.
    /// GP: Can we set empty data or preset the feedback handler? Whats the minimum feilds required?

}