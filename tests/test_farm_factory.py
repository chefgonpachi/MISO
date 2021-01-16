from brownie import accounts, web3, Wei, reverts, chain
from brownie.network.transaction import TransactionReceipt
from brownie.convert import to_address
import pytest
from brownie import Contract
from settings import *

# reset the chain after every test case
@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass

@pytest.fixture(scope='function')
def fixed_token_cal(FixedToken):
    fixed_token_cal = FixedToken.deploy({'from': accounts[0]})
    name = "Fixed Token Cal"
    symbol = "CAL"
    owner = accounts[0]

    fixed_token_cal.initToken(name, symbol, owner,AUCTION_TOKENS, {'from': owner})
    assert fixed_token_cal.name() == name
    assert fixed_token_cal.symbol() == symbol
    assert fixed_token_cal.totalSupply() == AUCTION_TOKENS
    assert fixed_token_cal.balanceOf(owner) == AUCTION_TOKENS

    return fixed_token_cal

@pytest.fixture(scope='function')
def farm_template_2(MasterChef):
    farm_template_2 = MasterChef.deploy({"from":accounts[0]})
    return farm_template_2


@pytest.fixture(scope='function')
def create_farm(farm_factory, fixed_token_cal,miso_access_controls):
    rewards_per_block = 1 * TENPOW18
    # Define the start time relative to sales
    start_block =  len(chain) + 10
    wallet = accounts[4]
    dev_addr = wallet
    fixed_token_cal.approve(farm_factory, AUCTION_TOKENS, {"from": accounts[0]})
    tx = farm_factory.createFarm(fixed_token_cal,rewards_per_block,start_block,dev_addr,miso_access_controls,1,{"from":accounts[0]})

    assert "FarmCreated" in tx.events
    assert farm_factory.numberOfFarms() == 1

def test_farm_factory_wrong_operator_add_template(create_farm,farm_factory,farm_template_2):
    with reverts():
        farm_factory.addFarmTemplate(farm_template_2,{"from":accounts[5]})

def test_farm_factory_remove_farm_template(farm_factory,farm_template_2):
    tx = farm_factory.addFarmTemplate(farm_template_2,{"from":accounts[0]})
    template_id = tx.events["FarmTemplateAdded"]["templateId"]
    assert template_id == 2
    tx = farm_factory.removeFarmTemplate(template_id, {"from":accounts[0]})
    assert "FarmTemplateRemoved" in tx.events 

def test_farm_factory_get_farm_template(farm_factory,farm_template):
    get_farm_template = farm_factory.getFarmTemplate(1)
    assert get_farm_template == farm_template

def test_farm_factory_get_farm_template_id(farm_factory,farm_template_2):
    tx = farm_factory.addFarmTemplate(farm_template_2,{"from":accounts[0]})
    template_id = tx.events["FarmTemplateAdded"]["templateId"]
    assert farm_factory.getTemplateId(farm_template_2) == template_id
    print(farm_factory.numberOfFarms())

""" ###########AUCTION FACTORY


@pytest.fixture(scope='function')
def auction_factory_template(auction_factory,dutch_auction_template):
    #tx = auction_factory.addAuctionTemplate(dutch_auction_template, {"from": accounts[0]})
    template_id = 1
   # assert "AuctionTemplateAdded" in tx.events
    dutch_auction_template  =  auction_factory.getAuctionTemplate(template_id)

    assert auction_factory.getTemplateId(dutch_auction_template) == template_id

@pytest.fixture(scope='function')
def crowdsale_factory_template(auction_factory,crowdsale_template):
   # tx = auction_factory.addAuctionTemplate(crowdsale_template, {"from": accounts[0]})
    #assert "AuctionTemplateAdded" in tx.events
    template_id = 2
    
    crowdsale_template = auction_factory.getAuctionTemplate(template_id)
    assert auction_factory.getTemplateId(crowdsale_template) == template_id

def test_create_auction(auction_factory, auction_factory_template,fixed_token_cal,dutch_auction_template):
    assert fixed_token_cal.balanceOf(accounts[0]) == AUCTION_TOKENS
    
    template_id = auction_factory.getTemplateId(dutch_auction_template)
    start_date = chain.time() + 10
    end_date = start_date + AUCTION_TIME
    wallet = accounts[1]
    
    fixed_token_cal.approve(auction_factory, AUCTION_TOKENS, {"from": accounts[0]})
    auction_factory.createAuction(fixed_token_cal, AUCTION_TOKENS, start_date, end_date, ETH_ADDRESS, AUCTION_START_PRICE, AUCTION_RESERVE, wallet, template_id,{"from": accounts[0]})
    
def test_create_crowdsale(auction_factory,crowdsale_factory_template, fixed_token_cal, crowdsale_template):
    assert fixed_token_cal.balanceOf(accounts[0]) == AUCTION_TOKENS
    start_time = chain.time() + 10
    end_time = start_time + CROWDSALE_TIME
    wallet = accounts[4]

    
    template_id = auction_factory.getTemplateId(crowdsale_template)
    fixed_token_cal.approve(auction_factory, CROWDSALE_TOKENS, {"from": accounts[0]})

    auction_factory.createCrowdsale(fixed_token_cal, CROWDSALE_TOKENS, ETH_ADDRESS, start_time, end_time, CROWDSALE_RATE, CROWDSALE_GOAL, wallet,template_id, {"from": accounts[0]}) """