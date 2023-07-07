// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

contract MulticallGuard {
    // source: @openzeppelin/contracts/security/ReentrancyGuard.sol (v4.6.2)
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    address private _multicall_initial_sender;
    uint256 private _multicall_status;
    /// @dev This is used to prevent reentrancy attacks when a function is called out of a multicall context.
    uint256 private _function_status;

    constructor() {
        _multicall_status = _NOT_ENTERED;
        _function_status = _NOT_ENTERED;
        _multicall_initial_sender = address(0);
    }

    /// @notice Modifier to validate multicall
    /// @dev This modifier ensures that no surplus native tokens are left in the contract after function execution
    /// @param noNativeSurplus If true, it checks that no surplus native tokens are left in the contract
    modifier guardMulticall(bool noNativeSurplus) {
        // On the first call to guardMulticall, _multicall_status == _NOT_ENTERED
        require(_multicall_status == _NOT_ENTERED, "MulticallGuard: reentrant call");
        _multicall_status = _ENTERED;
        _multicall_initial_sender = msg.sender;
        uint256 initialBalance = address(this).balance - msg.value;

        _;

        if (noNativeSurplus) {
            require(address(this).balance <= initialBalance, "MulticallGuard: Native surplus in contract");
        }

        // source: @openzeppelin/contracts/security/ReentrancyGuard.sol (v4.6.2)
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _multicall_status = _NOT_ENTERED;
        _multicall_initial_sender = address(0);
    }

    /// @dev Modifier to validate params depending on the context of multicall.
    /// @param inMulticallValidation If true, requires validation to pass when in a multicall context.
    /// @param notInMulticallValidation If true, requires validation to pass when not in a multicall context.
    modifier multicallGuard(bool inMulticallValidation, bool notInMulticallValidation) {
        require(_function_status == _NOT_ENTERED, "MulticallGuard: reentrant call");
        if (_multicall_status == _NOT_ENTERED) {
            /// @dev Protect function against reentrancy when not in a multicall context
            _function_status = _ENTERED;
        }
        _requireNotInMulticall(notInMulticallValidation);
        _requireInMulticall(inMulticallValidation);
        _;
        _function_status = _NOT_ENTERED;
    }

    /// @notice Function to require multicall when in multicall context
    /// @dev This function provides reentrancy protection during a multicall and checks a conditional validation
    /// @param validation If within a multicall true, it checks that the current sender is the initial sender
    ///   and the validation is true
    function _requireInMulticall(bool validation) internal view {
        /// @dev When delegatecall hits other functions, msg.sender will still be the original sender of the
        ///   transaction, not address(this)
        if (_multicall_status == _ENTERED) {
            require(
                _multicall_initial_sender == msg.sender,
                "MulticallGuard: In multicall, sender should be initial sender"
            );
            require(validation, "MulticallGuard: In multicall, validation should be true");
        }
    }

    /// @notice Function to require validation when not in multicall context
    /// @dev This function checks that the validation is true when not in a multicall
    /// @param validation If not within a multicall transaction, it checks that the validation is true
    function _requireNotInMulticall(bool validation) internal view {
        if (_multicall_status == _NOT_ENTERED) {
            require(validation, "MulticallGuard: Not in multicall, validation should be true");
        }
    }
}
