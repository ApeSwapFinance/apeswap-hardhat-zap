// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

/// @title Router token swapping functionality
/// @notice Functions for swapping tokens via Algebra
/// @dev Credit to Uniswap Labs under GPL-2.0-or-later license:
/// https://github.com/Uniswap/v3-periphery
interface IAlgebraSwapRouter {
    struct ExactInputSingleParamsAlgebra {
        address factory;
        address tokenIn;
        address tokenOut;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 limitSqrtPrice;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another token
    /// @param params The parameters necessary for the swap, encoded as `ExactInputSingleParamsAlgebra` in calldata
    /// @return amountOut The amount of the received token
    function exactInputSingleAlgebra(
        ExactInputSingleParamsAlgebra calldata params
    ) external payable returns (uint256 amountOut);

    struct ExactInputParamsAlgebra {
        address factory;
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another along the specified path
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactInputParamsAlgebra` in calldata
    /// @return amountOut The amount of the received token
    function exactInputAlgebra(ExactInputParamsAlgebra calldata params) external payable returns (uint256 amountOut);

    struct ExactOutputSingleParamsAlgebra {
        address factory;
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 limitSqrtPrice;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another token
    /// @param params The parameters necessary for the swap, encoded as `ExactOutputSingleParamsAlgebra` in calldata
    /// @return amountIn The amount of the input token
    function exactOutputSingleAlgebra(
        ExactOutputSingleParamsAlgebra calldata params
    ) external payable returns (uint256 amountIn);

    struct ExactOutputParamsAlgebra {
        address factory;
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another along the specified path (reversed)
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactOutputParamsAlgebra` in calldata
    /// @return amountIn The amount of the input token
    function exactOutputAlgebra(ExactOutputParamsAlgebra calldata params) external payable returns (uint256 amountIn);

    /// @notice Swaps `amountIn` of one token for as much as possible of another along the specified path
    /// @dev Unlike standard swaps, handles transferring from user before the actual swap.
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactInputParamsAlgebra` in calldata
    /// @return amountOut The amount of the received token
    function exactInputSingleSupportingFeeOnTransferTokensAlgebra(
        ExactInputSingleParamsAlgebra calldata params
    ) external returns (uint256 amountOut);
}
