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
def buy_tokens(crowdsale):
    token_buyer =  accounts[1]
    eth_to_transfer = 10 * TENPOW18
    tx = crowdsale.buyTokens(token_buyer, {"value": eth_to_transfer, "from": token_buyer})
    assert 'TokensPurchased' in tx.events
    assert crowdsale.weiRaised() == eth_to_transfer
    assert crowdsale.goalReached() == True


def test_crowdsale_tokenBalance(crowdsale, mintable_token):
       assert mintable_token.balanceOf(crowdsale) == CROWDSALE_TOKENS

def test_crowdsale_buyTokensExtra(crowdsale):
    token_buyer =  accounts[2]
    eth_to_transfer = crowdsale.goal() + 1

    with reverts():
        crowdsale.buyTokens(token_buyer, {"value": eth_to_transfer})

def test_crowdsale_balanceOf(crowdsale, mintable_token, buy_tokens):
    assert crowdsale.balanceOf(accounts[1]) == crowdsale.rate() * 10 * TENPOW18

def test_crowdsale_finalize(crowdsale, buy_tokens):
    old_balance = accounts[2].balance()
    chain.sleep(CROWDSALE_TIME)
    crowdsale_balance = crowdsale.balance()
    tx = crowdsale.finalize({"from": accounts[0]})
    assert 'CrowdsaleFinalized' in tx.events
    assert accounts[2].balance() == old_balance + crowdsale_balance


# def test_crowdsale_withdrawTokens(crowdsale, mintable_token, buy_tokens):
#     chain.sleep(CROWDSALE_TIME)
#     assert mintable_token.balanceOf(crowdsale)
#     crowdsale.withdrawTokens(accounts[1], {"from": accounts[1]})
    
