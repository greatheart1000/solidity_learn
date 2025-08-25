// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title AMMSwap
 * @dev 基础 AMM (Automated Market Maker) Swap 合约
 * 实现恒定乘积公式 (x * y = k) 的代币交换
 */
contract AMMSwap is ReentrancyGuard, Ownable {
    using SafeMath for uint256;

    // 事件定义
    event Swap(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    event AddLiquidity(
        address indexed provider,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity
    );

    event RemoveLiquidity(
        address indexed provider,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity
    );

    // 状态变量
    address public token0;
    address public token1;
    
    uint256 public reserve0;
    uint256 public reserve1;
    
    uint256 public totalSupply; // LP 代币总供应量
    mapping(address => uint256) public balanceOf; // LP 代币余额
    
    uint256 public constant MINIMUM_LIQUIDITY = 10**3;
    uint256 public constant FEE_DENOMINATOR = 1000;
    uint256 public constant FEE_NUMERATOR = 3; // 0.3% 手续费

    // 构造函数
    constructor(address _token0, address _token1) {
        require(_token0 != _token1, "AMMSwap: IDENTICAL_ADDRESSES");
        require(_token0 != address(0) && _token1 != address(0), "AMMSwap: ZERO_ADDRESS");
        
        token0 = _token0;
        token1 = _token1;
    }

    /**
     * @dev 获取当前储备量
     */
    function getReserves() public view returns (uint256 _reserve0, uint256 _reserve1) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
    }

    /**
     * @dev 计算交换输出量
     * @param amountIn 输入代币数量
     * @param reserveIn 输入代币储备量
     * @param reserveOut 输出代币储备量
     * @return amountOut 输出代币数量
     */
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        require(amountIn > 0, "AMMSwap: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "AMMSwap: INSUFFICIENT_LIQUIDITY");
        
        uint256 amountInWithFee = amountIn.mul(FEE_DENOMINATOR.sub(FEE_NUMERATOR));
        uint256 numerator = amountInWithFee.mul(reserveOut);
        uint256 denominator = reserveIn.mul(FEE_DENOMINATOR).add(amountInWithFee);
        amountOut = numerator.div(denominator);
    }

    /**
     * @dev 计算交换输入量
     * @param amountOut 期望输出代币数量
     * @param reserveIn 输入代币储备量
     * @param reserveOut 输出代币储备量
     * @return amountIn 需要的输入代币数量
     */
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountIn) {
        require(amountOut > 0, "AMMSwap: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "AMMSwap: INSUFFICIENT_LIQUIDITY");
        
        uint256 numerator = reserveIn.mul(amountOut).mul(FEE_DENOMINATOR);
        uint256 denominator = reserveOut.sub(amountOut).mul(FEE_DENOMINATOR.sub(FEE_NUMERATOR));
        amountIn = numerator.div(denominator).add(1);
    }

    /**
     * @dev 执行代币交换
     * @param tokenIn 输入代币地址
     * @param amountIn 输入代币数量
     * @param minAmountOut 最小输出代币数量（滑点保护）
     */
    function swap(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut
    ) external nonReentrant {
        require(tokenIn == token0 || tokenIn == token1, "AMMSwap: INVALID_TOKEN");
        require(amountIn > 0, "AMMSwap: INSUFFICIENT_INPUT_AMOUNT");
        
        address tokenOut = tokenIn == token0 ? token1 : token0;
        (uint256 reserveIn, uint256 reserveOut) = tokenIn == token0 
            ? (reserve0, reserve1) 
            : (reserve1, reserve0);
        
        uint256 amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        require(amountOut >= minAmountOut, "AMMSwap: INSUFFICIENT_OUTPUT_AMOUNT");
        
        // 转移代币
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).transfer(msg.sender, amountOut);
        
        // 更新储备量
        _updateReserves();
        
        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    /**
     * @dev 添加流动性
     * @param amount0Desired 期望添加的 token0 数量
     * @param amount1Desired 期望添加的 token1 数量
     * @param minLiquidity 最小 LP 代币数量
     */
    function addLiquidity(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 minLiquidity
    ) external nonReentrant {
        require(amount0Desired > 0 && amount1Desired > 0, "AMMSwap: INSUFFICIENT_INPUT_AMOUNT");
        
        uint256 amount0;
        uint256 amount1;
        uint256 liquidity;
        
        if (reserve0 == 0 && reserve1 == 0) {
            // 首次添加流动性
            amount0 = amount0Desired;
            amount1 = amount1Desired;
            liquidity = sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
            _mint(address(0), MINIMUM_LIQUIDITY); // 永久锁定最小流动性
        } else {
            // 后续添加流动性
            uint256 amount1Optimal = quote(amount0Desired, reserve0, reserve1);
            if (amount1Optimal <= amount1Desired) {
                require(amount1Optimal >= 0, "AMMSwap: INSUFFICIENT_AMOUNT_1");
                amount0 = amount0Desired;
                amount1 = amount1Optimal;
            } else {
                uint256 amount0Optimal = quote(amount1Desired, reserve1, reserve0);
                assert(amount0Optimal <= amount0Desired);
                require(amount0Optimal >= 0, "AMMSwap: INSUFFICIENT_AMOUNT_0");
                amount0 = amount0Optimal;
                amount1 = amount1Desired;
            }
            liquidity = min(
                amount0.mul(totalSupply).div(reserve0),
                amount1.mul(totalSupply).div(reserve1)
            );
        }
        
        require(liquidity >= minLiquidity, "AMMSwap: INSUFFICIENT_LIQUIDITY_MINTED");
        
        // 转移代币
        IERC20(token0).transferFrom(msg.sender, address(this), amount0);
        IERC20(token1).transferFrom(msg.sender, address(this), amount1);
        
        // 铸造 LP 代币
        _mint(msg.sender, liquidity);
        
        // 更新储备量
        _updateReserves();
        
        emit AddLiquidity(msg.sender, amount0, amount1, liquidity);
    }

    /**
     * @dev 移除流动性
     * @param liquidity LP 代币数量
     * @param minAmount0 最小 token0 数量
     * @param minAmount1 最小 token1 数量
     */
    function removeLiquidity(
        uint256 liquidity,
        uint256 minAmount0,
        uint256 minAmount1
    ) external nonReentrant {
        require(liquidity > 0, "AMMSwap: INSUFFICIENT_LIQUIDITY_BURNED");
        
        uint256 amount0 = liquidity.mul(reserve0).div(totalSupply);
        uint256 amount1 = liquidity.mul(reserve1).div(totalSupply);
        
        require(amount0 >= minAmount0, "AMMSwap: INSUFFICIENT_AMOUNT_0");
        require(amount1 >= minAmount1, "AMMSwap: INSUFFICIENT_AMOUNT_1");
        
        // 销毁 LP 代币
        _burn(msg.sender, liquidity);
        
        // 转移代币
        IERC20(token0).transfer(msg.sender, amount0);
        IERC20(token1).transfer(msg.sender, amount1);
        
        // 更新储备量
        _updateReserves();
        
        emit RemoveLiquidity(msg.sender, amount0, amount1, liquidity);
    }

    /**
     * @dev 更新储备量
     */
    function _updateReserves() private {
        reserve0 = IERC20(token0).balanceOf(address(this));
        reserve1 = IERC20(token1).balanceOf(address(this));
    }

    /**
     * @dev 铸造 LP 代币
     */
    function _mint(address to, uint256 amount) private {
        balanceOf[to] = balanceOf[to].add(amount);
        totalSupply = totalSupply.add(amount);
    }

    /**
     * @dev 销毁 LP 代币
     */
    function _burn(address from, uint256 amount) private {
        balanceOf[from] = balanceOf[from].sub(amount);
        totalSupply = totalSupply.sub(amount);
    }

    /**
     * @dev 计算平方根
     */
    function sqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    /**
     * @dev 计算最优代币数量
     */
    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) private pure returns (uint256 amountB) {
        require(amountA > 0, "AMMSwap: INSUFFICIENT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "AMMSwap: INSUFFICIENT_LIQUIDITY");
        amountB = amountA.mul(reserveB).div(reserveA);
    }

    /**
     * @dev 最小值函数
     */
    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
} 