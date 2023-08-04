const {expect} = require("chai");
const {loadFixture} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

//对bank里的各项变量还有函数，事件进行测试
//这里就不用对多个商家进行测试了，就开一个shop实例就行