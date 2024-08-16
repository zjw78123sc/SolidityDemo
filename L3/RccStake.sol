// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract RccStake {
    mapping(address => mapping(address => uint256)) private _allowances; //授权额度映射。
    mapping(uint256 => mapping(address => uint256)) private _userStake; //质押池-用户-质押数量 映射。
    mapping(uint256 => uint256) private _totalStake; //质押池-总质押数量 映射。
    uint256 _miniStake = 100; //最小质押数量

    mapping(uint256 => Pool) private _Pools; //id-质押池 映射。
    mapping(address => User) private _Users; //用户地址-用户 映射。

    struct Pool {
        // - stTokenAddress: 质押代币的地址。
        // - poolWeight: 质押池的权重，影响奖励分配。
        // - lastRewardBlock: 最后一次计算奖励的区块号。
        // - accRCCPerST: 每个质押代币累积的 RCC 数量。
        // - stTokenAmount: 池中的总质押代币量。
        // - minDepositAmount: 最小质押金额。
        // - unstakeLockedBlocks: 解除质押的锁定区块数。
        address stTokenAddress;
        uint256 poolWeight;
        uint256 lastRewardBlock;
        uint256 accRCCPerST;
        uint256 stTokenAmount;
        uint256 minDepositAmount;
        uint256 unstakeLockedBlocks;
    }

    struct User {
        // - stAmount: 用户质押的代币数量。
        // - finishedRCC: 已分配的 RCC 数量。
        // - pendingRCC: 待领取的 RCC 数量。
        // - requests: 解质押请求列表，每个请求包含解质押数量和解锁区块。
        uint256 stAmount;
        uint256 finishedRCC;
        uint256 pendingRCC;
        ReleaseStakeRequest[] requests;
    }

    struct ReleaseStakeRequest {
        // - requests: 解质押请求列表，每个请求包含解质押数量和解锁区块。
        uint256 stAmount;
        uint256 blockId;
    }

    //2.1 质押功能
    // - 输入参数: 池 ID(_pid)，质押数量(_amount)。
    // - 前置条件: 用户已授权足够的代币给合约。
    // - 后置条件: 用户的质押代币数量增加，池中的总质押代币数量更新。
    // - 异常处理: 质押数量低于最小质押要求时拒绝交易。
    function stake(uint256 _pid, uint256 _amount) public {
        Pool storage pool = _Pools[_pid]; //用storge省gas
        User storage user = _Users[address(msg.sender)];

        uint256 allowance = _allowances[address(msg.sender)][address(this)];
        require(allowance >= _amount, "allowance not enough");
        require(_amount >= pool.minDepositAmount, "stake amount not enough");

        // _userStake[_pid][msg.sender] += _amount;
        user.stAmount += _amount;

        // _totalStake[_pid] += _amount;
        pool.stTokenAmount += _amount;

        // msg.sender.transfer(_amount);
    }

    //2.2 解除质押功能
    // - 输入参数: 池 ID(_pid)，解除质押数量(_amount)。
    // - 前置条件: 用户质押的代币数量足够。
    // - 后置条件: 用户的质押代币数量减少，解除质押请求记录，等待锁定期结束后可提取。
    // - 异常处理: 如果解除质押数量大于用户质押的数量，交易失败。

    function releasStake(uint256 _pid, uint256 _amount) public {
        Pool storage pool = _Pools[_pid];
        uint256 userStake = _userStake[_pid][address(msg.sender)];
        require(userStake >= _amount, "userStake not enough");

        // _userStake[_pid][msg.sender] -= _amount;
        User memory user = _Users[address(msg.sender)];
        user.stAmount -= _amount;

        // _totalStake[_pid] -= _amount;
        pool.stTokenAmount -= _amount;
    }

    // 2.3 领取奖励
    // - 输入参数: 池 ID(_pid)。
    // - 前置条件: 有可领取的奖励。
    // - 后置条件: 用户领取其奖励，清除已领取的奖励记录。
    // - 异常处理: 如果没有可领取的奖励，不执行任何操作。

    function claim(uint256 _pid) public view {
        Pool memory pool = _Pools[_pid];
        User memory user = _Users[address(msg.sender)];

        uint256 bonus = pool.accRCCPerST *
            user.stAmount -
            user.finishedRCC +
            user.pendingRCC;

        require(bonus > 0, "nothing to claim");
        if (bonus > 0) {
            user.pendingRCC = 0;
        }
        // user.finishedRCC = pool.accRCCPerST * user.stAmount;
    }

    //     2.4 添加和更新质押池
    // - 输入参数: 质押代币地址(_stTokenAddress)，池权重(_poolWeight)，最小质押金额(_minDepositAmount)，解除质押锁定区(_unstakeLockedBlocks)。
    // - 前置条件: 只有管理员可操作。
    // - 后置条件: 创建新的质押池或更新现有池的配置。
    // - 异常处理: 权限验证失败或输入数据验证失败。

    function addPool(
        address _stTokenAddress,
        uint256 _poolWeight,
        uint256 _minDepositAmount,
        uint256 _unstakeLockedBlocks
    ) public view {
        Pool pool;

        pool = _Pools[_stTokenAddress];
        pool.poolWeight = _poolWeight;
        pool.minDepositAmount = _minDepositAmount;
        pool.unstakeLockedBlocks = _unstakeLockedBlocks;
        _Pools[_stTokenAddress] = pool;
    }
}
