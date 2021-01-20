from brownie import accounts, web3, Wei, reverts, chain
from brownie.network.transaction import TransactionReceipt
from brownie.convert import to_address
import pytest
from brownie import Contract
from settings import *


# AG: What if the token is not minable during an auction? Should commit tokens to auction

# reset the chain after every test case
@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass


def test_dutch_auction_totalTokensCommitted(dutch_auction):
    assert dutch_auction.totalTokensCommitted() == 0


def test_dutch_auction_commitEth(dutch_auction):
    token_buyer =  accounts[2]
    eth_to_transfer = 20 * TENPOW18
    tx = token_buyer.transfer(dutch_auction, eth_to_transfer)
    assert 'AddedCommitment' in tx.events

    
def test_dutch_auction_tokensClaimable(dutch_auction):
    assert dutch_auction.tokensClaimable(accounts[2]) == 0
    token_buyer =  accounts[2]
    eth_to_transfer = 20 * TENPOW18
    token_buyer.transfer(dutch_auction, eth_to_transfer)
    chain.sleep(AUCTION_TIME+100)
    chain.mine()
    assert dutch_auction.tokensClaimable(accounts[2]) == AUCTION_TOKENS

    
def test_dutch_auction_twoPurchases(dutch_auction):
    assert dutch_auction.tokensClaimable(accounts[2]) == 0
    token_buyer_a=  accounts[2]
    token_buyer_b =  accounts[3]

    eth_to_transfer = 20 * TENPOW18
    tx = token_buyer_a.transfer(dutch_auction, 20 * TENPOW18)
    assert 'AddedCommitment' in tx.events
    tx = token_buyer_b.transfer(dutch_auction, 80 * TENPOW18)
    assert 'AddedCommitment' in tx.events

    # AG need to double check these numbers
    # assert round(dutch_auction.tokensClaimable(token_buyer_a) * AUCTION_TOKENS / TENPOW18**2) == 2000
    # assert round(dutch_auction.tokensClaimable(token_buyer_b) * AUCTION_TOKENS / TENPOW18**2) == 8000


def test_dutch_auction_tokenPrice(dutch_auction):
    assert dutch_auction.tokenPrice() == 0
    token_buyer=  accounts[2]
    eth_to_transfer = 20 * TENPOW18
    tx = token_buyer.transfer(dutch_auction, eth_to_transfer)
    assert 'AddedCommitment' in tx.events
    assert dutch_auction.tokenPrice() == eth_to_transfer * TENPOW18 / AUCTION_TOKENS

def test_dutch_auction_ended(dutch_auction):

    assert dutch_auction.auctionEnded({'from': accounts[0]}) == False
    chain.sleep(AUCTION_TIME)
    chain.mine()
    assert dutch_auction.auctionEnded({'from': accounts[0]}) == True


def test_dutch_auction_claim(dutch_auction):
    token_buyer = accounts[2]
    eth_to_transfer = 100 * TENPOW18

    with reverts():
        dutch_auction.withdrawTokens({'from': accounts[0]})
    
    token_buyer.transfer(dutch_auction,eth_to_transfer)
    assert dutch_auction.finalized({'from': accounts[0]}) == False

    chain.sleep(AUCTION_TIME+100)
    chain.mine()
    assert dutch_auction.auctionSuccessful({'from': accounts[0]}) == True

    dutch_auction.withdrawTokens({'from': token_buyer})

    # Check for multiple withdraws
    with reverts():
        dutch_auction.withdrawTokens({'from': token_buyer})
        dutch_auction.withdrawTokens({'from': accounts[0]})

    dutch_auction.finalizeAuction({'from': accounts[0]})
    with reverts():
        dutch_auction.finalizeAuction({'from': accounts[0]})

def test_dutch_auction_claim_not_enough(dutch_auction):
    token_buyer = accounts[2]
    eth_to_transfer = 0.01 * TENPOW18

    token_buyer.transfer(dutch_auction,eth_to_transfer)
    chain.sleep(AUCTION_TIME+100)
    chain.mine()
    dutch_auction.withdrawTokens({'from': token_buyer})
    dutch_auction.finalizeAuction({"from": accounts[0]})

def test_dutch_auction_clearingPrice(dutch_auction):
    chain.sleep(100)
    chain.mine()
    assert dutch_auction.clearingPrice() <= AUCTION_START_PRICE
    assert dutch_auction.clearingPrice() > AUCTION_RESERVE

    chain.sleep(AUCTION_TIME)
    chain.mine()
    assert dutch_auction.clearingPrice() == AUCTION_RESERVE


############### Commit Eth Test ###############################

def test_dutch_auction_commit_eth(dutch_auction_cal):
    assert dutch_auction_cal.tokensClaimable(accounts[2]) == 0
    token_buyer_a=  accounts[2]
    token_buyer_b =  accounts[3]

    tx = token_buyer_a.transfer(dutch_auction_cal, 20 * TENPOW18)
    assert 'AddedCommitment' in tx.events
    
    tx = token_buyer_b.transfer(dutch_auction_cal, 90 * TENPOW18)
    assert 'AddedCommitment' in tx.events
    #### Initial balance of token_buyer_b = 100. Then transfer 90 but
    #### only 80 can be transfered as max is 100.
    #### 100 - 80 = 20
    assert round(token_buyer_b.balance()/TENPOW18) == 20

