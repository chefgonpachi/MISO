from brownie import accounts, web3, Wei, reverts, chain
from brownie.network.transaction import TransactionReceipt
from brownie.convert import to_address
import pytest
from brownie import Contract
from settings import *


@pytest.fixture(scope='function')
def fixed_token_cal(FixedToken):
    fixed_token_cal = FixedToken.deploy({'from': accounts[0]})
    name = "Fixed Token Cal"
    symbol = "CAL"
    owner = accounts[0]

    fixed_token_cal.initToken(name, symbol, owner, AUCTION_TOKENS,  {'from': owner})
    assert fixed_token_cal.name() == name
    assert fixed_token_cal.symbol() == symbol
    assert fixed_token_cal.totalSupply() == AUCTION_TOKENS
    assert fixed_token_cal.balanceOf(owner) == AUCTION_TOKENS

    return fixed_token_cal

@pytest.fixture(scope='function')
def fixed_token_staked(FixedToken):
    fixed_token_staked = FixedToken.deploy({'from': accounts[0]})
    name = "Fixed Token Staked"
    symbol = "FTS"
    owner = accounts[0]

    fixed_token_staked.initToken(name, symbol, owner, AUCTION_TOKENS,  {'from': owner})
    assert fixed_token_staked.name() == name
    assert fixed_token_staked.symbol() == symbol
    assert fixed_token_staked.totalSupply() == AUCTION_TOKENS
    assert fixed_token_staked.balanceOf(owner) == AUCTION_TOKENS

    return fixed_token_staked

def test_create_liquidity_farm(MasterChef,miso_recipe_03,fixed_token_cal,miso_access_controls):
    
    tokens_to_farm = 1000 * TENPOW18
    rewards_per_block = 1 * TENPOW18
    # Define the start time relative to sales
    start_block =  len(chain) + 10
    wallet = accounts[4]
    dev_addr = wallet
    fixed_token_cal.approve(miso_recipe_03,tokens_to_farm,{"from":accounts[0]})
    miso_access_controls.addSmartContractRole(miso_recipe_03,{"from":accounts[0]})
    master_chef = miso_recipe_03.createLiquidityFarm(
        fixed_token_cal,
        tokens_to_farm,
        rewards_per_block,
        start_block,
        dev_addr,
        fixed_token_staked,
        100,
        miso_access_controls,
        {"from":accounts[0]})
    
    master_chef = MasterChef.at(master_chef.return_value)

    master_chef

def test_create_token_farm(MasterChef,miso_recipe_03,fixed_token_staked,fixed_token_cal,miso_access_controls):
    
    tokens_to_farm = 1000 * TENPOW18
    rewards_per_block = 1 * TENPOW18
    # Define the start time relative to sales
    start_block =  len(chain) + 10
    wallet = accounts[4]
    dev_addr = wallet
    fixed_token_cal.approve(miso_recipe_03,tokens_to_farm,{"from":accounts[0]})
    miso_access_controls.addSmartContractRole(miso_recipe_03,{"from":accounts[0]})
    master_chef = miso_recipe_03.createTokenFarm(
        fixed_token_cal,
        tokens_to_farm,
        rewards_per_block,
        start_block,
        dev_addr,
        fixed_token_staked,
        100,
        miso_access_controls,
        {"from":accounts[0]})
    
    master_chef = MasterChef.at(master_chef.return_value)

    master_chef    

