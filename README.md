# MISO

## Minimal Initial SushiSwap Offering

Minimal Initial SushiSwap Offering (MISO) will be a token launchpad, designed to drive new projects towards launching on SushiSwap. It will include crowdsale options and functionality aimed at easing new tokens through their launch and migrating new liquidity into SushiSwap.

It includes the following menu items:

#### MISOTokenFactory
Creates new tokens from a set of template token types. Tokens include standard fixed token, mintable and our signiture SushiToken with governance functions. 

#### MISOFermenter
Once tokens are freshly minted, there is the option to send some of them away safely for a period of time. 

#### MISOMarket
A place to sell your new tokens. From crowdsales to auctions, we have a few options available to distribute your fresh new tokens.

#### MISOLauncher
A simple way to launch your new tokens on SushiSwap. From holding tokens until liquidity is ready and one click launch.


## Quickstart

No UI yet

# Developers

##  Test Setup 

Install needed Brownie to test: `pip3 install eth-brownie`

## Compiling the contracts

Compile updated contracts: `brownie compile`

Compile all contracts (even not changed ones): `brownie compile --all`

## Running tests

Run tests: `brownie test`

Run tests in verbose mode: `brownie test -v`

Check code coverage: `brownie test --coverage`

Check available fixtures: `brownie --fixtures .`


## Brownie commands

Run script: `brownie run <script_path>`

Run console (very useful for debugging): `brownie console`

## Deploying DutchSwap Contracts 

Run script: `brownie run scripts/deploy_MISO.py`
