const { ethers } = require("hardhat");

async function main() {
    const [deployer, user1, user2] = await ethers.getSigners();
    
    console.log("=== AMM Swap 合约交互演示 ===\n");
    
    // 部署合约（如果还没有部署）
    console.log("1. 部署合约...");
    
    const TestToken = await ethers.getContractFactory("TestToken");
    const tokenA = await TestToken.deploy("Token A", "TKA", 18, 1000000);
    const tokenB = await TestToken.deploy("Token B", "TKB", 18, 1000000);
    
    const AMMSwap = await ethers.getContractFactory("AMMSwap");
    const ammSwap = await AMMSwap.deploy(tokenA.address, tokenB.address);
    
    console.log("Token A:", tokenA.address);
    console.log("Token B:", tokenB.address);
    console.log("AMM Swap:", ammSwap.address);
    
    // 为测试用户铸造代币
    await tokenA.mint(user1.address, ethers.utils.parseEther("10000"));
    await tokenB.mint(user1.address, ethers.utils.parseEther("10000"));
    await tokenA.mint(user2.address, ethers.utils.parseEther("10000"));
    await tokenB.mint(user2.address, ethers.utils.parseEther("10000"));
    
    console.log("\n2. 添加流动性演示...");
    
    // 用户1添加流动性
    const liquidityAmount0 = ethers.utils.parseEther("1000");
    const liquidityAmount1 = ethers.utils.parseEther("1000");
    
    await tokenA.connect(user1).approve(ammSwap.address, liquidityAmount0);
    await tokenB.connect(user1).approve(ammSwap.address, liquidityAmount1);
    
    const tx1 = await ammSwap.connect(user1).addLiquidity(
        liquidityAmount0, 
        liquidityAmount1, 
        0
    );
    await tx1.wait();
    
    const [reserve0, reserve1] = await ammSwap.getReserves();
    console.log(`流动性池状态: ${ethers.utils.formatEther(reserve0)} TokenA, ${ethers.utils.formatEther(reserve1)} TokenB`);
    
    const lpBalance = await ammSwap.balanceOf(user1.address);
    console.log(`用户1获得 LP 代币: ${ethers.utils.formatEther(lpBalance)}`);
    
    console.log("\n3. 代币交换演示...");
    
    // 用户2进行代币交换
    const swapAmount = ethers.utils.parseEther("100");
    
    await tokenA.connect(user2).approve(ammSwap.address, swapAmount);
    
    const balanceBefore = await tokenB.balanceOf(user2.address);
    console.log(`交换前 TokenB 余额: ${ethers.utils.formatEther(balanceBefore)}`);
    
    // 计算预期输出量
    const expectedOutput = await ammSwap.getAmountOut(swapAmount, reserve0, reserve1);
    console.log(`预期输出量: ${ethers.utils.formatEther(expectedOutput)} TokenB`);
    
    // 设置合理的最小输出量（比预期输出量稍低一些，5% 滑点保护）
    const minAmountOut = expectedOutput.mul(95).div(100);
    console.log(`最小输出量（5% 滑点保护）: ${ethers.utils.formatEther(minAmountOut)} TokenB`);
    
    const tx2 = await ammSwap.connect(user2).swap(
        tokenA.address, 
        swapAmount, 
        minAmountOut
    );
    await tx2.wait();
    
    const balanceAfter = await tokenB.balanceOf(user2.address);
    console.log(`交换后 TokenB 余额: ${ethers.utils.formatEther(balanceAfter)}`);
    console.log(`实际获得: ${ethers.utils.formatEther(balanceAfter.sub(balanceBefore))} TokenB`);
    
    // 更新后的储备量
    const [newReserve0, newReserve1] = await ammSwap.getReserves();
    console.log(`交换后流动性池: ${ethers.utils.formatEther(newReserve0)} TokenA, ${ethers.utils.formatEther(newReserve1)} TokenB`);
    
    console.log("\n4. 价格影响分析...");
    
    const priceImpact = swapAmount.mul(100).div(reserve0);
    console.log(`价格影响: ${priceImpact.toString()}%`);
    
    // 计算新的价格比率
    const priceRatio = newReserve1.mul(ethers.utils.parseEther("1")).div(newReserve0);
    console.log(`TokenA/TokenB 价格比率: ${ethers.utils.formatEther(priceRatio)}`);
    
    console.log("\n5. 移除流动性演示...");
    
    // 用户1移除部分流动性
    const removeAmount = lpBalance.div(2); // 移除一半流动性
    
    const balanceBefore0 = await tokenA.balanceOf(user1.address);
    const balanceBefore1 = await tokenB.balanceOf(user1.address);
    
    const tx3 = await ammSwap.connect(user1).removeLiquidity(
        removeAmount, 
        0, 
        0
    );
    await tx3.wait();
    
    const balanceAfter0 = await tokenA.balanceOf(user1.address);
    const balanceAfter1 = await tokenB.balanceOf(user1.address);
    
    console.log(`移除流动性获得:`);
    console.log(`  TokenA: ${ethers.utils.formatEther(balanceAfter0.sub(balanceBefore0))}`);
    console.log(`  TokenB: ${ethers.utils.formatEther(balanceAfter1.sub(balanceBefore1))}`);
    
    const finalLpBalance = await ammSwap.balanceOf(user1.address);
    console.log(`剩余 LP 代币: ${ethers.utils.formatEther(finalLpBalance)}`);
    
    console.log("\n6. 手续费收益演示...");
    
    // 进行多次交换来累积手续费
    for (let i = 0; i < 3; i++) {
        const smallSwap = ethers.utils.parseEther("10");
        await tokenA.connect(user2).approve(ammSwap.address, smallSwap);
        await ammSwap.connect(user2).swap(tokenA.address, smallSwap, 0);
        
        // 反向交换
        const reverseSwap = ethers.utils.parseEther("9");
        await tokenB.connect(user2).approve(ammSwap.address, reverseSwap);
        await ammSwap.connect(user2).swap(tokenB.address, reverseSwap, 0);
    }
    
    const [finalReserve0, finalReserve1] = await ammSwap.getReserves();
    console.log(`累积手续费后的流动性池:`);
    console.log(`  TokenA: ${ethers.utils.formatEther(finalReserve0)}`);
    console.log(`  TokenB: ${ethers.utils.formatEther(finalReserve1)}`);
    
    // 计算手续费收益
    const feeGain0 = finalReserve0.sub(newReserve0);
    const feeGain1 = finalReserve1.sub(newReserve1);
    console.log(`手续费收益:`);
    console.log(`  TokenA: ${ethers.utils.formatEther(feeGain0)}`);
    console.log(`  TokenB: ${ethers.utils.formatEther(feeGain1)}`);
    
    console.log("\n=== 演示完成 ===");
    console.log("\n关键要点:");
    console.log("1. AMM 使用恒定乘积公式自动计算交换比率");
    console.log("2. 每次交易都会产生价格影响，大额交易影响更大");
    console.log("3. 0.3% 手续费留在流动性池中，增加 LP 价值");
    console.log("4. 流动性提供者通过 LP 代币获得手续费收益");
    console.log("5. 滑点保护机制防止意外损失");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    }); 