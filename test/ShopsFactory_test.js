const {expect} = require("chai");
const {loadFixture} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { ethers } = require("hardhat");

describe(
    "Shops Factory", function(){
        async function deployShopsFactoryFixture(){
            //get the signers here 
            const [owner] = await ethers.getSigners();

            const hardhatShopsFactory = await ethers.deployContract("ShpsFactory");

            await hardhatShopsFactory.waitForDeployment();

            return {hardhatShopsFactory,owner};
        }
        //nest describe calls to operate subsections
        describe("deployment",function(){
            // //暂时没有设置owner变量，就不用对该变量设计测试用例了
            // it("Should set the right owner", async function(){
            //     const {hardhatShopsFactory,owner} = await loadFixture(deployShopsFactoryFixture);
            // });
            
            //测试createShop函数

            //测试list_of_shop是否记载正确

            //测试addShopSuccess事件是否成功
        })
    }
)