.. _token_types:

===========
Token Types
===========

Most ERC20 tokens can be sold in a dutch Auction. For those without exisitng tokens, our token factory can mint Base Tokens. 
Base token type is an ERC20 token from the InstantMISO protocol. It is essentially an ERC20 with some advanced features from the ERC777 standard and some bonus code to make them work with the InstantMISO contract. 

Dutch auction sales differ from traditional token sales in that the Dutch auction allows the market to set the final token price. The auction process allows tokens to be allocated in an equal and impartial way as all successful bidders pay the same price per token.

The bidding process generates a clearing price for the tokens offered in the auction. Once the token price is determined, all investors who submitted successful bids receive an allocation of tokens at that price.


What is an ERC20 Token
======================

Tokens themselves is a special unit that describes what exactly you sell.  It can hold value and be sent and received.

The price per token that you ultimately pay will be less than or equal to the quoted price at the time since the token price decreases over time.

Demand for tokens is calculated as the sum of payments received from users divided by the current price per token. Once demand equals the total amount of tokens available, the auction ends and the token price is locked in.

If the auction concludes at the end of the auction period everyone will receive their tokens at the pre-defined reserve price, also known as the price floor.


Types of Tokens
===============

Most ERC20 tokens can be sold in a Dutch Auction.

**The Basic ERC20** Token implements the missing name, short name, decimals and the initial total supply of a standard ERC20 token. No extra features, no extra bells, and whistles. Just standard ERC20 functionality.


.. note::

    For those without existing tokens, our token factory can mint Base Tokens. The base token type is an ERC20 token from the InstantMISO protocol. It is essentially an ERC20 with some advanced features from the ERC777 standard and some modified code to make them work with the Instant MISO contract.




Exceptions for InstantMISO
------------------------

Some exceptions include deflationary tokens where there is a difference in total value when transfered, usually from a transfer at the protocol level.