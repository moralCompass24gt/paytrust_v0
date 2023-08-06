const {expect} = require("chai");
const {loadFixture} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { ethers } = require("hardhat");

describe(
    "Shops Factory", function(){
        async function deployShopsFactoryFixture(){
            //get the signers here 
            const [owner,add1,add2] = await ethers.getSigners();

            const hardhatShopsFactory = await ethers.deployContract("ShopsFactory");

            await hardhatShopsFactory.waitForDeployment();

            // console.log("it is deploy process:",hardhatShopsFactory);
            const shop = hardhatShopsFactory.createShop("shop1",owner.address);
            console.log("test~test",shop.to);
            return {hardhatShopsFactory,owner,add1,add2};
        }

        it("test createShop111",async()=>{
            const {hardhatShopsFactory,owner,add1,add2} = loadFixture(deployShopsFactoryFixture);
            console.log('this is instances111:',hardhatShopsFactory);
        })
        //nest describe calls to operate subsections
        describe("Deploying shopFactory and create shop instances",function(){
            // //暂时没有设置owner变量，就不用对该变量设计测试用例了
            // it("Should set the right owner", async function(){
            //     const {hardhatShopsFactory,owner} = await loadFixture(deployShopsFactoryFixture);
            // });
            
            //测试createShop函数
            it("test createShop",async function(){
                const {hardhatShopsFactory,owner,add1,add2} = loadFixture(deployShopsFactoryFixture);
                console.log('this is instances:',hardhatShopsFactory);
                //调用createShop函数
                const sp1=await hardhatShopsFactory.createShop("shop1",owner.address);
                const sp2=await hardhatShopsFactory.createShop("shop2",add1.address);
                const sp3=await hardhatShopsFactory.createShop("shop3",add2.address);

                //print address of shop factory
                console.log("Shop factory's address at: ",sp1.to);
                console.log('\n');

                //get the address of the deployed shop contracts 
                const sp1_add = await hardhatShopsFactory.list_of_shops(0);
                const sp2_add = await hardhatShopsFactory.list_of_shops(1);
                const sp3_add = await hardhatShopsFactory.list_of_shops(2);

                console.log("shopFactory array of shops, address at index 0:",sp1_add);
                console.log("shopFactory array of shops, address at index 1:",sp2_add);
                console.log("shopFactory array of shops, address at index 2:",sp3_add);

                //Attached the created shop instance to the address it's located at. Call functions
                const shop = await ethers.getContractFactory('Shop');
                const shop1=await shop.attach(sp1_add);
                const shop2=await shop.attach(sp2_add);
                const shop3=await shop.attach(sp3_add);

                //get the shop1's info
                const shop1_owner = await shop1.owner();
                const shop1_name = await shop1._shopName();
                console.log(`Shop 1 \n owner:${shop1_owner}\n name:${shop1_name}`);
                console.log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');

                //get the shop2's info
                const shop2_owner = await shop2.owner();
                const shop2_name = await shop2._shopName();
                console.log(`Shop 2 \n owner:${shop2_owner}\n name:${shop2_name}`);
                console.log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');

                //get the shop3's info
                const shop3_owner = await shop3.owner();
                const shop3_name = await shop3._shopName();
                console.log(`Shop 3 \n owner:${shop3_owner}\n name:${shop3_name}`);
                console.log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
            });
            //测试addShopSuccess事件是否成功
            it("it should emit event addShopSuccess",async ()=>{
                const {hardhatShopsFactory,owner}=await loadFixture(deployShopsFactoryFixture);
                await expect(hardhatShopsFactory.createShop("shop",owner.address)).to.emit(hardhatShopsFactory,"addShopSuccess").withArgs(msg.sender,owner.address,Date.now());
            });
        })
    }
)