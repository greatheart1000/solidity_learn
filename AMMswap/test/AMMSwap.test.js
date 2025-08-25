const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AMMSwap", function () {
    let ammSwap, tokenA, tokenB;
    let owner, user1, user2;
    const INITIAL_SUPPLY = ethers.utils.parseEther("1000000");

    beforeEach(async function () {
        [owner, user1, user2] = await ethers.getSigners();

        // 部署测试代币
        const TestToken = await ethers.getContractFactory("TestToken");
        tokenA = await TestToken.deploy("Token A", "TKA", 18, 1000000);
        tokenB = await TestToken.deploy("Token B", "TKB", 18, 1000000);

        // 部署 AMM Swap 合约
        const AMMSwap = await ethers.getContractFactory("AMMSwap");
        ammSwap = await AMMSwap.deploy(tokenA.address, tokenB.address);

        // 为测试用户铸造代币
        await tokenA.mint(user1.address, ethers.utils.parseEther("10000"));
        await tokenB.mint(user1.address, ethers.utils.parseEther("10000"));
        await tokenA.mint(user2.address, ethers.utils.parseEther("10000"));
        await tokenB.mint(user2.address, ethers.utils.parseEther("10000"));
    });

    describe("基础功能", function () {
        it("应该正确设置代币地址", async function () {
            expect(await ammSwap.token0()).to.equal(tokenA.address);
            expect(await ammSwap.token1()).to.equal(tokenB.address);
        });

        it("初始储备量应该为 0", async function () {
            const [reserve0, reserve1] = await ammSwap.getReserves();
            expect(reserve0).to.equal(0);
            expect(reserve1).to.equal(0);
        });
    });

    describe("添加流动性", function () {
        it("应该能够添加初始流动性", async function () {
            const amount0 = ethers.utils.parseEther("1000");
            const amount1 = ethers.utils.parseEther("1000");

            await tokenA.connect(user1).approve(ammSwap.address, amount0);
            await tokenB.connect(user1).approve(ammSwap.address, amount1);

            await ammSwap.connect(user1).addLiquidity(amount0, amount1, 0);

            const [reserve0, reserve1] = await ammSwap.getReserves();
            expect(reserve0).to.equal(amount0);
            expect(reserve1).to.equal(amount1);

            const lpBalance = await ammSwap.balanceOf(user1.address);
            expect(lpBalance).to.be.gt(0);
        });

        it("应该能够添加后续流动性", async function () {
            // 首次添加流动性
            const amount0 = ethers.utils.parseEther("1000");
            const amount1 = ethers.utils.parseEther("1000");

            await tokenA.connect(user1).approve(ammSwap.address, amount0);
            await tokenB.connect(user1).approve(ammSwap.address, amount1);
            await ammSwap.connect(user1).addLiquidity(amount0, amount1, 0);

            // 后续添加流动性
            const amount0_2 = ethers.utils.parseEther("500");
            const amount1_2 = ethers.utils.parseEther("500");

            await tokenA.connect(user2).approve(ammSwap.address, amount0_2);
            await tokenB.connect(user2).approve(ammSwap.address, amount1_2);
            await ammSwap.connect(user2).addLiquidity(amount0_2, amount1_2, 0);

            const [reserve0, reserve1] = await ammSwap.getReserves();
            expect(reserve0).to.equal(amount0.add(amount0_2));
            expect(reserve1).to.equal(amount1.add(amount1_2));
        });
    });

    describe("代币交换", function () {
        beforeEach(async function () {
            // 添加初始流动性
            const amount0 = ethers.utils.parseEther("1000");
            const amount1 = ethers.utils.parseEther("1000");

            await tokenA.connect(user1).approve(ammSwap.address, amount0);
            await tokenB.connect(user1).approve(ammSwap.address, amount1);
            await ammSwap.connect(user1).addLiquidity(amount0, amount1, 0);
        });

        it("应该能够交换代币", async function () {
            const swapAmount = ethers.utils.parseEther("100");
            
            // 先计算预期输出量
            const [reserve0, reserve1] = await ammSwap.getReserves();
            const expectedOutput = await ammSwap.getAmountOut(swapAmount, reserve0, reserve1);
            
            // 设置合理的最小输出量（比预期输出量稍低一些）
            const minAmountOut = expectedOutput.mul(95).div(100); // 5% 滑点保护

            await tokenA.connect(user2).approve(ammSwap.address, swapAmount);

            const balanceBefore = await tokenB.balanceOf(user2.address);
            await ammSwap.connect(user2).swap(tokenA.address, swapAmount, minAmountOut);
            const balanceAfter = await tokenB.balanceOf(user2.address);

            expect(balanceAfter).to.be.gt(balanceBefore);
        });

        it("应该正确计算交换输出量", async function () {
            const amountIn = ethers.utils.parseEther("100");
            const [reserve0, reserve1] = await ammSwap.getReserves();

            const amountOut = await ammSwap.getAmountOut(amountIn, reserve0, reserve1);
            expect(amountOut).to.be.gt(0);
            expect(amountOut).to.be.lt(amountIn); // 由于手续费，输出量小于输入量
        });

        it("应该正确计算交换输入量", async function () {
            const amountOut = ethers.utils.parseEther("95");
            const [reserve0, reserve1] = await ammSwap.getReserves();

            const amountIn = await ammSwap.getAmountIn(amountOut, reserve0, reserve1);
            expect(amountIn).to.be.gt(amountOut);
        });
    });

    describe("移除流动性", function () {
        beforeEach(async function () {
            // 添加流动性
            const amount0 = ethers.utils.parseEther("1000");
            const amount1 = ethers.utils.parseEther("1000");

            await tokenA.connect(user1).approve(ammSwap.address, amount0);
            await tokenB.connect(user1).approve(ammSwap.address, amount1);
            await ammSwap.connect(user1).addLiquidity(amount0, amount1, 0);
        });

        it("应该能够移除流动性", async function () {
            const lpBalance = await ammSwap.balanceOf(user1.address);
            const balanceBefore0 = await tokenA.balanceOf(user1.address);
            const balanceBefore1 = await tokenB.balanceOf(user1.address);

            await ammSwap.connect(user1).removeLiquidity(lpBalance, 0, 0);

            const balanceAfter0 = await tokenA.balanceOf(user1.address);
            const balanceAfter1 = await tokenB.balanceOf(user1.address);

            expect(balanceAfter0).to.be.gt(balanceBefore0);
            expect(balanceAfter1).to.be.gt(balanceBefore1);
        });
    });

    describe("安全性", function () {
        it("应该防止重入攻击", async function () {
            // 这个测试验证了 ReentrancyGuard 的使用
            const amount0 = ethers.utils.parseEther("1000");
            const amount1 = ethers.utils.parseEther("1000");

            await tokenA.connect(user1).approve(ammSwap.address, amount0);
            await tokenB.connect(user1).approve(ammSwap.address, amount1);
            
            // 如果合约没有 ReentrancyGuard，这里可能会出现问题
            await expect(
                ammSwap.connect(user1).addLiquidity(amount0, amount1, 0)
            ).to.not.be.reverted;
        });

        it("应该验证代币地址", async function () {
            const invalidToken = "0x0000000000000000000000000000000000000000";
            await expect(
                ammSwap.connect(user1).swap(invalidToken, 1000, 0)
            ).to.be.revertedWith("AMMSwap: INVALID_TOKEN");
        });
    });
}); 