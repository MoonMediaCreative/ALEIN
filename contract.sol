// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

contract AleinToken is ERC20, Ownable {
    using SafeMath for uint256;

    IUniswapV2Router02 public uniswapV2Router;
    address public marketingWallet;
    address public projectFundsWallet;

    uint256 public liquidityFee = 2;
    uint256 public marketingFee = 5;
    uint256 public projectFundsFee = 2;
    uint256 private totalFees = liquidityFee.add(marketingFee).add(projectFundsFee);

    mapping (address => bool) private _isExcludedFromFees;

    constructor(
        address _router,
        address _marketingWallet,
        address _projectFundsWallet
    ) ERC20("Alein Token", "ALEIN") Ownable(0xEaa28DF4673377a601Bb503677bD0903a3079452) {
        _mint(0xEaa28DF4673377a601Bb503677bD0903a3079452, 100000000 * (10 ** 18)); // Mint 100 million ALEIN tokens to the specified address
        uniswapV2Router = IUniswapV2Router02(_router);
        marketingWallet = _marketingWallet;
        projectFundsWallet = _projectFundsWallet;
    }

    function transferWithFees(
        address from,
        address to,
        uint256 amount
    ) public {
        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            _transfer(from, to, amount);
            return;
        }

        uint256 fees = amount.mul(totalFees).div(100);
        uint256 amountAfterFees = amount.sub(fees);

        uint256 liquidityAmount = fees.mul(liquidityFee).div(totalFees);
        uint256 marketingAmount = fees.mul(marketingFee).div(totalFees);
        uint256 projectFundsAmount = fees.mul(projectFundsFee).div(totalFees);

        _transfer(from, address(this), fees);
        _transfer(from, to, amountAfterFees);

        // Handle liquidity, marketing, and project funds transfers
        swapAndLiquify(liquidityAmount);
        sendToMarketing(marketingAmount);
        sendToProjectFunds(projectFundsAmount);
    }

    function swapAndLiquify(uint256 tokens) private {
        // Split the tokens into halves
        uint256 half = tokens.div(2);
        uint256 otherHalf = tokens.sub(half);

        // Capture the contract's current BNB balance
        uint256 initialBalance = address(this).balance;

        // Swap tokens for BNB
        swapTokensForBNB(half);

        // How much BNB did we get?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // Add liquidity to PancakeSwap
        addLiquidity(otherHalf, newBalance);
    }

function swapTokensForBNB(uint256 tokenAmount) private {
    // Declare and initialize the path for swapping ALEIN to BNB
    address[] memory path = new address[](2);
    path[0] = address(this);  // ALEIN token address
    path[1] = uniswapV2Router.WETH();

    _approve(address(this), address(uniswapV2Router), tokenAmount);

    // Perform the swap
    uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
        tokenAmount,
        0,  // Accept any amount of BNB
        path,
        address(this),
        block.timestamp
    );
}

    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // Add liquidity to PancakeSwap
        uniswapV2Router.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0, // Min amount of tokens
            0, // Min amount of BNB
            owner(),
            block.timestamp
        );
    }

    function sendToMarketing(uint256 tokens) private {
        _transfer(address(this), marketingWallet, tokens);
    }

    function sendToProjectFunds(uint256 tokens) private {
        _transfer(address(this), projectFundsWallet, tokens);
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        _isExcludedFromFees[account] = excluded;
    }

    receive() external payable {}
}
