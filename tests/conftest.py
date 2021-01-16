from brownie import accounts, web3, Wei, chain
from brownie.network.transaction import TransactionReceipt
from brownie.convert import to_address
import pytest
# from brownie import Contract
from settings import *


#####################################
# MISOAccessControls
######################################
@pytest.fixture(scope='module', autouse=True)
def miso_access_controls(MISOAccessControls):
    access_controls = MISOAccessControls.deploy({'from': accounts[0]})
    access_controls.initAccessControls(accounts[0], {'from': accounts[0]})
    access_controls.addOperatorRole(accounts[0], {'from': accounts[0]})
    return access_controls

@pytest.fixture(scope='module', autouse=True)
def public_access_controls(MISOAccessControls):
    access_controls = MISOAccessControls.deploy({'from': accounts[0]})
    access_controls.initAccessControls(accounts[0], {'from': accounts[0]})
    access_controls.addOperatorRole(accounts[0], {'from': accounts[0]})
    return access_controls

#####################################
# MISOTokenFactory
######################################
@pytest.fixture(scope='module', autouse=True)
def token_factory(MISOTokenFactory, miso_access_controls, fixed_token_template, mintable_token_template):
    token_factory = MISOTokenFactory.deploy({'from': accounts[0]})
    token_factory.initMISOTokenFactory(miso_access_controls, {'from': accounts[0]})
    
    fixed_token_tx = token_factory.addTokenTemplate(fixed_token_template, {"from": accounts[0]})
    mintable_token_tx = token_factory.addTokenTemplate(mintable_token_template, {"from": accounts[0]})
    assert "TokenTemplateAdded" in fixed_token_tx.events
    assert "TokenTemplateAdded" in mintable_token_tx.events
    assert token_factory.tokenTemplateId() == 2
    ft_address = token_factory.getTokenTemplate(1)
    mt_address = token_factory.getTokenTemplate(2)
    assert token_factory.getTemplateId(ft_address) == 1
    assert token_factory.getTemplateId(mt_address) == 2

    return token_factory


#####################################
# FixedToken
######################################
@pytest.fixture(scope='module', autouse=True)
def fixed_token(FixedToken):
    fixed_token = FixedToken.deploy({'from': accounts[0]})
    name = "Fixed Token"
    symbol = "FXT"
    owner = accounts[0]
    initial_supply = AUCTION_TOKENS

    fixed_token.initToken(name, symbol, owner, initial_supply, {'from': owner})
    assert fixed_token.name() == name
    assert fixed_token.symbol() == symbol
    assert fixed_token.totalSupply() == AUCTION_TOKENS
    assert fixed_token.balanceOf(owner) == AUCTION_TOKENS

    return fixed_token


#####################################
# FixedToken
######################################
@pytest.fixture(scope='module', autouse=True)
def fixed_token2(FixedToken):
    fixed_token = FixedToken.deploy({'from': accounts[0]})
    name = "Fixed Token"
    symbol = "FXT"
    owner = accounts[0]

    fixed_token.initToken(name, symbol, owner,AUCTION_TOKENS, {'from': owner})
    assert fixed_token.name() == name
    assert fixed_token.symbol() == symbol
    assert fixed_token.totalSupply() == AUCTION_TOKENS
    assert fixed_token.balanceOf(owner) == AUCTION_TOKENS

    return fixed_token

@pytest.fixture(scope='module', autouse=True)
def fixed_token_template(FixedToken):
    fixed_token_template = FixedToken.deploy({'from': accounts[0]})
    return fixed_token_template


    
#####################################
# MintableToken
######################################
@pytest.fixture(scope='module', autouse=True)
def mintable_token(MintableToken):
    mintable_token = MintableToken.deploy({'from': accounts[0]})

    name = "Mintable Token"
    symbol = "MNT"
    owner = accounts[0]

    mintable_token.initToken(name, symbol, owner, 0, {'from': owner})
    assert mintable_token.name() == name
    assert mintable_token.symbol() == symbol
    # assert mintable_token.owner() == owner
    # changed to access controls

    return mintable_token
    
@pytest.fixture(scope='module', autouse=True)
def mintable_token_template(MintableToken):
    mintable_token_template = MintableToken.deploy({'from': accounts[0]})
    return mintable_token_template



#####################################
# SushiToken
######################################
@pytest.fixture(scope='module', autouse=True)
def sushi_token(SushiToken):
    sushi_token = SushiToken.deploy({'from': accounts[0]})

    name = "Sushi Token"
    symbol = "Sushi"
    owner = accounts[0]

    sushi_token.initToken(name, symbol, owner, 0, {'from': owner})
    assert sushi_token.name() == name
    assert sushi_token.symbol() == symbol

    return sushi_token

