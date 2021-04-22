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
    fixed_token_template = deploy_fixed_token_template()
    sushi_token_template = deploy_sushi_token_template()

    if miso_token_factory.tokenTemplateId() == 0:
        miso_token_factory.addTokenTemplate(
            mintable_token_template, {'from': operator})
        miso_token_factory.addTokenTemplate(
            fixed_token_template, {'from': operator})
        miso_token_factory.addTokenTemplate(
            sushi_token_template, {'from': operator})

    # Setup MISO Market
    crowdsale_template = deploy_crowdsale_template()
    dutch_auction_template = deploy_dutch_auction_template()
    batch_auction_template = deploy_batch_auction_template()
    hyperbolic_auction_template = deploy_hyperbolic_auction_template()

    bento_box = deploy_bento_box()

    miso_market = deploy_miso_market(access_control, bento_box, [
                                     dutch_auction_template, crowdsale_template, batch_auction_template, hyperbolic_auction_template])
    uniswap_factory = deploy_uniswap_factory()

    # Setup PointList
    pointlist_template = deploy_pointlist_template()
    pointlist_factory = deploy_pointlist_factory(
        pointlist_template, access_control, 0)

    # MISOLiquidityLauncher
    weth_token = deploy_weth_token()

    pool_liquidity_template = deploy_pool_liquidity_template()
    miso_launcher = deploy_miso_launcher(access_control, weth_token)
    if miso_launcher.launcherTemplateId() == 0:
        miso_launcher.addLiquidityLauncherTemplate(
            pool_liquidity_template, {"from": accounts[0]})

    # MISOFarmFactory
    masterchef_template = deploy_masterchef_template()
    farm_factory = deploy_farm_factory(access_control)
    if farm_factory.farmTemplateId() == 0:
        farm_factory.addFarmTemplate(
            masterchef_template, {"from": accounts[0]})

    miso_helper = deploy_miso_helper(
        access_control, miso_token_factory, miso_market, miso_launcher, farm_factory)
