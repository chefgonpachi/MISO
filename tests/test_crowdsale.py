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

############## Buy Tokens Test #############################
@pytest.fixture(scope='function')
def buy_tokens(crowdsale):
    totalWeiRaised = 0
    token_buyer =  accounts[1]
    eth_to_transfer = 5 * TENPOW18
    totalWeiRaised += eth_to_transfer
    tx = crowdsale.buyTokens(token_buyer, {"value": eth_to_transfer, "from": token_buyer})
    assert 'TokensPurchased' in tx.events
    assert crowdsale.weiRaised() == totalWeiRaised
    assert crowdsale.goalReached() == False

    token_buyer =  accounts[2]
    eth_to_transfer = 5 * TENPOW18
    totalWeiRaised += eth_to_transfer
    tx = crowdsale.buyTokens(token_buyer, {"value": eth_to_transfer, "from": token_buyer})
    assert 'TokensPurchased' in tx.events
    assert crowdsale.weiRaised() == totalWeiRaised
    assert crowdsale.goalReached() == True

def test_buy_tokens_with_receive(crowdsale):
    token_buyer = accounts[3]
    eth_to_transfer = 5 * TENPOW18
    tx = token_buyer.transfer(crowdsale, eth_to_transfer)
    assert 'TokensPurchased' in tx.events
    assert crowdsale.goalReached() == False


############## Buy Tokens Test #############################
def buy_token_helper(crowdsale, beneficiary, token_buyer, amount):
    eth_to_transfer = amount
    tx = crowdsale.buyTokens(beneficiary, {"value": eth_to_transfer, "from": token_buyer})
    assert 'TokensPurchased' in tx.events  
    return crowdsale

############## INIT Test ###################################
def test_init_done_again(crowdsale, mintable_token):
    mintable_token.mint(accounts[0], AUCTION_TOKENS, {"from": accounts[0]})
    assert mintable_token.balanceOf(accounts[0]) == AUCTION_TOKENS
    start_time = chain.time() + 10
    end_time = start_time + CROWDSALE_TIME
    wallet = accounts[4]
    with reverts():
        crowdsale.initCrowdsale(accounts[0], mintable_token, CROWDSALE_TOKENS, start_time, end_time, CROWDSALE_RATE, CROWDSALE_GOAL, wallet, {"from": accounts[0]})

############## INIT Test ###################################
def test_init_goal_greater_than_total_tokens(crowdsale, mintable_token):
    mintable_token.mint(accounts[0], AUCTION_TOKENS, {"from": accounts[0]})
    assert mintable_token.balanceOf(accounts[0]) == AUCTION_TOKENS
    start_time = chain.time() + 10
    end_time = start_time + CROWDSALE_TIME
    wallet = accounts[4]
    goal = 10*TENPOW18
    total_token = 100 * TENPOW18
    rate = 100
    with reverts():
        crowdsale.initCrowdsale(accounts[0], mintable_token, total_token, start_time, end_time, rate, goal, wallet, {"from": accounts[0]})

############## Buy Tokens Test #############################
def test_buy_token_with_zero_address(crowdsale):
    token_buyer =  ZERO_ADDRESS
    eth_to_transfer = 5 * TENPOW18
    with reverts():
        crowdsale.buyTokens(token_buyer, {"value": eth_to_transfer, "from": accounts[0]})

############## Buy Tokens Test #############################
def test_buy_token_multiple_times_goal_not_reached(crowdsale):
    totalWeiRaised = 0
    beneficiary = accounts[1]
    token_buyer = accounts[1]
    eth_to_transfer = 2 * TENPOW18
    tokens_to_beneficiary = eth_to_transfer * crowdsale.rate()
    totalWeiRaised += eth_to_transfer

    crowdsale = buy_token_helper(crowdsale, beneficiary,token_buyer, eth_to_transfer)
    assert crowdsale.weiRaised() == totalWeiRaised
    assert crowdsale.balanceOf(beneficiary) == tokens_to_beneficiary

    beneficiary = accounts[2]
    token_buyer = accounts[2]
    eth_to_transfer = 2 * TENPOW18
    tokens_to_beneficiary = eth_to_transfer * crowdsale.rate()
    totalWeiRaised += eth_to_transfer
    crowdsale = buy_token_helper(crowdsale, beneficiary,token_buyer,eth_to_transfer)
    assert crowdsale.weiRaised() == totalWeiRaised
    assert crowdsale.balanceOf(beneficiary) == tokens_to_beneficiary

    return crowdsale

