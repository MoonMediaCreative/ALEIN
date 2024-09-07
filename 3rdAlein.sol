// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Context.sol";

interface IPancakeRouter02 {
  function swapExactTokensForBNBSupportingFeeOnTransferTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external;

  function WBNB() external pure returns (address);

  function addLiquidityBNB(
    address token,
    uint256 amountTokenDesired,
    uint256 amountTokenMin,
    uint256 amountBNBMin,
    address to,
    uint256 deadline
  ) external payable returns (uint256 amountToken, uint256 amountBNB, uint256 liquidity);
}

contract AleinToken is ERC20, Ownable {
  using SafeMath for uint256;

  IPancakeRouter02 public pancakeRouter = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
  address public marketingWallet; // Declare marketingWallet as a public member
  address public projectFundsWallet;
  address[] public path; // Declare the path array at the contract level

  uint256 public liquidityFee = 2; // 2%
  uint256 public marketingFee = 5; // 5%
  uint256 public projectFundsFee = 2; // 2%
  uint256 private totalFees = liquidityFee.add(marketingFee).add(projectFundsFee);

  // uint256 public approvalDeadline = 1 hours; // Set your desired approval deadline (removed for brevity)

  event TransferWithFees(address indexed from, address indexed to, uint256 amount);
  event LiquidityAdded(uint256 tokenAmount, uint256 bnbAmount);
  event SentToMarketing(uint256 amount);
  event SentToProjectFunds(uint256 amount);

  constructor(
    address _marketingWallet,
    address _projectFundsWallet,
    uint256 _initialSupply
  ) ERC20("Alein Token", "ALEIN") Ownable(msg.sender) {
    _mint(msg.sender, _initialSupply);
    marketingWallet = _marketingWallet;
    projectFundsWallet = _projectFundsWallet;

    // Initialize the path array with 2 elements
    path = new address[](2);
    path[0] = address(this);
    path[1] = pancakeRouter.WBNB();
  }

function transfer(
    address to,
    uint256 amount
) public override returns (bool) {
    address from = _msgSender();
    _transfer(from, to, amount);

    uint256 fees = amount.mul(totalFees).div(100);
    uint256 liquidityAmount 
        = fees.mul(liquidityFee).div(totalFees);
    uint256 marketingAmount 
        = fees.mul(marketingFee).div(totalFees);
    uint256 projectFundsAmount 
        = fees.mul(projectFundsFee).div(totalFees);

    _transfer(from, address(this), fees);

    swapAndLiquify(liquidityAmount);
    swapAndSendToMarketing(marketingAmount);
    swapAndSendToProjectFunds(projectFundsAmount);

    emit TransferWithFees(from, to, amount);

    return true;
}

  function swapAndLiquify(uint256 tokens) private {
    uint256 half = tokens.div(2);
    uint256 otherHalf = tokens.sub(half);

    uint256 initialBalance = address(this).balance;

    swapTokensForBNB(half);

    uint256 newBalance = address(this).balance.sub(initialBalance);

    addLiquidity(otherHalf, newBalance);
  }

  function swapTokensForBNB(uint256 tokenAmount) private {
    _approve(address(this), address(pancakeRouter), tokenAmount);

    pancakeRouter.swapExactTokensForBNBSupportingFeeOnTransferTokens(
      tokenAmount,
      0, // Set amountOutMin to 0
      path,
      address(this),
      block.timestamp
    );
  }

  function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
    _approve(address(this), address(pancakeRouter), tokenAmount);

    pancakeRouter.addLiquidityBNB{value: bnbAmount}(
      address(this),
      tokenAmount,
      0,
      0,
      owner(),
      block.timestamp
    );

    emit LiquidityAdded(tokenAmount, bnbAmount);
  }

  function swapAndSendToMarketing(uint256 tokenAmount) private {
    swapTokensForBNB(tokenAmount);
    uint256 bnbAmount = address(this).balance;
    payable(marketingWallet).transfer(bnbAmount);

    emit SentToMarketing(bnbAmount);
  }

  function swapAndSendToProjectFunds(uint256 tokenAmount) private {
    swapTokensForBNB(tokenAmount);
    uint256 bnbAmount = address(this).balance;
    payable(projectFundsWallet).transfer(bnbAmount);

    emit SentToProjectFunds(bnbAmount);
  }

  function withdrawBNB(uint256 amount) public onlyOwner {
    require(amount <= address(this).balance, "Insufficient balance");
    payable(owner()).transfer(amount);
  }
}