############## Calculate Commitment test ######################
def test_dutch_auction_calculate_commitment(dutch_auction_cal):
    assert dutch_auction_cal.tokensClaimable(accounts[2]) == 0
    token_buyer_a=  accounts[2]
    token_buyer_b =  accounts[3]
    
    tx = token_buyer_a.transfer(dutch_auction_cal, 20 * TENPOW18)
    assert 'AddedCommitment' in tx.events
    tx = token_buyer_b.transfer(dutch_auction_cal, 70 * TENPOW18)
    assert 'AddedCommitment' in tx.events
    commitment_not_max = dutch_auction_cal.calculateCommitment(5*TENPOW18, {"from":accounts[4]})
    assert round(commitment_not_max/TENPOW18) == 5
    
    commitment_more_than_max = dutch_auction_cal.calculateCommitment(30*TENPOW18, {"from":accounts[4]})
    assert round(commitment_more_than_max/TENPOW18) == 10

################# Helper Test Function  #############################

@pytest.fixture(scope='function', autouse=True)
def dutch_auction_cal(DutchAuction, fixed_token_cal):
    start_price = 1 * TENPOW18
    auction_tokens = 100 * TENPOW18
    
    start_time = chain.time() + 10
    end_time = start_time + AUCTION_TIME
    wallet = accounts[1]
    dutch_auction_cal = DutchAuction.deploy({"from": accounts[5]})

    fixed_token_cal.approve(dutch_auction_cal, auction_tokens, {"from": accounts[5]})

    dutch_auction_cal.initAuction(accounts[5], fixed_token_cal, auction_tokens, start_time, end_time, ETH_ADDRESS, start_price, AUCTION_RESERVE, wallet, {"from": accounts[5]})
    assert dutch_auction_cal.clearingPrice() == start_price
    chain.sleep(10)
    return dutch_auction_cal 

################# Helper  Test Function #############################
@pytest.fixture(scope='function', autouse=True)
def fixed_token_cal(FixedToken):
    fixed_token_cal = FixedToken.deploy({'from': accounts[5]})
    name = "Fixed Token Cal"
    symbol = "CAL"
    owner = accounts[5]

    fixed_token_cal.initToken(name, symbol, owner, 250*TENPOW18, {'from': owner})

    return fixed_token_cal


######## Test to commit with tokens   ###########################
#### fixed_token_cal -> token to auction
#### fixed_token_ime -> token to pay by
def test_dutch_auction_commit_tokens(dutch_auction_pay_by_token,fixed_token_ime): 
    account_payer = accounts[6] 
    
    fixed_token_ime.approve(accounts[5], 50*TENPOW18, {"from": accounts[5]})
    fixed_token_ime.transferFrom(accounts[5], account_payer, 20*TENPOW18,{"from":accounts[5]})
    
    assert fixed_token_ime.balanceOf(account_payer) == 20 * TENPOW18
    
    fixed_token_ime.approve(dutch_auction_pay_by_token, 20 * TENPOW18,{"from":account_payer})
    dutch_auction_pay_by_token.commitTokens(5 * TENPOW18, {"from":account_payer})

    assert fixed_token_ime.balanceOf(dutch_auction_pay_by_token) ==  5 * TENPOW18   

    


################# Helper Test Function To pay By Tokens #############################

@pytest.fixture(scope='function', autouse=True)
def dutch_auction_pay_by_token(DutchAuction, fixed_token_ime, fixed_token_cal):
    start_price = 1 * TENPOW18
    auction_tokens = 100 * TENPOW18
    
    start_time = chain.time() + 10
    end_time = start_time + AUCTION_TIME
    wallet = accounts[1]
    dutch_auction_pay_by_token = DutchAuction.deploy({"from": accounts[5]})

    fixed_token_cal.approve(dutch_auction_pay_by_token, auction_tokens, {"from": accounts[5]})

    dutch_auction_pay_by_token.initAuction(accounts[5], fixed_token_cal, auction_tokens, start_time, end_time, fixed_token_ime, start_price, AUCTION_RESERVE, wallet, {"from": accounts[5]})
    assert dutch_auction_pay_by_token.clearingPrice() == start_price
    chain.sleep(10)
    return dutch_auction_pay_by_token 

################# Helper Test Function To pay By Tokens #############################
@pytest.fixture(scope='function', autouse=True)
def fixed_token_ime(FixedToken):
    fixed_token_ime = FixedToken.deploy({'from': accounts[5]})
    name = "Fixed Token IME"
    symbol = "IME"
    owner = accounts[5]

    fixed_token_ime.initToken(name, symbol, owner,150*TENPOW18, {'from': owner})

    return fixed_token_ime 