@pytest.fixture(scope='module', autouse=True)
def sushi_token_template(SushiToken):
    sushi_token_template = SushiToken.deploy({'from': accounts[0]})
    return sushi_token_template
#####################################
# WETH9
######################################
@pytest.fixture(scope='module', autouse=True)
def weth_token(WETH9):
    weth_token = WETH9.deploy({'from': accounts[0]})
    return weth_token


#####################################
# MISOMarket
######################################
@pytest.fixture(scope='module', autouse=True)
def auction_factory(MISOMarket, miso_access_controls, dutch_auction_template, crowdsale_template):
    auction_factory = MISOMarket.deploy({'from': accounts[0]})

    auction_factory.initMISOMarket(miso_access_controls, [dutch_auction_template, crowdsale_template], {'from': accounts[0]})
    # assert miso_access_controls.hasAdminRole(accounts[0]) == True 

    return auction_factory

#####################################
# DutchAuction
######################################
@pytest.fixture(scope='module', autouse=True)
def dutch_auction(DutchAuction, fixed_token):
    assert fixed_token.balanceOf(accounts[0]) == AUCTION_TOKENS
    
    start_date = chain.time() +10
    end_date = start_date + AUCTION_TIME
    wallet = accounts[1]
    dutch_auction = DutchAuction.deploy({"from": accounts[0]})

    fixed_token.approve(dutch_auction, AUCTION_TOKENS, {"from": accounts[0]})

    dutch_auction.initAuction(accounts[0], fixed_token, AUCTION_TOKENS, start_date, end_date, ETH_ADDRESS, AUCTION_START_PRICE, AUCTION_RESERVE, wallet, {"from": accounts[0]})
    assert dutch_auction.clearingPrice() == AUCTION_START_PRICE
    chain.sleep(10)
    return dutch_auction 

@pytest.fixture(scope='module', autouse=True)
def dutch_auction_template(DutchAuction):
    dutch_auction_template = DutchAuction.deploy({"from": accounts[0]})
    return dutch_auction_template

#####################################
# Crowdsale
######################################
@pytest.fixture(scope='module', autouse=True)
def crowdsale(Crowdsale, mintable_token):
    crowdsale = Crowdsale.deploy({"from": accounts[0]})
    mintable_token.mint(accounts[0], AUCTION_TOKENS, {"from": accounts[0]})
    assert mintable_token.balanceOf(accounts[0]) == AUCTION_TOKENS

    start_time = chain.time() + 10
    end_time = start_time + CROWDSALE_TIME
    wallet = accounts[4]
    
    mintable_token.approve(crowdsale, AUCTION_TOKENS, {"from": accounts[0]})
    crowdsale.initCrowdsale(accounts[0], mintable_token, ETH_ADDRESS, CROWDSALE_TOKENS, start_time, end_time, CROWDSALE_RATE, CROWDSALE_GOAL, wallet, {"from": accounts[0]})
    assert mintable_token.balanceOf(crowdsale) == AUCTION_TOKENS
    chain.sleep(10)
    return crowdsale 

@pytest.fixture(scope='module', autouse=True)
def crowdsale_token(Crowdsale, mintable_token, fixed_token2):
    crowdsale = Crowdsale.deploy({"from": accounts[0]})
    mintable_token.mint(accounts[0], AUCTION_TOKENS, {"from": accounts[0]})
    assert mintable_token.balanceOf(accounts[0]) == AUCTION_TOKENS

    start_time = chain.time() + 10
    end_time = start_time + CROWDSALE_TIME
    wallet = accounts[4]
    
    mintable_token.approve(crowdsale, AUCTION_TOKENS, {"from": accounts[0]})
    crowdsale.initCrowdsale(accounts[0], mintable_token, fixed_token2, CROWDSALE_TOKENS, start_time, end_time, CROWDSALE_RATE, CROWDSALE_GOAL, wallet, {"from": accounts[0]})
    assert mintable_token.balanceOf(crowdsale) == AUCTION_TOKENS
    chain.sleep(10)
    return crowdsale 

@pytest.fixture(scope='module', autouse=True)
def crowdsale_template(Crowdsale, mintable_token):
    crowdsale_template = Crowdsale.deploy({"from":accounts[0]})
    return crowdsale_template
    
#####################################
# UninswapV2Factory
######################################
@pytest.fixture(scope='module', autouse=True)
def uniswap_factory(UniswapV2Factory):
    uniswap_factory = UniswapV2Factory.deploy(accounts[0], {"from": accounts[0]})
    return uniswap_factory


