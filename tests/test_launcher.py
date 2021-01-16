import pytest
from brownie import accounts, web3, Wei, reverts, chain
from brownie.convert import to_address
from settings import *

# reset the chain after every test case
@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass

def test_launcher_add_template_not_operator(launcher,pool_liquidity_template):
    with reverts():
        launcher.addLiquidityLauncherTemplate(pool_liquidity_template, {"from": accounts[5]} )

def test_launcher_get_template(launcher, pool_liquidity_template):
    launcher_template = launcher.getLiquidityLauncherTemplate(1,{"from":accounts[0]})
    assert pool_liquidity_template == launcher_template


# def test_launcher_number_of_liquidity_launcher_contracts(launcher,pool_liquidity_template_2):
#     tx = launcher.addLiquidityLauncherTemplate(pool_liquidity_template_2, {"from": accounts[0]} )
#     assert "LiquidityTemplateAdded" in tx.events
#     template_id = 2
#     tx = launcher.createLiquidityLauncher(template_id, {"from": accounts[0]})
#     number_of_contracts = launcher.numberOfLiquidityLauncherContracts({"from":accounts[0]})
#     assert number_of_contracts == 2
    

########### Template Id Test ##################################
def test_launcher_get_template_id(launcher, pool_liquidity_template_2):
    tx = launcher.addLiquidityLauncherTemplate(pool_liquidity_template_2, {"from": accounts[0]} )
    assert "LiquidityTemplateAdded" in tx.events

    template_id = launcher.getTemplateId(pool_liquidity_template_2,{"from":accounts[0]})
    assert template_id == 2


########## Remove Template Test#####################
def test_launcher_remove_template(launcher,pool_liquidity_template_2):
    tx = launcher.addLiquidityLauncherTemplate(pool_liquidity_template_2, {"from": accounts[0]} )
    assert "LiquidityTemplateAdded" in tx.events
    tx = launcher.removeLiquidityLauncherTemplate(2,{"from": accounts[0]})
    
    assert "LiquidityTemplateRemoved" in tx.events



####### Helper function ###########################
@pytest.fixture(scope='function', autouse=True)
def pool_liquidity_template_2(PoolLiquidity):
    pool_liquidity_template_2 = PoolLiquidity.deploy({"from": accounts[0]})
    return pool_liquidity_template_2

