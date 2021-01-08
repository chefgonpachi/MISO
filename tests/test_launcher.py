import pytest
from brownie import accounts, web3, Wei, reverts, chain
from brownie.convert import to_address
from settings import *

# reset the chain after every test case
@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass

@pytest.fixture(scope='function')
def depositEth(pool_liquidity, weth_token):
    assert weth_token.balance() == 0
    deposit_amount = 10 * TENPOW18
    pool_liquidity.depositETH({"from": accounts[0], "value": deposit_amount})
    assert weth_token.balance() == deposit_amount
    assert weth_token.totalSupply() == deposit_amount
    assert pool_liquidity.getWethBalance() == deposit_amount

@pytest.fixture(scope='function')
def depositTokens(pool_liquidity, mintable_token):
    assert mintable_token.balance() == 0
    
    amount_to_mint = 1000 * TENPOW18
    mintable_token.mint(accounts[0], amount_to_mint, {'from': accounts[0]})
    assert mintable_token.balanceOf(accounts[0]) == amount_to_mint

    deposit_amount = amount_to_mint
    mintable_token.approve(pool_liquidity, deposit_amount, {"from": accounts[0]})
    tx = pool_liquidity.depositTokens(deposit_amount, {"from": accounts[0]})
    assert "Transfer" in tx.events
    assert pool_liquidity.getTokenBalance() == deposit_amount

def test_addLiquidityToPool(pool_liquidity, UniswapV2Pair, UniswapV2Factory, depositEth, depositTokens):
    tx = pool_liquidity.addLiquidityToPool({"from": accounts[0]})
    print("liquidity:", tx.return_value)
    assert pool_liquidity.getTokenBalance() == 0
    assert pool_liquidity.getWethBalance() == 0
    factory = UniswapV2Factory.at(pool_liquidity.factory())

    print("pair:", factory.getPair(pool_liquidity.token(), pool_liquidity.WETH()))
    
def test_addLiquidityToPoolFromNotOperator(pool_liquidity, UniswapV2Pair, UniswapV2Factory, depositEth, depositTokens):
    with reverts():
        pool_liquidity.addLiquidityToPool({"from": accounts[1]})
    