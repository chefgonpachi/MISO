from brownie import *
from .settings import *
from .contract_addresses import *

def load_accounts():
    if network.show_active() == 'mainnet':
        # replace with your keys
        accounts.load("digitalax")
    # add accounts if active network is goerli
    if network.show_active() in ['goerli', 'ropsten','kovan','rinkeby']:
        # 0x2A40019ABd4A61d71aBB73968BaB068ab389a636
        accounts.add('4ca89ec18e37683efa18e0434cd9a28c82d461189c477f5622dae974b43baebf')
        # 0x1F3389Fc75Bf55275b03347E4283f24916F402f7
        accounts.add('fa3c06c67426b848e6cef377a2dbd2d832d3718999fbe377236676c9216d8ec0')

def deploy_bokky_token_factory():
    bokky_token_factory_address = CONTRACTS[network.show_active()]["bokky_token_factory"]
    if bokky_token_factory_address == '':
        bokky_token_factory = BokkyPooBahsFixedSupplyTokenFactory.deploy({'from': accounts[0]})
    else:
        bokky_token_factory = BokkyPooBahsFixedSupplyTokenFactory.at(bokky_token_factory_address)
    return bokky_token_factory

def deploy_bokky_fixed_token(bokky_token_factory):
    tx = bokky_token_factory.deployTokenContract(SYMBOL,NAME,18,AUCTION_TOKENS,{'from':accounts[0],"value":"0.02 ethers"})
    bokky_fixed_token = FixedSupplyToken.at(web3.toChecksumAddress(tx.events['TokenDeployed']['token']))
   # print("FixedSupplyToken deployed at: " + str(bokky_fixed_token))
    return bokky_fixed_token

def deploy_miso_token_factory():
    miso_token_factory_address = CONTRACTS[network.show_active()]["miso_token_factory"]
    if miso_token_factory_address == '':
        miso_token_factory = MISOTokenFactory.deploy({"from":accounts[0]})
        tx = miso_token_factory.initMISO({"from":accounts[0]})
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

def deploy_auction_house(dutch_auction_template):
    auction_house_address = CONTRACTS[network.show_active()]["auction_house"]
    if auction_house_address == '':
        auction_house = MISOMarket.deploy({"from":accounts[0]})
        ##dutch_auction_template in list req or not?
        auction_house._initMISO([dutch_auction_template],{"from":accounts[0]})
    else:
        auction_house = MISOMarket.at(auction_house_address)
    return auction_house

def deploy_dutch_auction(auction_house,
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
        tx1 = auction_house.addAuctionTemplate(dutch_auction_template,{"from":accounts[0]})
        template_id = tx1.events["AuctionTemplateAdded"]["templateId"]
        tx2 = auction_house.createAuction(token_address,
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

