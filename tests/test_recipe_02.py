from brownie import accounts, web3, Wei, reverts, chain
from brownie.network.transaction import TransactionReceipt
from brownie.convert import to_address
import pytest
from brownie import Contract
from settings import *





    
def test_prepare_miso(miso_recipe_02, miso_access_controls):
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
    launchwindow = 3 * 24 * 60 * 60
    deadline = 200
    locktime = 100
    tokensToLiquidity = 100 * TENPOW18

    # Create new Farm
    rewards_per_block = 1 * TENPOW18
    # Define the start time relative to sales
    start_block =  len(chain) + 10
    dev_addr = wallet
    tokensToFarm = 100 * TENPOW18
    alloc_point = 10

    tx = miso_recipe_02.prepareMiso(
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

    