############## Buy Tokens Test #############################
def test_buy_token_after_end_time(crowdsale):
    beneficiary = accounts[1]
    token_buyer = accounts[1]
    chain.sleep(CROWDSALE_TIME)
    eth_to_transfer = 2 * TENPOW18
    with reverts():
        crowdsale.buyTokens(beneficiary, {"value": eth_to_transfer, "from": token_buyer})

############## Buy Tokens Test #############################
def test_buy_token_greater_than_total_tokens(crowdsale, buy_tokens):
    beneficiary = accounts[3]
    token_buyer = accounts[3]
    eth_to_transfer = 1 * TENPOW18
    with reverts():
        crowdsale.buyTokens(beneficiary, {"value": eth_to_transfer, "from": token_buyer})

############## Buy Tokens Test #############################
def test_buy_token_with_zero_value(crowdsale, buy_tokens):
    beneficiary = accounts[3]
    token_buyer = accounts[3]
    eth_to_transfer = 0 * TENPOW18
    with reverts():
        crowdsale.buyTokens(beneficiary, {"value": eth_to_transfer, "from": token_buyer})

################ Withdraw Token Test##########################
def test_withdraw_tokens_goal_reached(crowdsale,buy_tokens,mintable_token):
    beneficiary = accounts[1]
    token_buyer = accounts[1]
    chain.sleep(CROWDSALE_TIME)
    balance_token_before_withdraw = crowdsale.balanceOf(beneficiary)
    crowdsale.withdrawTokens(beneficiary, {"from": token_buyer})
    assert crowdsale.balanceOf(beneficiary) == 0
    assert mintable_token.balanceOf(beneficiary) == balance_token_before_withdraw

################ Withdraw Token Test##########################
def test_withdraw_tokens_goal_not_reached(crowdsale):
    crowdsale = test_buy_token_multiple_times_goal_not_reached(crowdsale)
    beneficiary = accounts[1]
    token_buyer = accounts[1]
    chain.sleep(CROWDSALE_TIME)
    balance_wei_before_withdraw = beneficiary.balance()
    crowdsale.withdrawTokens(beneficiary, {"from": token_buyer})
    balance_wei_after_withdraw = beneficiary.balance()
    assert crowdsale.balanceOf(beneficiary) == 0
    eth_to_transfer = 2 * TENPOW18 
    assert balance_wei_after_withdraw == balance_wei_before_withdraw + eth_to_transfer 

################ Withdraw Token Test##########################
def test_withdraw_tokens_has_not_closed(crowdsale,buy_tokens):
    beneficiary = accounts[1]
    token_buyer = accounts[1]
    with reverts():
        crowdsale.withdrawTokens(beneficiary, {"from": token_buyer})

################ Withdraw Token Test##########################
def test_withdraw_tokens_wrong_beneficiary(crowdsale,buy_tokens):  
    beneficiary = accounts[2]
    token_buyer = accounts[1] 
    with reverts():
        crowdsale.withdrawTokens(beneficiary, {"from": token_buyer})
        
def test_crowdsale_tokenBalance(crowdsale, mintable_token):
       assert mintable_token.balanceOf(crowdsale) == CROWDSALE_TOKENS

def test_crowdsale_buyTokensExtra(crowdsale):
    token_buyer =  accounts[2]
    eth_to_transfer = crowdsale.goal() + 1

    with reverts():
        crowdsale.buyTokens(token_buyer, {"value": eth_to_transfer})

def test_crowdsale_balanceOf(crowdsale, mintable_token, buy_tokens):
    assert crowdsale.balanceOf(accounts[1]) == crowdsale.rate() * 5 * TENPOW18

def test_crowdsale_finalize(crowdsale, buy_tokens):
    old_balance = accounts[4].balance()
    chain.sleep(CROWDSALE_TIME)
    crowdsale_balance = crowdsale.balance()
    tx = crowdsale.finalize({"from": accounts[0]})
    assert 'CrowdsaleFinalized' in tx.events
    assert accounts[4].balance() == old_balance + crowdsale_balance


# def test_crowdsale_withdrawTokens(crowdsale, mintable_token, buy_tokens):
#     chain.sleep(CROWDSALE_TIME)
#     assert mintable_token.balanceOf(crowdsale)
#     crowdsale.withdrawTokens(accounts[1], {"from": accounts[1]})
    
