import pytest
from brownie import accounts
from settings import *

# reset the chain after every test case
@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass

# def test_create_token(fixed_token):
#     name = "Test Token"
#     symbol = "TT"
#     tx = fixed_token_factory.createToken(name, symbol, 1, {"from": accounts[0]})
#     assert "TokenCreated" in tx.events
#     assert fixed_token_factory.numberOfTokens() == 1
