// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Shop is ERC721, ERC721URIStorage {
    using Counters for Counters.Counter;
    //追踪最近mint的token
    Counters.Counter private _tokenId;
    //shop name
    string public _shopName;
    //Owner of the shop
    address payable public owner;//报错，说是在opz的合约中已经定义过owner
    //current total value of this shop
    uint256 private totalVal = 0;

    //The struct to store info about a activated deal
    struct Deal {
        uint256 tokenId;
        address payable PartyA;
        address payable PartyB;
        bool currentlyActivated;
        uint ActivatedTime;
        uint256 initVal;
        uint256 nominalBal;
        uint256 realBal;
    }

    //This mapping maps tokenId to token info and is helpful when retrieving details about a tokenId
    mapping(uint256 => Deal) private idToActivatedDeal;

    //shop's withdraw factors
    mapping(uint256 => uint[2]) private idToK;

    //events, generate NFT contract successfully
    event DealActivatedSuccess(
        uint256 indexed tokenId,
        address owner,
        address partyA,
        bool currentlyActivated,
        uint256 activatedTime,
        uint256 initVal
    );
    //consume success
    event ConsumeSuccess(
        uint256 indexed tokenId,
        address owner,
        address PartyA,
        bool currentlyActivated,
        uint256 consumeTime,
        uint256 consumeMoney,
        uint256 realBal,
        uint256 nominalBal
    );
    //checkout Success
    event CheckoutSuccess(
        uint256 indexed tokenId,
        address owner,
        address PartyA,
        bool currentlyActivated,
        uint256 checkoutTime,
        uint256 realBal,
        uint256 nominalBal
    );

    constructor(
        string memory _name,
        address payable _owner
    ) ERC721("Shop", _name) {
        _shopName = _name;
        owner = _owner;
    }

    //create NFT contract
    function createToken(
        string memory _tokenURI,
        uint256 initBal
    ) public payable returns (uint) {
        _tokenId.increment();
        uint256 newTokenId = _tokenId.current();

        _safeMint(msg.sender, newTokenId);

        _setTokenURI(newTokenId, _tokenURI);

        createActivatedDeal(newTokenId, initBal, msg.sender);
        return newTokenId;
    }

    //store Deal info
    function createActivatedDeal(
        uint256 tokenId,
        uint initBal,
        address _partyA
    ) private {
        //sanity check
        require(initBal > 0, "Make sure the balance isn't negative");
        require(
            _partyA != address(0),
            "It's illegal to have a deal with address 0"
        );

        uint activatedTime = block.timestamp;
        uint[2] memory k = [uint(80), uint(2)]; //分别对应初始提现额为消费额的80%，借贷利率为2%
        //update the mapping of tokenId's to Deal details
        idToActivatedDeal[tokenId] = Deal(
            tokenId,
            payable(_partyA),
            owner,
            true,
            activatedTime,
            initBal,
            initBal,
            initBal
        );

        //update the mapping of tokenId's to K details
        idToK[tokenId] = k;
        //emit the event for successful generate.
        emit DealActivatedSuccess(
            tokenId,
            owner,
            msg.sender,
            true,
            activatedTime,
            initBal
        );
    }

    //function return all NFT of this shop
    function getAllNFTs() public view returns (Deal[] memory) {
        uint nftCount = _tokenId.current();
        Deal[] memory tokens = new Deal[](nftCount);

        //将目前该商家合约内所有被激活的合同都收集起来
        for (uint i = 0; i < nftCount; i++) {
            uint currentId = i + 1;
            Deal storage currentItem = idToActivatedDeal[currentId];
            tokens[currentId] = currentItem;
            currentId += 1;
        }

        return tokens;
    }

    //function return all NFT of the user in this shop
    function getMyNFTs() public view returns (Deal[] memory) {
        uint totalItemCount = _tokenId.current();
        uint itemCount = 0;
        uint currentIndex = 0;

        //首先要统计当前用户在该商家里有多少合同
        for (uint i = 0; i < totalItemCount; i++) {
            if (
                idToActivatedDeal[i + 1].PartyA == msg.sender &&
                idToActivatedDeal[i + 1].currentlyActivated == true
            ) {
                itemCount += 1;
            }
        }

        //在获取总共用户总共有多少个合同后，就可以将这些合同存起来返回
        Deal[] memory items = new Deal[](itemCount);
        for (uint i = 0; i < totalItemCount; i++) {
            if (
                idToActivatedDeal[i + 1].PartyA == msg.sender &&
                idToActivatedDeal[i + 1].currentlyActivated == true
            ) {
                uint currentId = i + 1;
                Deal storage currentItem = idToActivatedDeal[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }

        return items;
    }

    //执行消费,该函数内仅实现
    // 1.更新名义/实际余额
    // 2.重新计算提现因子
    // 3.调用事件‘消费成功’
    function executeConsume(
        uint256 consumeMoney,
        uint256 tokenId
    ) public payable {
        //检查消费金额为正数
        require(consumeMoney > 0, "The money consumed should be positive!");
        //检查当前卡里还剩的钱足够消费,该步骤在更新实际/名义余额函数中操作
        //更新名义/实际余额
        bool isSuccess = calNomialAndRealBal(tokenId, consumeMoney);
        //只有消费成功了，才需要重新计算K并触发event
        if (isSuccess) {
            //消费成功后重新计算提现因子K
            recalK(tokenId);
            Deal storage item = idToActivatedDeal[tokenId];
            //调用事件‘消费成功’
            emit ConsumeSuccess(
                tokenId,
                owner,
                item.PartyA,
                item.currentlyActivated,
                block.timestamp,
                consumeMoney,
                item.realBal,
                item.nominalBal
            );
        }
    }

    //更新名义/实际余额
    function calNomialAndRealBal(
        uint256 tokenId,
        uint256 consumeMoney
    ) private returns (bool) {
        Deal storage item = idToActivatedDeal[tokenId];
        uint[2] storage K = idToK[tokenId];
        //如果名义余额归零，则说明商家已提供完所有预付服务，则本次消费失败
        if (item.nominalBal == 0) {
            return false;
        }
        //withdraw factor
        uint wf = K[0];
        //首先对名义余额做操作
        if (item.nominalBal > consumeMoney)
            item.nominalBal = item.nominalBal - consumeMoney;
        else {
            item.nominalBal = 0;
        }

        //对实际余额做操作
        //当前提现额度
        uint realWithdraw = (wf * consumeMoney) / 100;
        if (item.realBal > realWithdraw)
            item.realBal = item.realBal - realWithdraw;
        else {
            item.realBal = 0;
        }
        // 将计算出的额度转账给商家(实际函数为完成)
        TransferFromUserToShop(realWithdraw, tokenId);

        return true;
    }

    //function 重新计算提现因子K
    // 需要根据目前的服务质量和次数重新计算
    function recalK(uint256 tokenId) private {
        //先根据tokenId获取要修改的K和deal
        uint[2] storage k = idToK[tokenId];
        Deal storage item = idToActivatedDeal[tokenId];
        //现在的超额提现规则就简单设置为递增10
        // e.g 80%,90%,100%,110%...
        k[0] = k[0] + 10;

        uint balSize = (item.realBal * 100) / item.initVal;
        //利率在提现总额超过预付金的80%后提高一个level
        if (balSize <= 20 && balSize > 0) {
            k[1] = 5;
        }
        //利率在提现总额超过预付金的100%后再提高一个level，这意味着接下来商家再想借钱就是paytrust付钱了
        // 但是讲道理，借贷的账户跟预付金的账户不应该是同一个账户，因为钱的来源主体不一样了，一个是paytrust，另一个是用户的预付金。
        // 所以比较理想的做法应该是，当实际余额为0后，商家可以通过某种操作再在合约的某个记录借贷记录mapping登记。后续还钱也是把钱还给paytrust
        else if (balSize == 0) k[1] = 10;
    }

    //function 开放额度给商家，可以转账，转账的额度等于提现因子乘以消费金额
    function TransferFromUserToShop(uint256 withdraw, uint256 tokenId) private {
        //问题在于现在只更新了账本，没实际转钱啊？实际转钱，涉及到msg.value该怎么操作
        // 涉及到实际转账的操作后续有时间再看吧
    }

    //退卡
    function DeleteDeal(uint256 tokenId) private {
        //获取tokenId对应的Deal
        Deal storage item = idToActivatedDeal[tokenId];
        //将该id对应的Deal的currentlyActivated属性置为false，即表示退卡
        item.currentlyActivated = false;
        emit CheckoutSuccess(
            tokenId,
            owner,
            item.PartyA,
            item.currentlyActivated,
            block.timestamp,
            item.realBal,
            item.nominalBal
        );
    }

    function safeMint(address to, string memory uri) public {
        uint256 tokenId = _tokenId.current();
        _tokenId.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    //Some helper functions
    function getActivatedDealForId(
        uint256 tokenId
    ) public view returns (Deal memory) {
        return idToActivatedDeal[tokenId];
    }

    function getCurrentToken() public view returns (uint256) {
        return _tokenId.current();
    }

    function getNominalAndRealBalForId(
        uint256 tokenId
    ) public view returns (uint[2] memory) {
        uint[2] memory nAndrBal;
        Deal storage item = idToActivatedDeal[tokenId];
        nAndrBal[0] = item.nominalBal;
        nAndrBal[1] = item.realBal;

        return nAndrBal;
    }

    // The following functions are overrides required by Solidity.

    function _burn(
        uint256 tokenId
    ) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
