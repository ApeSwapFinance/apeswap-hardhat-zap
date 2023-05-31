// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../../ApeSwapZap.sol";
import "./libraries/IBEP20RewardApeV5.sol";
import "./libraries/ITreasury.sol";

abstract contract ApeSwapZapPools is ApeSwapZap {
    using SafeERC20 for IERC20;

    IERC20 public immutable BANANA;
    IERC20 public immutable GNANA;
    ITreasury public immutable GNANA_TREASURY; // Golden Banana Treasury

    event ZapLPPool(IERC20 inputToken, uint256 inputAmount, IBEP20RewardApeV5 pool);
    event ZapLPPoolNative(uint256 inputAmount, IBEP20RewardApeV5 pool);
    event ZapSingleAssetPool(IERC20 inputToken, uint256 inputAmount, IBEP20RewardApeV5 pool);
    event ZapSingleAssetPoolNative(uint256 inputAmount, IBEP20RewardApeV5 pool);

    constructor(ITreasury goldenBananaTreasury) {
        ITreasury gnanaTreasury;
        IERC20 banana;
        IERC20 gnana;
        if (block.chainid == 56) {
            /// @dev The Golden Banana Treasury only exists on BNB Chain
            require(address(goldenBananaTreasury) != address(0), "Must provide Golden BANANA Treasury for BNB Chain");
        }

        if (address(goldenBananaTreasury) != address(0)) {
            gnanaTreasury = goldenBananaTreasury;
            banana = gnanaTreasury.banana();
            gnana = gnanaTreasury.goldenBanana();
        } else {
            gnanaTreasury = ITreasury(address(0));
            banana = IERC20(address(0));
            gnana = IERC20(address(0));
        }
        /// @dev Can't access immutable variables in constructor
        /// @dev Can't initialize immutable variables in if statement.
        GNANA_TREASURY = gnanaTreasury;
        BANANA = banana;
        GNANA = gnana;
    }

    /// @notice Zap token into banana/gnana pool
    /// @param inputToken Input token to zap
    /// @param inputAmount Amount of input tokens to zap
    /// @param path Path from input token to stake token
    /// @param minAmountsSwap The minimum amount of output tokens that must be received for swap
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @param pool Pool address
    function zapSingleAssetPool(
        IERC20 inputToken,
        uint256 inputAmount,
        address[] calldata path,
        uint256 minAmountsSwap,
        uint256 deadline,
        IBEP20RewardApeV5 pool
    ) external nonReentrant {
        uint256 balanceBefore = _getBalance(inputToken);
        inputToken.safeTransferFrom(msg.sender, address(this), inputAmount);
        inputAmount = _getBalance(inputToken) - balanceBefore;

        __zapInternalSingleAssetPool(inputToken, inputAmount, path, minAmountsSwap, deadline, pool);
        emit ZapSingleAssetPool(inputToken, inputAmount, pool);
    }

    /// @notice Zap native into banana/gnana pool
    /// @param path Path from input token to stake token
    /// @param minAmountsSwap The minimum amount of output tokens that must be received for swap
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @param pool Pool address
    function zapSingleAssetPoolNative(
        address[] calldata path,
        uint256 minAmountsSwap,
        uint256 deadline,
        IBEP20RewardApeV5 pool
    ) external payable nonReentrant {
        uint256 inputAmount = msg.value;
        IERC20 inputToken = IERC20(WNATIVE);
        IWETH(WNATIVE).deposit{value: inputAmount}();

        __zapInternalSingleAssetPool(inputToken, inputAmount, path, minAmountsSwap, deadline, pool);
        emit ZapSingleAssetPoolNative(inputAmount, pool);
    }

    /// @notice Zap token into banana/gnana pool
    /// @param inputToken Input token to zap
    /// @param inputAmount Amount of input tokens to zap
    /// @param underlyingTokens Tokens of LP to zap to
    /// @param path0 Path from input token to LP token0
    /// @param path1 Path from input token to LP token1
    /// @param minAmountsSwap The minimum amount of output tokens that must be received for swap
    /// @param minAmountsLP AmountAMin and amountBMin for adding liquidity
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @param pool Pool address
    function zapLPPool(
        IERC20 inputToken,
        uint256 inputAmount,
        address[] memory underlyingTokens, //[token0, token1]
        address[] calldata path0,
        address[] calldata path1,
        uint256[] memory minAmountsSwap, //[A, B]
        uint256[] memory minAmountsLP, //[amountAMin, amountBMin]
        uint256 deadline,
        IBEP20RewardApeV5 pool
    ) external nonReentrant {
        IApePair pair = IApePair(address(pool.STAKE_TOKEN()));
        require(
            (underlyingTokens[0] == pair.token0() && underlyingTokens[1] == pair.token1()) ||
                (underlyingTokens[1] == pair.token0() && underlyingTokens[0] == pair.token1()),
            "ApeSwapZap: Wrong LP pair for Pool"
        );

        _zapInternal(
            inputToken,
            inputAmount,
            underlyingTokens,
            path0,
            path1,
            minAmountsSwap,
            minAmountsLP,
            address(this),
            deadline
        );

        uint256 balance = pair.balanceOf(address(this));
        pair.approve(address(pool), balance);
        pool.depositTo(balance, msg.sender);
        pair.approve(address(pool), 0);
        emit ZapLPPool(inputToken, inputAmount, pool);
    }

    /// @notice Zap native into banana/gnana pool
    /// @param underlyingTokens Tokens of LP to zap to
    /// @param path0 Path from input token to LP token0
    /// @param path1 Path from input token to LP token1
    /// @param minAmountsSwap The minimum amount of output tokens that must be received for swap
    /// @param minAmountsLP AmountAMin and amountBMin for adding liquidity
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @param pool Pool address
    function zapLPPoolNative(
        address[] memory underlyingTokens, //[token0, token1]
        address[] calldata path0,
        address[] calldata path1,
        uint256[] memory minAmountsSwap, //[A, B]
        uint256[] memory minAmountsLP, //[amountAMin, amountBMin]
        uint256 deadline,
        IBEP20RewardApeV5 pool
    ) external payable nonReentrant {
        IApePair pair = IApePair(address(pool.STAKE_TOKEN()));
        require(
            (underlyingTokens[0] == pair.token0() && underlyingTokens[1] == pair.token1()) ||
                (underlyingTokens[1] == pair.token0() && underlyingTokens[0] == pair.token1()),
            "ApeSwapZap: Wrong LP pair for Pool"
        );

        _zapNativeInternal(underlyingTokens, path0, path1, minAmountsSwap, minAmountsLP, address(this), deadline);

        uint256 balance = pair.balanceOf(address(this));
        pair.approve(address(pool), balance);
        pool.depositTo(balance, msg.sender);
        pair.approve(address(pool), 0);
        emit ZapLPPoolNative(msg.value, pool);
    }

    /// @notice Zap token into banana/gnana pool
    /// @param inputToken Input token to zap
    /// @param inputAmount Amount of input tokens to zap
    /// @param path Path from input token to stake token
    /// @param minAmountsSwap The minimum amount of output tokens that must be received for swap
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @param pool Pool address
    function __zapInternalSingleAssetPool(
        IERC20 inputToken,
        uint256 inputAmount,
        address[] calldata path,
        uint256 minAmountsSwap,
        uint256 deadline,
        IBEP20RewardApeV5 pool
    ) internal {
        IERC20 stakeToken = pool.STAKE_TOKEN();

        uint256 amount = inputAmount;
        IERC20 neededToken = stakeToken == GNANA ? BANANA : stakeToken;

        if (inputToken != neededToken) {
            require(path[0] == address(inputToken), "ApeSwapZap: wrong path path[0]");
            require(path[path.length - 1] == address(neededToken), "ApeSwapZap: wrong path path[-1]");

            inputToken.approve(address(router), inputAmount);
            uint256[] memory amounts = router.swapExactTokensForTokens(
                inputAmount,
                minAmountsSwap,
                path,
                address(this),
                deadline
            );
            amount = amounts[amounts.length - 1];
        }

        if (stakeToken == GNANA) {
            uint256 beforeAmount = _getBalance(stakeToken);
            IERC20(BANANA).approve(address(GNANA_TREASURY), amount);
            GNANA_TREASURY.buy(amount);
            amount = _getBalance(stakeToken) - beforeAmount;
        }

        stakeToken.approve(address(pool), amount);
        pool.depositTo(amount, msg.sender);
        stakeToken.approve(address(pool), 0);
    }
}