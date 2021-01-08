from brownie import *
from .settings import *
from .contract_addresses import *
import time

def load_accounts():
    if network.show_active() == 'mainnet':
        # replace with your keys
        accounts.load("miso")
    # add accounts if active network is goerli
    if network.show_active() in ['goerli', 'ropsten','kovan','rinkeby']:
        # 0x2A40019ABd4A61d71aBB73968BaB068ab389a636
        accounts.add('4ca89ec18e37683efa18e0434cd9a28c82d461189c477f5622dae974b43baebf')
        # 0x1F3389Fc75Bf55275b03347E4283f24916F402f7
        accounts.add('fa3c06c67426b848e6cef377a2dbd2d832d3718999fbe377236676c9216d8ec0')

def deploy_access_control(operator):
    access_control_address = CONTRACTS[network.show_active()]["access_control"]
    if access_control_address == '':
        access_control = MISOAccessControls.deploy({'from': accounts[0]})
        access_control.addOperatorRole(operator, {'from': accounts[0]})
    else:
        access_control = MISOAccessControls.at(access_control_address)
    return access_control

def deploy_user_access_control(operator):
    access_control = MISOAccessControls.deploy({'from': accounts[0]})
    access_control.addOperatorRole(operator, {'from': accounts[0]})
    return access_control


def deploy_weth_token():
    weth_token_address = CONTRACTS[network.show_active()]["weth_token"]
    if weth_token_address == '':
        weth_token = WETH9.deploy({"from":accounts[0]})
    else:
        weth_token = WETH9.at(weth_token_address)
    return weth_token


def deploy_miso_token_factory(access_control):
    miso_token_factory_address = CONTRACTS[network.show_active()]["miso_token_factory"]
    if miso_token_factory_address == '':
        miso_token_factory = MISOTokenFactory.deploy({"from":accounts[0]})
        tx = miso_token_factory.initMISOTokenFactory(access_control, {"from":accounts[0]})
        assert 'MisoInitTokenFactory' in tx.events
    else:
        miso_token_factory = MISOTokenFactory.at(miso_token_factory_address)
    return miso_token_factory

def deploy_mintable_token_template():
    mintable_token_template_address = CONTRACTS[network.show_active()]["mintable_token_template"]
    if mintable_token_template_address == '':
        mintable_token_template = MintableToken.deploy({"from":accounts[0]}) 
    else:
        mintable_token_template = MintableToken.at(mintable_token_template_address)
    return mintable_token_template

def deploy_mintable_token(miso_token_factory,mintable_token_template):
    mintable_token_address = CONTRACTS[network.show_active()]["mintable_token"]
    if mintable_token_address == '':
        tx1 = miso_token_factory.addTokenTemplate(mintable_token_template,{"from":accounts[0]})
        template_id = tx1.events['TokenTemplateAdded']['templateId']
        tx2 = miso_token_factory.createToken(NAME,SYMBOL,template_id,{"from":accounts[0]})
        mintable_token = MintableToken.at(web3.toChecksumAddress(tx2.events['TokenCreated']['addr']))
    else:
        mintable_token = MintableToken.at(mintable_token_address)
    return mintable_token

def deploy_dutch_auction_template():
    dutch_auction_template_address = CONTRACTS[network.show_active()]["dutch_auction_template"]
    if dutch_auction_template_address == '':
        dutch_auction_template = DutchAuction.deploy({"from":accounts[0]})
    else:
        dutch_auction_template = DutchAuction.at(dutch_auction_template_address)
    return dutch_auction_template

def deploy_crowdsale_template():
    crowdsale_template_address = CONTRACTS[network.show_active()]["crowdsale_template"]
    if crowdsale_template_address == '':
        crowdsale_template = Crowdsale.deploy({"from":accounts[0]})
    else:
        crowdsale_template = Crowdsale.at(crowdsale_template_address)
    return crowdsale_template


def deploy_miso_market(access_control, templates):
    miso_market_address = CONTRACTS[network.show_active()]["miso_market"]
    if miso_market_address == '':
        miso_market = MISOMarket.deploy({"from":accounts[0]})
        miso_market.initMISOMarket(access_control, templates)

    else:
        miso_market = MISOMarket.at(miso_market_address)
    return miso_market

def deploy_uniswap_factory():
    uniswap_factory_address = CONTRACTS[network.show_active()]["uniswap_factory"]
    if uniswap_factory_address == '':
        uniswap_factory = UniswapV2Factory.deploy(accounts[0], {"from":accounts[0]})
    else:
        uniswap_factory = UniswapV2Factory.at(uniswap_factory_address)
    return uniswap_factory


def deploy_pool_liquidity_template():
    pool_liquidity_template_address = CONTRACTS[network.show_active()]["pool_liquidity_template"]
    if pool_liquidity_template_address == '':
        pool_liquidity_template = PoolLiquidity.deploy({"from":accounts[0]})
    else:
        pool_liquidity_template = PoolLiquidity.at(pool_liquidity_template_address)
    return pool_liquidity_template

def deploy_miso_launcher(access_control):
    miso_launcher_address = CONTRACTS[network.show_active()]["miso_launcher"]
    if miso_launcher_address == '':
        miso_launcher = MISOLiquidityLauncher.deploy({"from":accounts[0]})
        time.sleep(1) 
        miso_launcher.initMISOLiquidityLauncher(access_control)

    else:
        miso_launcher = MISOLiquidityLauncher.at(miso_launcher_address)
    return miso_launcher


def deploy_masterchef_template():
    masterchef_template_address = CONTRACTS[network.show_active()]["masterchef_template"]
    if masterchef_template_address == '':
        masterchef_template = MasterChef.deploy({"from":accounts[0]})
    else:
        masterchef_template = MasterChef.at(masterchef_template_address)
    return masterchef_template

def deploy_farm_factory(access_control):
    farm_factory_address = CONTRACTS[network.show_active()]["farm_factory"]
    if farm_factory_address == '':
        farm_factory = MISOFarmFactory.deploy({"from":accounts[0]})        
        time.sleep(1) 
        farm_factory.initMISOFarmFactory(access_control)

    else:
        farm_factory = MISOFarmFactory.at(farm_factory_address)
    return farm_factory

def deploy_dutch_auction(miso_market,
                        dutch_auction_template,
                        token_address,
                        auction_tokens,
                        auction_start,
                        auction_end,
                        eth_address,
                        auction_start_price,
                        auction_reserve,
                        wallet):
    dutch_auction_address = CONTRACTS[network.show_active()]["dutch_auction"]
    if dutch_auction_address == '':
        tx1 = miso_market.addAuctionTemplate(dutch_auction_template,{"from":accounts[0]})
        template_id = tx1.events["AuctionTemplateAdded"]["templateId"]
        tx2 = miso_market.createAuction(token_address,
                                         auction_tokens,
                                         auction_start,
                                         auction_end,
                                         eth_address,
                                         auction_start_price,
                                         auction_reserve,
                                         wallet,
                                         template_id,{"from":accounts[0]})
        dutch_auction = DutchAuction.at(web3.toChecksumAddress(tx2.events['AuctionCreated']['addr']))
    else:
        dutch_auction = DutchAuction.at(dutch_auction_address)
    return dutch_auction

