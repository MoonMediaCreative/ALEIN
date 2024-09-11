// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract AleinToken is ERC20, Ownable, ERC20Burnable {
    using SafeMath for uint256;

    address public immutable marketingWallet;
    address public immutable projectFundsWallet;
    address[] private _path;

    uint256 public constant liquidityFee = 2; // 2%
    uint256 public constant marketingFee = 5; // 5%
    uint256 public constant projectFundsFee = 2; // 2%
    uint256 private constant _totalFees = liquidityFee + marketingFee + projectFundsFee;

    mapping(address => bool) private _isExcludedFromFees;

    event TransferWithFees(address indexed from, address indexed to, uint256 amount);
    event LiquidityAdded(uint256 tokenAmount, uint256 bnbAmount);
    event SentToMarketing(uint256 amount);
    event SentToProjectFunds(uint256 amount);

    constructor(
        address _marketingWallet,
        address _projectFundsWallet,
        uint256 _initialSupply
    ) ERC20("Alein Token", "ALEIN") Ownable(msg.sender) {
        _mint(_msgSender(), _initialSupply);
        marketingWallet = _marketingWallet;
        projectFundsWallet = _projectFundsWallet;

        _path = new address[](2);
        _path[0] = address(this);
        _path[1] = address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c); // PancakeSwap router address for BSC

        // Exclude owner and this contract from fees
        _isExcludedFromFees[owner()] = true;
        _isExcludedFromFees[address(this)] = true;
    }

    function transfer(
        address to,
        uint256 amount
    ) public override returns (bool) {
        address from = _msgSender();
        _transfer(from, to, amount);

        if (!_isExcludedFromFees[from] && !_isExcludedFromFees[to]) {
            uint256 fees = amount.mul(_totalFees).div(100);
            uint256 amountAfterFees = amount - fees;

            uint256 liquidityAmount = (fees * liquidityFee) / _totalFees;
            uint256 marketingAmount = (fees * marketingFee) / _totalFees;
            uint256 projectFundsAmount = fees - liquidityAmount - marketingAmount;

            _transfer(from, address(this), fees);

            swapAndLiquify(liquidityAmount);
            swapAndSendToMarketing(marketingAmount);
            swapAndSendToProjectFunds(projectFundsAmount);

            emit TransferWithFees(from, to, amountAfterFees);
        } else {
            emit TransferWithFees(from, to, amount);
        }

        return true;
    }

    function swapAndLiquify(uint256 tokens) private {
        uint256 half = tokens / 2;
        uint256 otherHalf = tokens - half;

        uint256 initialBalance = address(this).balance;

        swapTokensForBNB(half);

        uint256 newBalance = address(this).balance - initialBalance;

        addLiquidity(otherHalf, newBalance);

        emit LiquidityAdded(otherHalf, newBalance);
    }

    function swapTokensForBNB(uint256 tokenAmount) private {
        _approve(address(this), address(0x10ED43C718714eb63d5aA57B78B54704E256024E), tokenAmount); // PancakeSwap router address for BSC

        IPancakeRouter02 pancakeRouter = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E); // PancakeSwap router address for BSC

        pancakeRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // Set amountOutMin to 0
            _path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        _approve(address(this), address(0x10ED43C718714eb63d5aA57B78B54704E256024E), tokenAmount); // PancakeSwap router address for BSC

        IPancakeRouter02 pancakeRouter = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E); // PancakeSwap router address for BSC

        pancakeRouter.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            owner(),
            block.timestamp
        );
    }

    function swapAndSendToMarketing(uint256 tokenAmount) private {
        swapTokensForBNB(tokenAmount);
        uint256 bnbAmount = address(this).balance;

        (bool success, ) = marketingWallet.call{value: bnbAmount}("");
        require(success, "Transfer to marketing wallet failed");

        emit SentToMarketing(bnbAmount);
    }

    function swapAndSendToProjectFunds(uint256 tokenAmount) private {
        swapTokensForBNB(tokenAmount);
        uint256 bnbAmount = address(this).balance;

        (bool success, ) = projectFundsWallet.call{value: bnbAmount}("");
        require(success, "Transfer to project funds wallet failed");

        emit SentToProjectFunds(bnbAmount);
    }

    function withdrawBNB(uint256 amount) public onlyOwner {
        require(amount <= address(this).balance, "Insufficient balance");
        payable(owner()).transfer(amount);
    }

    receive() external payable {}
}

interface IPancakeRouter02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
}