// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "contracts/interfaces/ITrap.sol";

contract LiquidityTrap is ITrap {
    // ---------------------------------------------------------
    // CONFIG
    // ---------------------------------------------------------
    address public constant TOKEN = 0xFba1bc0E3d54D71Ba55da7C03c7f63D4641921B1;

    address public owner;
    uint256 public liquidityDropThreshold = 20; // default: 20% drop triggers trap
    uint256 public lastLiquidity;

    // ---------------------------------------------------------
    // EVENTS
    // ---------------------------------------------------------
    event TrapArmed(uint256 initialLiquidity);
    event LiquidityPulled(uint256 oldLiquidity, uint256 newLiquidity);
    event ThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // ---------------------------------------------------------
    // OWNER FUNCTIONS
    // ---------------------------------------------------------
    function setThreshold(uint256 newThres) external onlyOwner {
        require(newThres <= 90, "Too high");
        emit ThresholdUpdated(liquidityDropThreshold, newThres);
        liquidityDropThreshold = newThres;
    }

    function armTrap(uint256 currentLiquidity) external onlyOwner {
        // You call this when creating or updating LP
        lastLiquidity = currentLiquidity;
        emit TrapArmed(currentLiquidity);
    }

    // ---------------------------------------------------------
    // CORE LOGIC
    // ---------------------------------------------------------
    function detect(
        address target,
        bytes calldata data
    ) external override returns (bool triggered) {
        // target = address being interacted with
        // data   = function selector + arguments

        uint256 newLiquidity = _simulateLiquidityCheck();

        if (lastLiquidity == 0) {
            // First run, initialise
            lastLiquidity = newLiquidity;
            return false;
        }

        // Compute % drop
        uint256 drop = ((lastLiquidity - newLiquidity) * 100) / lastLiquidity;

        if (drop >= liquidityDropThreshold) {
            emit LiquidityPulled(lastLiquidity, newLiquidity);
            lastLiquidity = newLiquidity;
            return true;
        }

        // Update lastLiquidity anyway
        lastLiquidity = newLiquidity;
        return false;
    }

    // ---------------------------------------------------------
    // INTERNAL (mock for now)
    // ---------------------------------------------------------
    function _simulateLiquidityCheck() internal view returns (uint256) {
        // TODO:
        // Replace this mock with real LP-token balance logic
        //
        // Example:
        // return IERC20(LP_TOKEN).balanceOf(UNISWAP_PAIR);
        //
        // For now, just return block number so trap reacts to change.
        return block.number;
    }
}
