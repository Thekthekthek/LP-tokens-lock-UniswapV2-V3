# Liquidity Locker Smart Contracts

## Overview

This project contains two versions of the Liquidity Locker smart contracts, `liqLockV2` and `LiqLockV3`, inspired by the Unibot Liquidity Locker. These contracts are designed to secure liquidity tokens in a decentralized manner, providing users and projects with a trustless way to lock liquidity and thus enhance the integrity and trustworthiness of their tokens.

`liqLockV2` is suited for LP tokens of UniswapV2 likes, whereas `liqLockV3` has been updated to support uniswapV3 likes pools, incorporating features and optimizations for the latest DeFi ecosystem requirements.

Feel free to deploy it to the chain you likes or make it your own by including the onlyOwner modifier on each functions.

## Features

- **Liquidity Locking**: Securely lock liquidity tokens to enhance project trustworthiness.
- **Decentralized and Trustless**: Contracts allow for a decentralized way to lock and manage liquidity.

## Prerequisites

- Solidity ^0.8.20
- A wallet with Ethereum for deployment fees (e.g., MetaMask).

## Installation

1. Clone this repository to your local machine.
2. Install [Truffle](https://www.trufflesuite.com/) or [Hardhat](https://hardhat.org/) to compile and deploy the contracts.
3. Compile the contracts with `truffle compile` or `npx hardhat compile`.

## Usage

To deploy these contracts, you will need to use a development framework like Truffle or Hardhat. Below is an example of deploying `LiqLockV3` using Truffle:

```shell
truffle migrate --network <your_network>
