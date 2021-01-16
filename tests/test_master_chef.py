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

    fixed_token_cal.initToken(name, symbol, owner, AUCTION_TOKENS, {'from': owner})
    assert fixed_token_cal.name() == name
    assert fixed_token_cal.symbol() == symbol
    # assert fixed_token_cal.owner() == owner
    # changed to access controls

    assert fixed_token_cal.totalSupply() == AUCTION_TOKENS
    assert fixed_token_cal.balanceOf(owner) == AUCTION_TOKENS

    return fixed_token_cal

def test_create_farm(MasterChef,farm_factory, fixed_token_cal,miso_access_controls):
    rewards_per_block = 1 * TENPOW18
    # Define the start time relative to sales
    start_block =  len(chain) + 10
    wallet = accounts[4]
    dev_addr = wallet
    fixed_token_cal.approve(farm_factory, AUCTION_TOKENS, {"from": accounts[0]})
    tx = farm_factory.createFarm(fixed_token_cal,rewards_per_block,start_block,dev_addr,miso_access_controls,1,{"from":accounts[0]})

    assert "FarmCreated" in tx.events
    assert farm_factory.numberOfFarms() == 1
    farm_address = tx.events["FarmCreated"]["addr"] 
    farm = MasterChef.at(farm_address)
    farm.addToken(100, fixed_token_cal, False,{"from":accounts[0]})