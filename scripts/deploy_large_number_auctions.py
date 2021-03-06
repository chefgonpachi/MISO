from brownie import *
from .settings import *
from .contracts import *
from .contract_addresses import *
import time
import random




def main():
    access_control = deploy_access_control(accounts[0])
    bento_box = deploy_bento_box()
    number_of_auction_1= 5
    number_of_auction_2 = 5
    deploy_n_number_fixed_token_crowdsale(access_control, bento_box, number_of_auction_1)
    deploy_n_number_fixed_token_dutch_auction(access_control, bento_box, number_of_auction_2)

def deploy_n_number_fixed_token_crowdsale(access_control, bento_box, number_of_auction):
    
    ## To get miso market. not to deploy
    miso_market = deploy_miso_market(access_control, bento_box, [])
    for i in range(number_of_auction):
        print("deploying crowdsale auction --------------- No. ", i+1)
        initial_supply, token = deploy_fixed_token(access_control)
        token = FixedToken.at(token)
        token.approve(miso_market, initial_supply, {"from": accounts[0]})
        deploy_crowdsale(miso_market, access_control, bento_box,token, initial_supply,ETH_ADDRESS)


def deploy_n_number_fixed_token_dutch_auction(access_control, bento_box, number_of_auction):
    for i in range(number_of_auction):
        print("deploying dutch auction ----------- No.", i+1)
        miso_market = deploy_miso_market(access_control, bento_box, [])
        initial_supply, token = deploy_fixed_token(access_control)
        token = FixedToken.at(token)
        token.approve(miso_market, initial_supply, {"from": accounts[0]})
        deploy_dutch_auction(miso_market, access_control, token, initial_supply, ETH_ADDRESS)



################################################
# DutchAuction
###############################################
def deploy_dutch_auction(miso_market, access_control, token, initial_supply, payment_currency):
    dutch_auction_template_address = CONTRACTS[network.show_active()]["dutch_auction_template"]
    dutch_auction_template_id = miso_market.getTemplateId(dutch_auction_template_address)

    token_supply_for_factory = initial_supply - 100 * TENPOW18
    owner = accounts[0]
    _funder = miso_market
    _token = token
    _totalTokens = initial_supply - 500 * TENPOW18
    _startTime,_endTime =  get_auction_start_end()
    _paymentCurrency = payment_currency
    _startPrice, _minimumPrice = get_start_minimum_price()
    _admin = accounts[0]
    _point_list = ZERO_ADDRESS
    _wallet = accounts[1]
    _data = get_data_dutch_auction(
                           _funder,
                           _token,
                           _totalTokens,
                           _startTime,
                           _endTime,
                           _paymentCurrency,
                           _startPrice,
                           _minimumPrice,
                           _admin,
                           _point_list,
                           _wallet
    )

    return deploy_one_market(miso_market, dutch_auction_template_id, token, token_supply_for_factory, _data)



def get_data_dutch_auction(_funder,
                           _token,
                           _totalTokens,
                           _startTime,
                           _endTime,
                           _paymentCurrency,
                           _startPrice,
                           _minimumPrice,
                           _admin,
                           _point_list,
                           _wallet): 

    dutch_auction_template = deploy_dutch_auction_template()

    _data = dutch_auction_template.getAuctionInitData(
                           _funder,
                           _token,
                           _totalTokens,
                           _startTime,
                           _endTime,
                           _paymentCurrency,
                           _startPrice,
                           _minimumPrice,
                           _admin,
                           _point_list,
                           _wallet
    )

    return _data

#################################################
## Crowdsale 
#################################################   

def deploy_crowdsale(miso_market, access_control, bento_box, token, initial_supply, payment_currency):
    ## This does not deploy only gets the address--
    crowdsale_template_address = CONTRACTS[network.show_active()]["crowdsale_template"]
    crowdsale_template_id = miso_market.getTemplateId(crowdsale_template_address)
    token_supply_for_factory = initial_supply - 100 * TENPOW18
    owner = accounts[0]
    _funder = miso_market
    _token = token
    _paymentCurrency = payment_currency
    _totalTokens = initial_supply - 500 * TENPOW18
    _startTime,_endTime =  get_auction_start_end()
    _rate = initial_supply / 10000
    _goal = initial_supply / 1000
    _admin = accounts[0]
    _point_list = ZERO_ADDRESS
    _wallet = accounts[1]
    
    _data = get_data_crowdsale(_funder,
                       _token,
                       _paymentCurrency,
                       _totalTokens,
                       _startTime,
                       _endTime,
                       _rate,
                       _goal,
                       _admin,
                       _point_list,
                       _wallet)
                       
    return deploy_one_market(miso_market, crowdsale_template_id, token, token_supply_for_factory, _data)