#####################################
# Point List
######################################
@pytest.fixture(scope='module', autouse=True)
def point_list(PointList, public_access_controls):
    point_list = PointList.deploy({"from": accounts[0]})
    point_list.initPointList(public_access_controls, {"from": accounts[0]})
    return point_list


#####################################
# MISOLauncher
######################################

@pytest.fixture(scope='module', autouse=True)
def pool_liquidity_template(PoolLiquidity):
    pool_liquidity_template = PoolLiquidity.deploy({"from": accounts[0]})
    return pool_liquidity_template

@pytest.fixture(scope='module', autouse=True)
def seed_liquidity_template(SeedLiquidity):
    seed_liquidity_template = SeedLiquidity.deploy({"from": accounts[0]})
    return seed_liquidity_template


@pytest.fixture(scope='module', autouse=True)
def launcher(MISOLiquidityLauncher, miso_access_controls, pool_liquidity_template, seed_liquidity_template, weth_token):
    launcher = MISOLiquidityLauncher.deploy({"from": accounts[0]})
    launcher.initMISOLiquidityLauncher(miso_access_controls, weth_token)
    assert launcher.accessControls() == miso_access_controls
    assert launcher.WETH() == weth_token

    launcher.addLiquidityLauncherTemplate(pool_liquidity_template, {"from": accounts[0]} )
    # launcher.addLiquidityLauncherTemplate(seed_liquidity_template, {"from": accounts[0]} )

    return launcher

@pytest.fixture(scope='module', autouse=True)
def pool_liquidity(PoolLiquidity, public_access_controls, mintable_token, weth_token, uniswap_factory):

    deadline = chain.time() + POOL_LAUNCH_DEADLINE
    launch_window = POOL_LAUNCH_WINDOW
    locktime = POOL_LAUNCH_LOCKTIME
    pool_liquidity = PoolLiquidity.deploy({"from": accounts[0]})
    pool_liquidity.initPoolLiquidity(public_access_controls, mintable_token, weth_token, uniswap_factory, accounts[0], accounts[0], deadline, launch_window, locktime)

    return pool_liquidity

@pytest.fixture(scope='module', autouse=True)
def launcher_pool_liquidity(PoolLiquidity, launcher):
    template_id = 1
    tx = launcher.createLiquidityLauncher(template_id, {"from": accounts[0]})
    assert "LiquidityLauncherCreated" in tx.events
    pool_liquidity = PoolLiquidity.at(web3.toChecksumAddress(tx.events['LiquidityLauncherCreated']['addr']))

    return pool_liquidity


#####################################
# Farm Factory
######################################
@pytest.fixture(scope='module', autouse=True)
def farm_factory(MISOFarmFactory,miso_access_controls,farm_template):
    miso_dev = accounts[0]
    minimum_fee = 0 
    token_fee = 0
    farm_factory = MISOFarmFactory.deploy({"from":accounts[0]})
    farm_factory.initMISOFarmFactory(miso_access_controls,miso_dev, minimum_fee, token_fee,{"from":accounts[0]})
    tx = farm_factory.addFarmTemplate(farm_template, {"from":accounts[0]})
    assert "FarmTemplateAdded" in tx.events
    return farm_factory

@pytest.fixture(scope='module', autouse=True)
def farm_template(MasterChef):
    farm_template = MasterChef.deploy({"from":accounts[0]})
    return farm_template

#####################################
# MISORecipe
######################################

@pytest.fixture(scope='module', autouse=True)
def token_factory_sushi(MISOTokenFactory, miso_access_controls, sushi_token_template):
    token_factory_sushi = MISOTokenFactory.deploy({'from': accounts[0]})
    token_factory_sushi.initMISOTokenFactory(miso_access_controls, {'from': accounts[0]})
    
    token_factory_sushi.addTokenTemplate(sushi_token_template, {"from": accounts[0]})
    return token_factory_sushi

@pytest.fixture(scope='module', autouse=True)
def miso_recipe_02(MISORecipe02,miso_access_controls,token_factory_sushi, weth_token, auction_factory, launcher,uniswap_factory,farm_factory):
    miso_recipe_02 = MISORecipe02.deploy(token_factory_sushi,weth_token,auction_factory,launcher,uniswap_factory,farm_factory,{"from":accounts[0]})
    
    return miso_recipe_02

@pytest.fixture(scope='module', autouse=True)
def miso_recipe_03(MISORecipe03,weth_token,uniswap_factory,farm_factory):
    miso_recipe_03 = MISORecipe03.deploy(weth_token,uniswap_factory,farm_factory, {"from":accounts[0]})
    
    return miso_recipe_03
