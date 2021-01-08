from brownie import *
from .settings import *
from .contracts import *
from .contract_addresses import *
import time

def main():
    load_accounts()

    # Initialise Project
    operator = accounts[0]
    wallet = accounts[1]

    # GP: Split into public and miso access control
    access_control = deploy_access_control(operator)
    
    # Setup MISOTokenFactory
    miso_token_factory = deploy_miso_token_factory(access_control)
    mintable_token_template = deploy_mintable_token_template()
    if miso_token_factory.tokenTemplateId() == 0 :
        miso_token_factory.addTokenTemplate(mintable_token_template, {'from': operator} )

    # Setup MISO Market  
    crowdsale_template = deploy_crowdsale_template()
    dutch_auction_template = deploy_dutch_auction_template()
    miso_market = deploy_miso_market(access_control, [dutch_auction_template, crowdsale_template])
    uniswap_factory = deploy_uniswap_factory()

    # MISOLiquidityLauncher
    pool_liquidity_template = deploy_pool_liquidity_template()    
    miso_launcher = deploy_miso_launcher(access_control)
    if miso_launcher.launcherTemplateId() == 0:
        miso_launcher.addLiquidityLauncherTemplate(pool_liquidity_template, {"from": accounts[0]} )

    # MISOFarmFactory
    masterchef_template = deploy_masterchef_template()    
    farm_factory = deploy_farm_factory(access_control)
    if farm_factory.farmTemplateId() == 0:
        farm_factory.addFarmTemplate(masterchef_template, {"from": accounts[0]} )

    # ##########
    # Testing  
    # ##########


    # Create mintable for testing
    weth_token = deploy_weth_token()
    
    wallet = accounts[1]
    templateId = 1
    tx = miso_token_factory.createToken("Token", "TKN", templateId, {'from': operator})
    rewards_token = MintableToken.at(web3.toChecksumAddress(tx.events['TokenCreated']['addr']))
    print("rewards_token: " + str(rewards_token))

    rewards_token.mint(operator, 1000 * TENPOW18, {'from': operator})

    # Create new Crowdsale Contract
    market_tokens = 200 * TENPOW18
    market_rate = 100
    market_goal = 200
    rewards_token.approve(miso_market, market_tokens, {'from': operator})
    tx = miso_market.createCrowdsale(
        rewards_token, 
        market_tokens, 
        chain.time() + 50, 
        chain.time() + 1000, 
        market_rate, 
        market_goal, 
        wallet, 2,
        {'from': operator}
    )
    crowdsale = Crowdsale.at(web3.toChecksumAddress(tx.events['AuctionCreated']['addr']))
    print("crowdsale: " + str(crowdsale))

    # Create new LiquidityLauncher
    # just random numbers atm 
    duration = 300  # seconds
    launchwindow = 3 * 24 * 60 * 60
    deadline = 200
    locktime = 100
    tx = miso_launcher.createLiquidityLauncher(1, {'from': operator} )
    pool_liquidity = PoolLiquidity.at(web3.toChecksumAddress(tx.events['LiquidityLauncherCreated']['addr']))
    print("pool_liquidity: " + str(pool_liquidity))
   
    pool_liquidity.initPoolLiquidity(access_control,
            rewards_token,
            weth_token,
            uniswap_factory,
            operator,
            wallet,
            duration,
            launchwindow,
            deadline,
            locktime,  {'from': operator}) 

    lp_token_address = pool_liquidity.getLPTokenAddress()
    lp_token = interface.IERC20(web3.toChecksumAddress(lp_token_address))

    print("lp_token: " + str(lp_token))

    rewards_token.transfer(pool_liquidity, 100 * TENPOW18, {'from': operator})

    # Create new Farm
    rewards_per_block = 1 * TENPOW18
    # Define the start time relative to sales
    start_block =  len(chain) + 10
    dev_addr = wallet

    tx = farm_factory.createFarm(rewards_token, rewards_per_block, start_block, dev_addr, access_control, 1, {'from': operator})
    masterchef = MasterChef.at(web3.toChecksumAddress(tx.events['FarmCreated']['addr']))
    print("masterchef: " + str(masterchef))

    rewards_token.transfer(masterchef, 100 * TENPOW18, {'from': operator})
    alloc_point = 10
    masterchef.addToken(alloc_point, lp_token, False, {'from': operator})


    if network.show_active() == "development":
        # Things to check
        # Buy tokens from Crowdsale
        # Claim tokens
        # Finalise Auction

        # Mock funds from crowdsale to launcher (instead of finalising auction, we just send some eth)
        pool_liquidity.depositETH({'from': operator, 'value': 2 * TENPOW18})

        sleep = pool_liquidity.deadline() - chain.time() + 1
        chain.sleep(sleep) 
        tx = pool_liquidity.addLiquidityToPool({'from': operator})
        liquidity = tx.events['LiquidityAdded']['liquidity']
        print("liquidity: " + str(liquidity))

        chain.sleep(1) 
