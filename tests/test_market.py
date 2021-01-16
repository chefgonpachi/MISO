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
    # assert fixed_token_cal.owner() == owner
    # changed to access controls

    assert fixed_token_cal.totalSupply() == AUCTION_TOKENS
    assert fixed_token_cal.balanceOf(owner) == AUCTION_TOKENS

    return fixed_token_cal

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

def test_market_add_auction_template_twice(auction_factory,crowdsale_template,crowdsale_factory_template):
    with reverts():
        auction_factory.addAuctionTemplate(crowdsale_template,{"from": accounts[0]})

def test_remove_auction_template(auction_factory,crowdsale_template):
    template_id = 2
    auction_factory.removeAuctionTemplate(template_id,{"from":accounts[0]})
    return auction_factory

def test_add_again_after_removal(auction_factory,crowdsale_template):
    auction_factory = test_remove_auction_template(auction_factory,crowdsale_template)
    auction_factory.addAuctionTemplate(crowdsale_template,{"from": accounts[0]})


def test_market_create_auction(auction_factory, auction_factory_template,fixed_token_cal,dutch_auction_template):
    assert fixed_token_cal.balanceOf(accounts[0]) == AUCTION_TOKENS
    
    template_id = auction_factory.getTemplateId(dutch_auction_template)
    start_date = chain.time() + 10
    end_date = start_date + AUCTION_TIME
    wallet = accounts[1]
    
    fixed_token_cal.approve(auction_factory, AUCTION_TOKENS, {"from": accounts[0]})
    auction_factory.createAuction(fixed_token_cal, AUCTION_TOKENS, start_date, end_date, ETH_ADDRESS, AUCTION_START_PRICE, AUCTION_RESERVE, wallet, template_id,{"from": accounts[0]})
    assert auction_factory.numberOfAuctions() == 1

def test_create_crowdsale(auction_factory,crowdsale_factory_template, fixed_token_cal, crowdsale_template):
    assert fixed_token_cal.balanceOf(accounts[0]) == AUCTION_TOKENS
    start_time = chain.time() + 10
    end_time = start_time + CROWDSALE_TIME
    wallet = accounts[4]

    
    template_id = auction_factory.getTemplateId(crowdsale_template)
    fixed_token_cal.approve(auction_factory, CROWDSALE_TOKENS, {"from": accounts[0]})

    auction_factory.createCrowdsale(fixed_token_cal, CROWDSALE_TOKENS, ETH_ADDRESS, start_time, end_time, CROWDSALE_RATE, CROWDSALE_GOAL, wallet,template_id, {"from": accounts[0]})
