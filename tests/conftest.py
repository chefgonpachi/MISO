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
def access_controls(MISOAccessControls):
    access_controls = MISOAccessControls.deploy({'from': accounts[0]})
    access_controls.addOperatorRole(accounts[0], {'from': accounts[0]})
    return access_controls

#####################################
# MISOTokenFactory
######################################
@pytest.fixture(scope='module', autouse=True)
def token_factory(MISOTokenFactory, access_controls, fixed_token, mintable_token):
    token_factory = MISOTokenFactory.deploy({'from': accounts[0]})
    token_factory.initMISOTokenFactory(access_controls, {'from': accounts[0]})
    
    fixed_token_tx = token_factory.addTokenTemplate(fixed_token, {"from": accounts[0]})
    mintable_token_tx = token_factory.addTokenTemplate(mintable_token, {"from": accounts[0]})
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

    fixed_token.initToken(name, symbol, owner, {'from': owner})
    assert fixed_token.name() == name
    assert fixed_token.symbol() == symbol
    assert fixed_token.owner() == owner

    fixed_token.initFixedTotalSupply(AUCTION_TOKENS, {'from': owner})
    assert fixed_token.totalSupply() == AUCTION_TOKENS
    assert fixed_token.balanceOf(owner) == AUCTION_TOKENS

    return fixed_token


    
#####################################
# MintableToken
######################################
@pytest.fixture(scope='module', autouse=True)
def mintable_token(MintableToken):
    mintable_token = MintableToken.deploy({'from': accounts[0]})

    name = "Mintable Token"
    symbol = "MNT"
    owner = accounts[0]

    mintable_token.initToken(name, symbol, owner, {'from': owner})
    assert mintable_token.name() == name
    assert mintable_token.symbol() == symbol
    assert mintable_token.owner() == owner

    return mintable_token
    
#####################################
# SushiToken
######################################
@pytest.fixture(scope='module', autouse=True)
def sushi_token(SushiToken):
    sushi_token = SushiToken.deploy({'from': accounts[0]})

    name = "Sushi Token"
    symbol = "Sushi"
    owner = accounts[0]

    sushi_token.initToken(name, symbol, owner, {'from': owner})
    assert sushi_token.name() == name
    assert sushi_token.symbol() == symbol
    assert sushi_token.owner() == owner

    return sushi_token

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
def auction_factory(MISOMarket, access_controls, fixed_token, mintable_token, sushi_token):
    auction_factory = MISOMarket.deploy({'from': accounts[0]})

    auction_factory.initMISOMarket(access_controls, [fixed_token, mintable_token, sushi_token], {'from': accounts[0]})
    # assert access_controls.hasAdminRole(accounts[0]) == True 

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

#####################################
# Crowdsale
######################################
@pytest.fixture(scope='module', autouse=True)
def crowdsale(Crowdsale, mintable_token):
    mintable_token.mint(accounts[0], AUCTION_TOKENS, {"from": accounts[0]})
    assert mintable_token.balanceOf(accounts[0]) == AUCTION_TOKENS

    start_time = chain.time() + 10
    end_time = start_time + CROWDSALE_TIME
    wallet = accounts[2]
    crowdsale = Crowdsale.deploy({"from": accounts[0]})

    mintable_token.approve(crowdsale, AUCTION_TOKENS, {"from": accounts[0]})
    crowdsale.initCrowdsale(accounts[0], mintable_token, CROWDSALE_TOKENS, start_time, end_time, CROWDSALE_RATE, CROWDSALE_GOAL, wallet, {"from": accounts[0]})
    assert mintable_token.balanceOf(crowdsale) == AUCTION_TOKENS
    chain.sleep(10)
    return crowdsale 

#####################################
# UninswapV2Factory
######################################
@pytest.fixture(scope='module', autouse=True)
def uniswap_factory(UniswapV2Factory):
    uniswap_factory = UniswapV2Factory.deploy(accounts[0], {"from": accounts[0]})
    return uniswap_factory

#####################################
# MISOLauncher
######################################
@pytest.fixture(scope='module', autouse=True)
def launcher(MISOLauncher, access_controls, mintable_token, weth_token, uniswap_factory):
    launcher = MISOLauncher.deploy({"from": accounts[0]})
    owner = accounts[0]
    wallet = accounts[1]
    launcher.initMISOLauncher(access_controls, mintable_token, weth_token, uniswap_factory, owner, wallet)
    # assert launcher.accessControls() == access_controls
    # assert launcher.token() == mintable_token
    # assert launcher.WETH() == weth_token
    # assert launcher.factory() == uniswap_factory
    # assert launcher.wallet() == wallet

    return launcher