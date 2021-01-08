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
def test_create_token(token_factory):
    name = "Fixed Token"
    symbol = "FXT"
    template_id = 1 # Fixed Token Template
    tx = token_factory.createToken(name, symbol, template_id)
    assert "TokenCreated" in tx.events    

def test_add_token_template_wrong_operator(token_factory, fixed_token_template):
    with reverts():
        token_factory.addTokenTemplate(fixed_token_template, {"from": accounts[2]})

def test_number_of_tokens(token_factory):
    name = "Fixed Token"
    symbol = "FXT"
    template_id = 1 # Fixed Token Template
    tx = token_factory.createToken(name, symbol, template_id)
    assert "TokenCreated" in tx.events  

    name = "Mintable Token"
    symbol = "MNT"
    template_id = 2 # Mintable Token Template
    tx = token_factory.createToken(name, symbol, template_id)
    assert "TokenCreated" in tx.events  

    assert token_factory.numberOfTokens() == 2

def test_remove_token_template(token_factory):
    template_id = 1 # Fixed Token Template
    tx = token_factory.removeTokenTemplate(template_id,{"from": accounts[0]})

    assert "TokenTemplateRemoved" in tx.events
    assert token_factory.getTokenTemplate(template_id) == ZERO_ADDRESS
    