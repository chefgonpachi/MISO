.. meta::
    :keywords: Smart Contracts

.. _fixed_token_contract:

Fixed Supply ERC20 Contract
===============================

FixedSupplyToken
-------------------

The FixedSupplyToken smart contract implements all the mandatory `ERC20 <https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md>`_ functions. They are:

totalSupply(), balanceOf(...), transfer(...), transferFrom(...), approve(...) and allowance(...)


Additionally, the approveAndCall(...) functionality is included so that the two operations of executing tokenContract.approve(targetContract, tokens) and targetContract.doSomething(...) (which will execute tokenContract.transferFrom(user, targetContact, tokens)) can be combined into a single approveAndCall(...) transaction. Please only use this functionality with trusted smart contracts, and with checks!




Factory deployTokenContract Function
----------------------------------------

* `function deployTokenContract(string memory symbol, string memory name, uint8 decimals, uint totalSupply) public payable returns (address token)`

Deploy a new token contract. The account executing this function will be assigned as the owner of the new token contract. The entire totalSupply is minted for the token contract owner.

Parameters:

* symbol: Symbol of the token

* name: Token contract name

* decimals: Decimal places, between 0 and 27. Commonly 18

* totalSupply: The number of tokens that will be minted to the token contract owner's account
