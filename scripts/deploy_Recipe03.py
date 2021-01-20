from brownie import *
from .settings import *
from .contracts import *
from .contract_addresses import *
import time

def main():
    load_accounts()

    # Initialise Project
    operator = accounts[0]
    owner = accounts[0]

    wallet = accounts[1]

    # Farm Settings
    rewards_per_block = 1 * TENPOW18
    # Define the start time relative to sales
    start_block =  len(chain) + 50
    dev_addr = wallet
    alloc_point = 100
    templateId = 1
    tokensToFarm = 100 * TENPOW18


    # GP: Split into public and miso access control
    access_control = deploy_access_control(operator)
    user_access_control = deploy_user_access_control(operator)
    # user_access_control = access_control
    
    uniswap_factory = deploy_uniswap_factory()
    weth_token = deploy_weth_token()

    # Setup MISOTokenFactory
    miso_token_factory = deploy_miso_token_factory(access_control)
    if miso_token_factory.tokenTemplateId() == 0 :
        mintable_token_template = deploy_mintable_token_template()
        miso_token_factory.addTokenTemplate(mintable_token_template, {'from': operator} )

    tx = miso_token_factory.createToken("Token", "TKN", templateId, owner, 0, {'from': operator})
    rewards_token = MintableToken.at(web3.toChecksumAddress(tx.events['TokenCreated']['addr']))
    print("rewards_token: " + str(rewards_token))

    rewards_token.mint(owner, tokensToFarm, {'from': owner})

    # MISOFarmFactory
    masterchef_template = deploy_masterchef_template()    
    farm_factory = deploy_farm_factory(access_control)
    if farm_factory.farmTemplateId() == 0:
        farm_factory.addFarmTemplate(masterchef_template, {"from": accounts[0]} )


    # Create MISORecipe03
    recipe_03 = MISORecipe03.deploy(
        weth_token, 
        uniswap_factory, 
        farm_factory, 
        {"from": accounts[0]}
    )


    # User to approve tokens and create farm
    rewards_token.approve(recipe_03, tokensToFarm, {'from': operator})
    tx = recipe_03.createLiquidityFarm(
        rewards_token,
        tokensToFarm,
        rewards_per_block, 
        start_block,
        dev_addr, 
        alloc_point,
        access_control,  {'from': accounts[0]}
    )
    time.sleep(1)
    print("tx events: " + str(tx.events))

