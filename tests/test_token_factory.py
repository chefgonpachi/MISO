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



########## TEST CREATE TOKEN ###################
def test_create_token(FixedToken,token_factory):
    name = "Fixed Token"
    symbol = "FXT"
    template_id = 1 # Fixed Token Template
    test_tokens = 100 * TENPOW18 # Fixed Token Template
    token = token_factory.deployToken(template_id, {"from":accounts[0]}).return_value
    #assert "TokenCreated" in token.events 

    token = FixedToken.at(token)
    _data = token.getInitData(name, symbol, accounts[0], test_tokens)
    token = token_factory.createToken(template_id, _data,{"from":accounts[0]}).return_value

    token = FixedToken.at(token)
    assert token.balanceOf(accounts[0]) == test_tokens
    
    




def test_add_token_template_wrong_operator(token_factory, fixed_token_template):
    with reverts():
        token_factory.addTokenTemplate(fixed_token_template, {"from": accounts[2]})

def test_number_of_tokens(token_factory):
    name = "Fixed Token"
    symbol = "FXT"
    template_id = 1 # Fixed Token Template
    test_tokens = 100 * TENPOW18 # Fixed Token Template

    number_of_tokens_before = token_factory.numberOfTokens()

    tx = token_factory.createToken(name, symbol, template_id, accounts[0], test_tokens)
    assert "TokenCreated" in tx.events  

    name = "Mintable Token"
    symbol = "MNT"
    template_id = 2 # Mintable Token Template
    test_tokens = 0

    tx = token_factory.createToken(name, symbol, template_id, accounts[0], test_tokens)
    assert "TokenCreated" in tx.events  

    assert number_of_tokens_before + 2 == token_factory.numberOfTokens() 

def test_remove_token_template(token_factory):
    template_id = 1 # Fixed Token Template
    tx = token_factory.removeTokenTemplate(template_id,{"from": accounts[0]})

    assert "TokenTemplateRemoved" in tx.events
    assert token_factory.getTokenTemplate(template_id) == ZERO_ADDRESS
    