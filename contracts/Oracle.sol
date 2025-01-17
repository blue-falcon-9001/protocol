// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "./interfaces/IOracle.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/ITrading.sol";

contract Oracle is IOracle {

	// Contract dependencies
	address public owner;
	address public trading;
	address public oracle;
	address public treasury;

	// Variables
	uint256 public requestsPerFunding = 100;
	uint256 public costPerRequest = 6 * 10**14; // 0.0006 ETH
	uint256 public requestsSinceFunding;

	event SettlementError(
		uint256 indexed orderId,
		bool indexed isClose,
		string reason
	);

	constructor() {
		owner = msg.sender;
	}

	function settleOrders(
		uint256[] calldata positionIds,
		uint256[] calldata positionPrices,
		uint256[] calldata orderIds,
		uint256[] calldata orderPrices
	) external onlyOracle {

		if (positionIds.length > 0) {

			for (uint256 i = 0; i < positionIds.length; i++) {

				uint256 positionId = positionIds[i];
				uint256 price = positionPrices[i];

				try ITrading(trading).settleNewPosition(positionId, price) {

				} catch Error(string memory reason) {
					ITrading(trading).cancelPosition(positionId);
					console.log("Error position", positionId, reason);
					emit SettlementError(
						positionId,
						false,
						reason
					);
				}

			}

		}

		if (orderIds.length > 0) {

			for (uint256 i = 0; i < orderIds.length; i++) {

				uint256 orderId = orderIds[i];
				uint256 price = orderPrices[i];

				try ITrading(trading).settleCloseOrder(orderId, price) {

				} catch Error(string memory reason) {
					ITrading(trading).cancelOrder(orderId);
					console.log("Error order", orderId, reason);
					emit SettlementError(
						orderId,
						true,
						reason
					);
				}

			}

		}

		_tallyOracleRequests(positionIds.length + orderIds.length);

	}

	function liquidatePositions(
		uint256[] calldata positionIds,
		uint256[] calldata _prices
	) external onlyOracle {
		ITrading(trading).liquidatePositions(positionIds, _prices);
		_tallyOracleRequests(positionIds.length);
	}

	function _tallyOracleRequests(uint256 newRequests) internal {
		if (newRequests == 0) return;
		requestsSinceFunding += newRequests;
		if (requestsSinceFunding >= requestsPerFunding) {
			requestsSinceFunding = 0;
			ITreasury(treasury).fundOracle(oracle, costPerRequest * requestsPerFunding);
		}
	}

	// Owner methods

	function setParams(
		uint256 _requestsPerFunding, 
		uint256 _costPerRequest
	) external onlyOwner {
		requestsPerFunding = _requestsPerFunding;
		costPerRequest = _costPerRequest;
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

	function setTreasury(address _treasury) external onlyOwner {
		treasury = _treasury;
	}

	// Modifiers

	modifier onlyOwner() {
		require(msg.sender == owner, "!owner");
		_;
	}

	modifier onlyOracle() {
		require(msg.sender == oracle, "!oracle");
		_;
	}

}