// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "contracts/Shop.sol"; 

contract ShopsFactory{
    //实例化shop
    Shop shop;

    //记录创建的商家
    Shop[] public list_of_shops;
    
    //记录添加/创建商家成功
    event addShopSuccess(
        address deployer,
        address shop,
        uint createdTime
    );

    function createShop(string calldata _shopName,address payable _owner)external{
        shop = new Shop(_shopName,_owner);
        list_of_shops.push(shop); 
        uint ct = block.timestamp;
        emit addShopSuccess(address(this), _owner, ct);
    }
}
