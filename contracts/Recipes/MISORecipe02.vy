# @version 0.2.8

# MVP for preparing a MISO set menu

interface IMISOTokenFactory:
    def createToken(
        name: String[64],
        symbol: String[32],
        templateId: uint256
    ) -> address: nonpayable

interface IMISOMarket:
    def createCrowdsale(
        token: address, 
        tokenSupply: uint256, 
        startDate: uint256, 
        endDate: uint256, 
        rate: uint256, 
        goal: uint256, 
        wallet: address,
        templateId: uint256
    ) -> address: nonpayable

interface IMISOLiquidity:
    def createLiquidityLauncher( 
        templateId: uint256
    ) -> address: nonpayable

interface IPoolLiquidity:
    def initPoolLiquidity(
        accessControls: address,
        token: address,
        WETH: address,
        factory: address,
        owner: address,
        wallet: address,
        duration: uint256,
        launchwindow: uint256,
        deadline: uint256,
        locktime: uint256
    ) : nonpayable
    def getLPTokenAddress() -> address: view

interface IMISOFarmFactory:
    def createFarm(
        rewards: address,
        rewardsPerBlock: uint256,
        startBlock: uint256,
        devaddr: address,
        accessControls: address,
        templateId: uint256
    ) -> address: nonpayable

interface IMasterChef:
    def initFarm(
        rewards: address,
        rewardsPerBlock: uint256,
        startBlock: uint256,
        devaddr: address,
        accessControls: address
    ) : nonpayable
    def addToken(allocPoint: uint256, lpToken: address, withUpdate: bool) : nonpayable

interface ISushiToken:
    def mint(owner: address, amount: uint256) : nonpayable
    def approve(spender: address, amount: uint256) -> bool: nonpayable
    def transfer(to: address, amount: uint256) -> bool: nonpayable



tokenFactory: public(IMISOTokenFactory)
misoMarket: public(address)
weth: public(address)
misoLauncher: public(IMISOLiquidity)
farmFactory: public(IMISOFarmFactory)
uniswapFactory: public(address)


@external
def __init__(
    tokenFactory: address,
    weth: address,
    misoMarket: address,
    misoLauncher: address,
    uniswapFactory: address, 
    farmFactory: address
):
    """
    @notice Recipe Number 01
    @param tokenFactory - Token Factory that produced fresh new tokens
    @param weth - Wrapped Ethers contract address
    @param misoMarket - Factory that produces a market / auction to sell your tokens
    @param misoLauncher - MISOLauncher is a vault that collects tokens and sends them to SushiSwap
    @param uniswapFactory - The SushiSwap factory to create new pools
    @param farmFactory - A factory that makes farms that can stake and reward your new tokens
    """

    self.tokenFactory = IMISOTokenFactory(tokenFactory)
    self.weth = weth
    self.misoMarket = misoMarket
    self.misoLauncher = IMISOLiquidity(misoLauncher)
    self.uniswapFactory = uniswapFactory
    self.farmFactory = IMISOFarmFactory(farmFactory)

    
@external
def prepareMiso(
    name: String[64],
    symbol: String[32],
    accessControl: address,
    tokensToMint: uint256,
    tokensToMarket: uint256,

    startTime: uint256, 
    endTime: uint256,
    marketRate: uint256,
    marketGoal: uint256,
    wallet: address,
    operator: address,

    duration: uint256,
    launchwindow: uint256, 
    deadline: uint256,
    locktime: uint256, 
    tokensToLiquidity: uint256,

    rewardsPerBlock: uint256, 
    startBlock: uint256,
    devAddr: address, 
    tokensToFarm: uint256,
    allocPoint: uint256,

) -> (address, address, address, address):
    """
    @notice Prepare Miso
    @param name Name 
    @param symbol Symbol
    @param accessControl For operator permissions 
    """

    assert startTime < endTime  # dev: Start time later then end time

    token: address = self.tokenFactory.createToken(name, symbol, 1)
    # create access control
    # transfer ownership to msg.sender

    ISushiToken(token).mint(self, tokensToMint)
    ISushiToken(token).approve(self.misoMarket, tokensToMarket)

    crowdsale: address = IMISOMarket(self.misoMarket).createCrowdsale(
        token,
        tokensToMarket, 
        startTime, 
        endTime, 
        marketRate, 
        marketGoal, 
        wallet, 
        2
    )

    poolLiquidity: address = self.misoLauncher.createLiquidityLauncher(1)

    IPoolLiquidity(poolLiquidity).initPoolLiquidity(accessControl,
        token,
        self.weth,
        self.uniswapFactory,
        operator,
        wallet,
        duration,
        launchwindow,
        deadline,
        locktime
    ) 
    
    ISushiToken(token).transfer(poolLiquidity,tokensToLiquidity)

    farm: address = self.farmFactory.createFarm(
            token,
            rewardsPerBlock,
            startBlock,
            devAddr,
            accessControl,
            1)

    
    ISushiToken(token).transfer(farm,tokensToFarm)
    lpToken: address = IPoolLiquidity(poolLiquidity).getLPTokenAddress()
    IMasterChef(farm).addToken(allocPoint, lpToken, False)

    return (token, crowdsale, poolLiquidity, farm)

