InstantMISO
=======

InstantMISO is a smart contract factory and Dutch auction house for ERC20 tokens.

 Historically, Dutch auctions have been used to provide a fair price discovery event for both new and developed products and markets. For those with something to sell, they provide a system where you leave with all your stock sold - at a price you decide you're happy with. For those looking to buy, a way to make sure you're getting the same deal as everybody else in the market. With these goals in mind, InstantMISO aims to update the traditional Dutch auction experience and bring them to the Ethereum community. 

A fair token pricing solution for new and existing ERC20 tokens, InstantMISO has you covered from bulb to bloom.

!! Documentation is currently under construction !!


.. note::

    Parts of this documentation reference smart contracts written in ``Solidity`` and the documentation assumes a basic familiarity with it. You may wish to view the `Solidity docs <https://solidity.readthedocs.io/en/stable/index.html>`_ if you have not used it previously.

Features
========

* Dutch Auctions for ERC20 tokens
* Payments in ETH or any ERC20 of your choosing
* Token minting and dispersal services
* Contract testing via `pytest <https://github.com/pytest-dev/pytest>`_, including trace-based coverage evaluation
* Property-based and stateful testing via `hypothesis <https://github.com/HypothesisWorks/hypothesis/tree/master/hypothesis-python>`_



The main documentation for the site is organized into the following sections:


.. toctree::
    :caption: Getting Started
    :maxdepth: 1
   
    quickstart/index
    getting_started/step_by_step/index



.. toctree::
    :caption: Tokens
    :maxdepth: 1
    :name: sec-tokens

    tokens/token_types
    tokens/creating_tokens


.. toctree::
    :caption: Protocol
    :maxdepth: 1
    :name: sec-devel

    protocol/smart_contracts/index
    protocol/deployment/index

.. toctree::
    :caption: Community
    :maxdepth: 1
    :name: sec-community

    community/contributing
    community/channels
