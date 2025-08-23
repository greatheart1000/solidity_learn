import { network } from "hardhat";

const {ethers} = await network.connect();

async function main(){
    console.log("🚀 多签名合约使用示例");
    console.log("===================\n")
    // 获取账户
    const [] =await ethers.getSigners();
    
}