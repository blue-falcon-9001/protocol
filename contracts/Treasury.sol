// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';

import "./interfaces/ITreasury.sol";
import "./interfaces/ITrading.sol";

// Treasury with methods to use revenue to push the Cap ecosystem forward through buybacks, dividends, etc. This contract can be upgraded any time, simply point to the new one in the Trading contract

interface IUniswapRouter is ISwapRouter {
    function refundETH() external payable;
}

contract Treasury is ITreasury {

	// Contract dependencies
	address public owner;
	address public trading;
	address public oracle;

	// Uniswap arbitrum addresses
	IUniswapRouter public constant uniswapRouter = IUniswapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
	//address public constant CAP = 0x031d35296154279dc1984dcd93e392b1f946737b;

	// Arbitrum
	address public constant WETH9 = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

	// Treasury can sell assets, hedge, support Cap ecosystem, etc.

	uint256 public vaultBalance;
	uint256 public vaultThreshold = 10 ether;

	// Events

	event Swap(
		uint256 amount,
	    uint256 amountOut,
	    uint256 amountOutMinimum,
	    address tokenIn,
	    address tokenOut,
	    uint24 poolFee
	);

	constructor() {
		owner = msg.sender;
	}

	function creditVault() external override payable {
		uint256 amount = msg.value;
		if (amount == 0) return;
		if (vaultBalance + amount > vaultThreshold) {
			vaultBalance = vaultThreshold;
		} else {
			vaultBalance += amount;
		}
	}

	function debitVault(address destination, uint256 amount) external override onlyTrading {
		if (amount == 0) return;
		require(amount <= vaultBalance, "!vault-insufficient");
		vaultBalance -= amount;
		payable(destination).transfer(amount);
	}

	// Move funds to vault internally
	function fundVault(uint256 amount) external onlyOwner {
		require(amount < address(this).balance - vaultBalance, "!insufficient");
		vaultBalance += amount;
	}

	function fundOracle(
		address destination, 
		uint256 amount
	) external override onlyOracle {
		if (amount > address(this).balance - vaultBalance) return;
		payable(destination).transfer(amount);
	}

	function sendETH(
		address destination, 
		uint256 amount
	) external onlyOwner {
		require(amount < address(this).balance - vaultBalance, "!insufficient");
		payable(destination).transfer(amount);
	}

	function sendToken(
		address token, 
		address destination, 
		uint256 amount
	) external onlyOwner {
		IERC20(token).transfer(destination, amount);
	}

	function swap(
		address tokenIn,
		address tokenOut,
		uint256 amountIn, 
		uint256 amountOutMinimum,
		uint24 poolFee
	) external onlyOwner {

		if (tokenIn == WETH9) {
			require(amountIn < address(this).balance - vaultBalance, "!insufficient");
		}

        // Approve the router to spend tokenIn
        TransferHelper.safeApprove(tokenIn, address(uniswapRouter), amountIn);

		ISwapRouter.ExactInputSingleParams memory params =
	        ISwapRouter.ExactInputSingleParams({
	            tokenIn: tokenIn,
	            tokenOut: tokenOut,
	            fee: poolFee,
	            recipient: msg.sender,
	            deadline: block.timestamp,
	            amountIn: amountIn,
	            amountOutMinimum: amountOutMinimum,
	            sqrtPriceLimitX96: 0
	        });

	    uint256 amountOut;

	    if (tokenIn == WETH9) {
	    	amountOut = uniswapRouter.exactInputSingle{value: amountIn}(params);
	    } else {
	    	amountOut = uniswapRouter.exactInputSingle(params);
	    }

	    emit Swap(
	    	amountIn,
	    	amountOut,
	    	amountOutMinimum,
	    	tokenIn,
	    	tokenOut,
	    	poolFee
	    );

	}

	fallback() external payable {}

	receive() external payable {}

	// Owner methods

	function setParams(
		uint256 _vaultThreshold
	) external onlyOwner {
		vaultThreshold = _vaultThreshold;
	}

	function setOwner(address newOwner) external onlyOwner {
		owner = newOwner;
	}

	function setTrading(address _trading) external onlyOwner {
		trading = _trading;
	}

	function setOracle(address _oracle) external onlyOwner {
		oracle = _oracle;
	}

	// Modifiers

	modifier onlyOwner() {
		require(msg.sender == owner, "!owner");
		_;
	}

	modifier onlyTrading() {
		require(msg.sender == trading, "!trading");
		_;
	}

	modifier onlyOracle() {
		require(msg.sender == oracle, "!oracle");
		_;
	}

}