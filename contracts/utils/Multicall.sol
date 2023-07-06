// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;
pragma abicoder v2;

import "../interfaces/IMulticall.sol";

/// @title Multicall
/// @notice Enables calling multiple methods in a single call to the contract
/// @dev The `msg.value` should not be trusted for any method callable from multicall.
abstract contract Multicall is IMulticall {
    /// @dev Modifier to check the balance of native tokens (ETH) before and after function execution.
    /// This is used to ensure that no surplus ETH is left in the contract after a function is executed.
    /// If the final balance is greater than the initial balance, the transaction is reverted.
    modifier noNativeSurplus() {
        uint256 initialBalance = address(this).balance - msg.value;
        _; // Placeholder for the modified function
        require(address(this).balance <= initialBalance, "Native surplus in contract");
    }

    /// @inheritdoc IMulticall
    function multicall(bytes[] calldata data) public payable override noNativeSurplus returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            /// @dev When delegatecall hits other functions, msg.sender will still be the original sender of the
            ///   transaction, not address(this)
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);

            if (!success) {
                // Next 5 lines from https://ethereum.stackexchange.com/a/83577
                if (result.length < 68) revert();
                assembly {
                    result := add(result, 0x04)
                }
                revert(abi.decode(result, (string)));
            }

            results[i] = result;
        }
    }
}