def get_data_crowdsale(_funder,
                       _token,
                       _paymentCurrency,
                       _totalTokens,
                       _startTime,
                       _endTime,
                       _rate,
                       _goal,
                       _admin,
                       _point_list,
                       _wallet):

    crowdsale_template = deploy_crowdsale_template()
    _data = crowdsale_template.getCrowdsaleInitData(
                       _funder,
                       _token,
                       _paymentCurrency,
                       _totalTokens,
                       _startTime,
                       _endTime,
                       _rate,
                       _goal,
                       _admin,
                       _point_list,
                       _wallet
    )

    return _data
    
####################################
## Fixed Token
###################################

def deploy_fixed_token(access_control):
    token_factory = deploy_miso_token_factory(access_control)
    fixed_token_template_address = CONTRACTS[network.show_active()]["fixed_token_template"]
    fixed_token_template_id = token_factory.getTemplateId(fixed_token_template_address)
    token_name, token_symbol = get_token_name_symbol()
    initial_supply = get_initial_supply()

    _data = get_data_fixed_token(token_name,
                                token_symbol,
                                initial_supply
                                )

    return initial_supply, deploy_one_token(token_factory,
                                                fixed_token_template_id, 
                                                token_name, 
                                                token_symbol, 
                                                initial_supply, 
                                                access_control,
                                                _data)



def get_data_fixed_token(token_name,
                         token_symbol,
                         initial_supply):

    fixed_token_template = deploy_fixed_token_template()
    owner = accounts[0]
    _data = fixed_token_template.getInitData(
        token_name,
        token_symbol,
        owner,
        initial_supply
    )

    return _data

############################################
# Actual Deployment
###########################################
def deploy_one_token(token_factory, template_id, token_name, token_symbol, initial_supply, access_control,_data):
    _integratorFeeAccount = accounts[0]
    token = token_factory.createToken(template_id, _integratorFeeAccount, _data, {"from": accounts[0]})
    return token.return_value
    
def deploy_one_market(miso_market, crowdsale_template_id, token, token_supply,data):
    _integratorFeeAccount = accounts[0]
    miso_market.createMarket(crowdsale_template_id, token, token_supply,_integratorFeeAccount, data, {"from": accounts[0]})

#############################################
# Helper Function
############################################
def get_token_name_symbol():
    first_words = (
        "The",
        "A",
        "An"
    )

    second_words=("MISO", 
                "MINISO", 
                "ETHEREUM", 
                "BITCOIN",
                "Erat-1",
                "Miso Era-1",
                "Nice",
                "Deniro",
                "Edamame",
                "okonomiyaki",
                "Tobiko",
                "Rachel",
                "green tea icecream",
                "Tempura 2000",
                "Gonpachi",
                "Cardano",
                "Gucci",
                "Toro",
                "Hot",
                "Cold Tofu",
                "IOTA",
                "Sukiyaki Hotpot",
                "Okonomiyaki",
                "KakumeiCoin",
                "Yolo Yakitori",
                "Eratos",
                "Get in quick",
                "Golden",
                "People",
                "Miso",
                "Unicorn")

    third_words = ("Coin", "Crypto", "Token")
    first_word = random.choice(first_words)
    second_word = random.choice(second_words)
    third_word = random.choice(third_words)
    token_name = first_word + " " + second_word+ " " + third_word

    token_symbol = second_word[0:3]

    return token_name,token_symbol


def get_initial_supply():
    return random.randrange(10000, 1000000, 1000) * TENPOW18

def get_auction_start_end():
    auction_start_days = random.uniform(0,1)
    auction_start = int(time.time()) + round(60 * 60 * 24 * auction_start_days)
    auction_end_days = random.uniform(0,2)
    auction_end = auction_start + round(60 * 60 * 24 * auction_end_days)

    return auction_start, auction_end

def get_start_minimum_price():
    auction_start_price = random.randrange(10,100,5) * TENPOW18
    auction_minimum_price = random.randrange(1,10,1) * TENPOW18

    return auction_start_price,auction_minimum_price