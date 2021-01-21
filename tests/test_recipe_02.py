from brownie import accounts, web3, Wei, reverts, chain
from brownie.network.transaction import TransactionReceipt
from brownie.convert import to_address
import pytest
from brownie import Contract
from settings import *



def prepare_miso(miso_recipe_02, miso_access_controls):

    operator = accounts[0]
    wallet = accounts[1]
    name = "Token"
    symbol = "TKN"
    tokensToMint = 1000 * TENPOW18
    tokensToMarket = 200 * TENPOW18

    startTime = chain.time() + 50
    endTime = chain.time() + 1000
    market_rate = 100
    market_goal = 200
    payment_currency = ETH_ADDRESS

    duration = 300  # seconds
    launchwindow  =POOL_LAUNCH_WINDOW
    deadline = chain.time() + POOL_LAUNCH_DEADLINE
    locktime = POOL_LAUNCH_LOCKTIME
    tokensToLiquidity = 100 * TENPOW18

    # Create new Farm
    rewards_per_block = 1 * TENPOW18
    # Define the start time relative to sales
    start_block =  len(chain) + 10
    dev_addr = wallet
    tokensToFarm = 100 * TENPOW18
    alloc_point = 10

    txn = miso_recipe_02.prepareMiso(
        name,
        symbol,
        miso_access_controls,
        tokensToMint,
        tokensToMarket,
        payment_currency,

        startTime, 
        endTime,
        market_rate,
        market_goal,
        wallet,
        operator,
        

        deadline,
        launchwindow, 
        locktime, 
        tokensToLiquidity,

        rewards_per_block, 
        start_block,
        dev_addr, 
        tokensToFarm,
        alloc_point, {'from': accounts[0]}
    )

    token,lp_token,pool_liquidity,farm = txn.return_value
    return [token,lp_token,pool_liquidity,farm]

def pool_liqudity(SushiToken, PoolLiquidity, weth_token, miso_recipe_02, miso_access_controls):
    token,lp_token,pool_liquidity,farm = prepare_miso(miso_recipe_02,miso_access_controls)
    pool_liquidity = PoolLiquidity.at(pool_liquidity)
    
    assert weth_token.balance() == 0
    deposit_eth = ETH_TO_DEPOSIT
    pool_liquidity.depositETH({"from": accounts[0], "value": deposit_eth})
    assert weth_token.balance() == deposit_eth
    assert weth_token.totalSupply() == deposit_eth
    assert pool_liquidity.getWethBalance() == deposit_eth 

    return [token,lp_token,pool_liquidity,farm]

    token = SushiToken.at(token)
    deposit_amount = 100*TENPOW18
    tx = pool_liquidity.depositTokens(deposit_amount, {"from": accounts[0]})
    assert "Transfer" in tx.events
    assert pool_liquidity.getTokenBalance() == deposit_amount
    return [token,lp_token,pool_liquidity,farm]
    


def test_master_chef(SushiToken, PoolLiquidity, weth_token, miso_recipe_02, miso_access_controls,MasterChef,fixed_token2):
    token,lp_token,pool_liquidity,farm= pool_liqudity(SushiToken, PoolLiquidity, weth_token, miso_recipe_02, miso_access_controls)
    
    master_chef = MasterChef.at(farm)
    master_chef.addToken(100, fixed_token2, False,{"from":accounts[0]})
    pool_id = 1
    approve_amount = 200* TENPOW18
    amount_to_deposit = 20*TENPOW18
    fixed_token2.approve(master_chef,approve_amount,{"from":accounts[0]})
    depositor = accounts[0]
    balance_before_deposit = fixed_token2.balanceOf(depositor)
    tx = master_chef.deposit(pool_id,amount_to_deposit,{"from":depositor})
    balance_after_deposit = fixed_token2.balanceOf(depositor)
    assert "Deposit" in tx.events
    assert balance_before_deposit - balance_after_deposit == amount_to_deposit

    chain.sleep(5*24*60*60)

    tx = master_chef.withdraw(pool_id,amount_to_deposit,{"from":depositor})
    assert "Withdraw" in tx.events
 





