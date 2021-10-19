// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./interfaces/IPool.sol";
import "./interfaces/ITrading.sol";

contract Pool is IPool {

	using SafeERC20 for IERC20; 
    using Address for address payable;

	address public owner;
	address public trading;
	address public clp;
	address public staking;

	constructor() {
		owner = msg.sender;
	}

	function creditProfit(address destination, address token, uint256 amount) {
		IERC20(token).safeTransfer(destination, amount);
	}

	function mintAndStakeCLP(address token, uint256 amount) external returns(uint256) {

		require(supportedToken[token], "!token");

		uint256 totalAssetsInUSD = ; // of total assets in the pool
		uint256 clpSupply = IERC20(clp).totalSupply();

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        uint256 amountInUsd = ; // of sent token

        uint256 CLPAmountToMint = totalAssetsInUSD == 0 ? amountInUsd : amountInUsd * clpSupply / totalAssetsInUSD;

        require(CLPAmountToMint >= minCLP, "!minCLP");

        IERC20(clp).mint(msg.sender, CLPAmountToMint);

        lastMinted[msg.sender] = block.timestamp;

        IStaking(staking).stakeAfterMint(msg.sender, clp, CLPAmountToMint);

        return CLPAmountToMint;

	}

}