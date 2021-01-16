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
    deposit_eth = ETH_TO_DEPOSIT
    pool_liquidity.depositETH({"from": accounts[0], "value": deposit_eth})
    assert weth_token.balance() == deposit_eth
    assert weth_token.totalSupply() == deposit_eth
    assert pool_liquidity.getWethBalance() == deposit_eth

@pytest.fixture(scope='function')
def depositTokens(pool_liquidity, mintable_token):
    assert mintable_token.balance() == 0
    mintable_token.mint(accounts[0], TOKENS_TO_MINT, {'from': accounts[0]})
    assert mintable_token.balanceOf(accounts[0]) == TOKENS_TO_MINT

    deposit_amount = TOKENS_TO_MINT
    mintable_token.approve(pool_liquidity, deposit_amount, {"from": accounts[0]})
    tx = pool_liquidity.depositTokens(deposit_amount, {"from": accounts[0]})
    assert "Transfer" in tx.events
    assert pool_liquidity.getTokenBalance() == deposit_amount

@pytest.fixture(scope='function')
def launchLiquidityPool(pool_liquidity, UniswapV2Pair, UniswapV2Factory, depositEth, depositTokens):
    chain.sleep(POOL_LAUNCH_DEADLINE)
    tx = pool_liquidity.launchLiquidityPool({"from": accounts[0]})

    assert "LiquidityAdded" in tx.events
    assert pool_liquidity.getTokenBalance() == 0
    assert pool_liquidity.getWethBalance() == 0
    
def test_launchLiquidityPoolFromNotOperator(pool_liquidity, depositEth, depositTokens):
    with reverts():
        pool_liquidity.launchLiquidityPool({"from": accounts[1]})

# def test_zapEth(pool_liquidity, weth_token, UniswapV2Pair, mintable_token, launchLiquidityPool):
#     # mintable_token.mint(accounts[0], TOKENS_TO_MINT, {'from': accounts[0]})
#     # mintable_token.approve(pool_liquidity, TOKENS_TO_MINT, {"from": accounts[0]})
#     # tokenPair = UniswapV2Pair.at(pool_liquidity.tokenWETHPair())

#     tx = pool_liquidity.zapEth({"from": accounts[0], "value": 1*TENPOW18})
#     assert "LiquidityAdded" in tx.events

# def test_zapEthWithoutPool(pool_liquidity, weth_token, UniswapV2Pair, mintable_token):
#     mintable_token.mint(accounts[0], TOKENS_TO_MINT, {'from': accounts[0]})
#     mintable_token.approve(pool_liquidity, TOKENS_TO_MINT, {"from": accounts[0]})

#     with reverts("Liquidity is not added to pool"):
#         pool_liquidity.zapEth({"from": accounts[0], "value": 1*TENPOW18})

# def test_zapEthAfterUnlockTimeExpired(pool_liquidity, weth_token, UniswapV2Pair, mintable_token, launchLiquidityPool):
#     mintable_token.mint(accounts[0], TOKENS_TO_MINT, {'from': accounts[0]})
#     mintable_token.approve(pool_liquidity, TOKENS_TO_MINT, {"from": accounts[0]})
#     chain.sleep(pool_liquidity.locktime())

#     with reverts("The unlock time is passed"):
#         pool_liquidity.zapEth({"from": accounts[0], "value": 1*TENPOW18})

def test_withdrawDepositsWithoutExpiration(pool_liquidity, depositEth, depositTokens):
    with reverts("Timer has not yet expired"):
        pool_liquidity.withdrawDeposits({"from": accounts[0]})

def test_withdrawLPTokens(pool_liquidity, UniswapV2Pair, launchLiquidityPool):
    chain.sleep(pool_liquidity.locktime())
    wallet = pool_liquidity.wallet()
    tokenPair = UniswapV2Pair.at(pool_liquidity.tokenWETHPair())
    walletLPBalanceBeforeW = tokenPair.balanceOf(wallet)
    poolLiquidityBalanceBeforeW = tokenPair.balanceOf(pool_liquidity)
    
    tx = pool_liquidity.withdrawLPTokens({"from": accounts[0]})
    withdrawnLiquidity = tx.return_value

    assert poolLiquidityBalanceBeforeW - withdrawnLiquidity == tokenPair.balanceOf(pool_liquidity)
    assert walletLPBalanceBeforeW + withdrawnLiquidity == tokenPair.balanceOf(wallet)

def test_withdrawLPTokensWithLiquidityLocked(pool_liquidity, launchLiquidityPool):
    with reverts("Liquidity is locked"):
        pool_liquidity.withdrawLPTokens({"from": accounts[0]})

def test_withdrawLPTokensWithoutLiquidity(pool_liquidity):
    chain.sleep(pool_liquidity.locktime())

    with reverts("Liquidity must be greater than 0"):
        pool_liquidity.withdrawLPTokens({"from": accounts[0]})


def test_launchLiquidityPoolAfterContractExpires(pool_liquidity, depositEth, depositTokens):
    chain.sleep(POOL_LAUNCH_WINDOW)
    with reverts():
        pool_liquidity.launchLiquidityPool({"from": accounts[0]})

def test_withdrawDepositsWithLiquidity(pool_liquidity, launchLiquidityPool):
    chain.sleep(POOL_LAUNCH_WINDOW)

    with reverts("Liquidity is locked"):
        pool_liquidity.withdrawDeposits({"from": accounts[0]})

def test_withdrawDeposits(pool_liquidity, weth_token, mintable_token, depositEth, depositTokens):
    chain.sleep(POOL_LAUNCH_DEADLINE+POOL_LAUNCH_WINDOW)

    pool_liquidity.withdrawDeposits({"from": accounts[0]})

    assert mintable_token.balanceOf(pool_liquidity) == 0
    assert weth_token.balanceOf(pool_liquidity) == 0
