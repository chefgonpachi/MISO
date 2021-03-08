import pytest
from brownie import accounts, web3, Wei, reverts, chain
from brownie.convert import to_address
from settings import *

# reset the chain after every test case
@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass

@pytest.fixture(scope='function')
def deposit_eth(pool_liquidity, weth_token):
    assert weth_token.balance() == 0
    deposit_eth = ETH_TO_DEPOSIT
    pool_liquidity.depositETH({"from": accounts[0], "value": deposit_eth})
    assert weth_token.balance() == deposit_eth
    assert weth_token.totalSupply() == deposit_eth
    assert pool_liquidity.getWethBalance() == deposit_eth

@pytest.fixture(scope='function')
def deposit_tokens(pool_liquidity, mintable_token):
    assert mintable_token.balance() == 0
    mintable_token.mint(accounts[0], TOKENS_TO_MINT, {'from': accounts[0]})
    assert mintable_token.balanceOf(accounts[0]) == TOKENS_TO_MINT

    deposit_amount = TOKENS_TO_MINT
    mintable_token.approve(pool_liquidity, deposit_amount, {"from": accounts[0]})
    tx = pool_liquidity.depositTokens(deposit_amount, {"from": accounts[0]})
    assert "Transfer" in tx.events
    assert pool_liquidity.getTokenBalance() == deposit_amount

@pytest.fixture(scope='function')
def launch_liquidity_pool(UniswapV2Pair, UniswapV2Factory, pool_liquidity, mintable_token, weth_token, deposit_eth, deposit_tokens):
    chain.sleep(POOL_LAUNCH_DEADLINE)
    tx = pool_liquidity.launchLiquidityPool({"from": accounts[0]})

    assert "LiquidityAdded" in tx.events
    assert pool_liquidity.getTokenBalance() == 0
    assert pool_liquidity.getWethBalance() == 0

    token_pair = UniswapV2Pair.at(pool_liquidity.tokenWETHPair())
    assert mintable_token.balanceOf(token_pair) == TOKENS_TO_MINT
    assert weth_token.balanceOf(token_pair) == ETH_TO_DEPOSIT

def _finalize_market_and_launch_lp(pool_liquidity, operator):
    pool_liquidity.finalizeMarketAndLaunchLiquidityPool({"from": operator})


# TODO - test failed, fix it
# def test_launchPoolWithoutAnyDeposits(pool_liquidity):
#     chain.sleep(POOL_LAUNCH_DEADLINE)
#     ret_value = pool_liquidity.launchLiquidityPool({"from": accounts[0]}).return_value
#     assert ret_value == 0

def test_launchLiquidityPoolFromNotOperator(pool_liquidity, deposit_eth, deposit_tokens):
    with reverts():
        pool_liquidity.launchLiquidityPool({"from": accounts[1]})

def test_depositEthAfterContractExpired(pool_liquidity, weth_token):
    deposit_eth = ETH_TO_DEPOSIT
    chain.sleep(POOL_LAUNCH_DEADLINE + POOL_LAUNCH_WINDOW)
    with reverts("MISOLaucher: Contract has expired"):
        pool_liquidity.depositETH({"from": accounts[0], "value": deposit_eth})

def test_depositTokensAfterContractExpired(pool_liquidity, mintable_token):
    deposit_eth = ETH_TO_DEPOSIT
    chain.sleep(POOL_LAUNCH_DEADLINE + POOL_LAUNCH_WINDOW)
    with reverts("MISOLaucher: Contract has expired"):
        pool_liquidity.depositETH({"from": accounts[0], "value": deposit_eth})

    mintable_token.mint(accounts[0], TOKENS_TO_MINT, {'from': accounts[0]})

    deposit_amount = TOKENS_TO_MINT
    mintable_token.approve(pool_liquidity, deposit_amount, {"from": accounts[0]})
    with reverts("MISOLaucher: Contract has expired"):    
        pool_liquidity.depositTokens(deposit_amount, {"from": accounts[0]})

