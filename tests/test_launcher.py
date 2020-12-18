import pytest
from brownie import accounts, web3, Wei, reverts, chain
from brownie.convert import to_address
from settings import *

# reset the chain after every test case
@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass

@pytest.fixture(scope='function')
def depositEth(launcher, weth_token):
    assert weth_token.balance() == 0
    deposit_amount = 10 * TENPOW18
    launcher.depositETH({"from": accounts[0], "value": deposit_amount})
    assert weth_token.balance() == deposit_amount
    assert weth_token.totalSupply() == deposit_amount
    assert launcher.getWethBalance() == deposit_amount

@pytest.fixture(scope='function')
def depositTokens(launcher, mintable_token):
    assert mintable_token.balance() == 0
    
    amount_to_mint = 1000 * TENPOW18
    mintable_token.mint(accounts[0], amount_to_mint, {'from': accounts[0]})
    assert mintable_token.balanceOf(accounts[0]) == amount_to_mint

    deposit_amount = amount_to_mint
    mintable_token.approve(launcher, deposit_amount, {"from": accounts[0]})
    tx = launcher.depositTokens(deposit_amount, {"from": accounts[0]})
    assert "Transfer" in tx.events
    assert launcher.getTokenBalance() == deposit_amount

def test_addLiquidityToPool(launcher, UniswapV2Pair, UniswapV2Factory, depositEth, depositTokens):
    tx = launcher.addLiquidityToPool({"from": accounts[0]})
    print("liquidity:", tx.return_value)
    assert launcher.getTokenBalance() == 0
    assert launcher.getWethBalance() == 0
    factory = UniswapV2Factory.at(launcher.factory())

    print("pair:", factory.getPair(launcher.token(), launcher.WETH()))
    
def test_addLiquidityToPoolFromNotOperator(launcher, UniswapV2Pair, UniswapV2Factory, depositEth, depositTokens):
    with reverts():
        launcher.addLiquidityToPool({"from": accounts[1]})
    