// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IPancakeRouter02.sol";  // Update path as necessary

contract AleinToken is ERC20, Ownable, ERC20Burnable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public immutable marketingWallet;
    address public immutable projectFundsWallet;
    IPancakeRouter02 public immutable pancakeRouter;
    address[] private _path;

    uint256 public constant liquidityFee = 2;  // 2%
    uint256 public constant marketingFee = 5;  // 5%
    uint256 public constant projectFundsFee = 2;  // 2%
    uint256 private constant _totalFees = liquidityFee + marketingFee + projectFundsFee;

    mapping(address => bool) private _isExcludedFromFees;

    event TransferWithFees(address indexed from, address indexed to, uint256 amount);
    event LiquidityAdded(uint256 tokenAmount, uint256 bnbAmount);
    event SentToMarketing(uint256 amount);
    event SentToProjectFunds(uint256 amount);

    constructor(
        address _marketingWallet,
        address _projectFundsWallet,
        uint256 _initialSupply,
        address initialOwner,
        address _pancakeRouterAddress
    ) ERC20("Alein Token", "ALEIN") Ownable(initialOwner) {
        require(_marketingWallet != address(0), "Invalid marketing wallet address");
        require(_projectFundsWallet != address(0), "Invalid project funds wallet address");
        require(_pancakeRouterAddress != address(0), "Invalid PancakeRouter address");

        _mint(_msgSender(), _initialSupply);
        marketingWallet = _marketingWallet;
        projectFundsWallet = _projectFundsWallet;
        pancakeRouter = IPancakeRouter02(_pancakeRouterAddress);

_path = new address[](2);  // creates an address array with size 2
        _path[0] = address(this);
        _path[1] = _pancakeRouterAddress; // PancakeSwap router address for BSC

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

    function swapAndLiquify(uint256 tokens) private nonReentrant {
        uint256 half = tokens.div(2);
        uint256 otherHalf = tokens.sub(half);

        uint256 initialBalance = address(this).balance;

        swapTokensForBNB(half);

        uint256 newBalance = address(this).balance.sub(initialBalance);

        addLiquidity(otherHalf, newBalance);

        emit LiquidityAdded(otherHalf, newBalance);
    }

    function swapTokensForBNB(uint256 tokenAmount) private {
        _approve(address(this), address(pancakeRouter), tokenAmount);

        pancakeRouter.swapExactTokensForBNBSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // Set amountOutMin to 0
            _path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        _approve(address(this), address(pancakeRouter), tokenAmount);

        uint256 initialBalance = address(this).balance;

        pancakeRouter.addLiquidityBNB{value: bnbAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            owner(),
            block.timestamp
        );

        uint256 newBalance = address(this).balance.sub(initialBalance);

        emit LiquidityAdded(tokenAmount, newBalance);
    }

    function swapAndSendToMarketing(uint256 tokenAmount) private nonReentrant {
        swapTokensForBNB(tokenAmount);
        uint256 bnbAmount = address(this).balance;

        (bool success, ) = marketingWallet.call{value: bnbAmount}("");
        require(success, "Transfer to marketing wallet failed");

        emit SentToMarketing(bnbAmount);
    }

    function swapAndSendToProjectFunds(uint256 tokenAmount) private nonReentrant {
        swapTokensForBNB(tokenAmount);
        uint256 bnbAmount = address(this).balance;

        (bool success, ) = projectFundsWallet.call{value: bnbAmount}("");
        require(success, "Transfer to project funds wallet failed");

        emit SentToProjectFunds(bnbAmount);
    }

    function withdrawBNB(uint256 amount) public onlyOwner nonReentrant {
        require(amount <= address(this).balance, "Insufficient balance");
        payable(owner()).transfer(amount);
    }

    receive() external payable {}
}