def test_initPoolLiquidityAgain(pool_liquidity,public_access_controls, mintable_token, weth_token, uniswap_factory):
    deadline = chain.time() + POOL_LAUNCH_DEADLINE
    launch_window = POOL_LAUNCH_WINDOW
    locktime = POOL_LAUNCH_LOCKTIME
    
    with reverts():
        pool_liquidity.initPoolLiquidity(public_access_controls, mintable_token, weth_token, uniswap_factory, accounts[0], accounts[0], deadline, launch_window, locktime)

def test_initPoolLiquidityIncorrectLocktime(pool_liquidity,public_access_controls, mintable_token, weth_token, uniswap_factory):
    deadline = chain.time() + POOL_LAUNCH_DEADLINE
    launch_window = POOL_LAUNCH_WINDOW
    locktime = 100000000000
    with reverts("MISOLaucher: Enter an unix timestamp in seconds, not miliseconds"):
        pool_liquidity.initPoolLiquidity(public_access_controls, mintable_token, weth_token, uniswap_factory, accounts[0], accounts[0], deadline, launch_window, locktime)

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

def test_withdrawDepositsWithoutExpiration(pool_liquidity, deposit_eth, deposit_tokens):
    with reverts("MISOLaucher: Timer has not yet expired"):
        pool_liquidity.withdrawDeposits({"from": accounts[0]})

def test_withdrawLPTokens(pool_liquidity, UniswapV2Pair, launch_liquidity_pool):
    chain.sleep(pool_liquidity.locktime())
    wallet = pool_liquidity.wallet()
    tokenPair = UniswapV2Pair.at(pool_liquidity.tokenWETHPair())
    walletLPBalanceBeforeW = tokenPair.balanceOf(wallet)
    poolLiquidityBalanceBeforeW = tokenPair.balanceOf(pool_liquidity)
    
    tx = pool_liquidity.withdrawLPTokens({"from": accounts[0]})
    withdrawnLiquidity = tx.return_value

    assert poolLiquidityBalanceBeforeW - withdrawnLiquidity == tokenPair.balanceOf(pool_liquidity)
    assert walletLPBalanceBeforeW + withdrawnLiquidity == tokenPair.balanceOf(wallet)

def test_withdrawLPTokensWithLiquidityLocked(pool_liquidity, launch_liquidity_pool):
    with reverts("MISOLaucher: Liquidity is locked"):
        pool_liquidity.withdrawLPTokens({"from": accounts[0]})

def test_withdrawLPTokensWithoutLiquidity(pool_liquidity):
    chain.sleep(pool_liquidity.locktime())

    with reverts("MISOLaucher: Liquidity must be greater than 0"):
        pool_liquidity.withdrawLPTokens({"from": accounts[0]})

def test_withdrawLPTokensWrongOperator(pool_liquidity):
    with reverts("MISOLaucher: Sender must be operator"):
        pool_liquidity.withdrawLPTokens({"from": accounts[5]})

# TODO - uncomment
# def test_launchLiquidityPoolAfterContractExpires(pool_liquidity, deposit_eth, deposit_tokens):
#     chain.sleep(POOL_LAUNCH_WINDOW)
#     with reverts():
#         pool_liquidity.launchLiquidityPool({"from": accounts[0]})


def test_withdrawDepositsWithLiquidity(pool_liquidity, launch_liquidity_pool):
    chain.sleep(POOL_LAUNCH_WINDOW)

    with reverts("MISOLaucher: Liquidity is locked"):
        pool_liquidity.withdrawDeposits({"from": accounts[0]})

def test_withdrawDeposits(pool_liquidity, weth_token, mintable_token, deposit_eth, deposit_tokens):
    chain.sleep(POOL_LAUNCH_DEADLINE+POOL_LAUNCH_WINDOW)

    pool_liquidity.withdrawDeposits({"from": accounts[0]})

    assert mintable_token.balanceOf(pool_liquidity) == 0
    assert weth_token.balanceOf(pool_liquidity) == 0

def test_withdrawDepositsWrongOperator(pool_liquidity):
    
    with reverts("MISOLaucher: Sender must be operator"):
        pool_liquidity.withdrawDeposits({"from": accounts[5]})