// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract pledge is AccessControlUpgradeable {
    uint256 internal constant calDecimal = 1e18;
    uint256 internal constant baseDecimal = 1e8;
    uint256 public minAmount = 100e18;
    uint256 constant baseYear = 365 days;

    uint256 settleTime;
    uint256 endTime;
    uint256 interestRate;
    uint256 maxSupply;
    uint256 martgageRate;
    uint256 lendToken;
    uint256 borrowToken;
    address spToken;
    address jpToken;
    uint256 autoLiquidateThreshold;

    uint256 lendFee;
    uint256 borrowFee;
    address swapRouterAddres;
    address payable public feeAddress;
    // uint256 minAmount;

    PoolBaseInfo pool;
    PoolBaseInfo[] public poolBaseInfo;
    PoolState state;
    PoolDataInfo[] public poolDataInfo;

    mapping(address => mapping(uint256 => LendInfo)) userLendInfo;
    mapping(address => mapping(uint256 => BorrowInfo)) userBorrowInfo;

    enum PoolState {
        MATCH,
        EXECUTION,
        FINISH,
        LIQUIDATION,
        UNDONE
    }

    bytes32 public constant ADMIN_ROLE = keccak256("admin_role");

    struct PoolBaseInfo {
        uint256 settleTime;
        uint256 endTime;
        uint256 interestRate;
        uint256 maxSupply;
        uint256 lendSupply;
        uint256 borrowSupply;
        uint256 martgageRate;
        address lendToken;
        address borrowToken;
        address spToken;
        address jpToken;
        uint256 autoLiquidateThreshold;
        PoolState state;
    }
    struct PoolDataInfo {
        uint256 settleAmountLend;
        uint256 settleAmountBorrow;
        uint256 finishAmountLend;
        uint256 finishAmountBorrow;
        uint256 liquidationAmounLend;
        uint256 liquidationAmounBorrow;
    }

    struct BorrowInfo {
        uint256 stakeAmount;
        uint256 refundAmount;
        bool hasNoRefund;
        bool hasNoClaim;
    }

    struct LendInfo {
        uint256 stakeAmount;
        uint256 refundAmount;
        bool hasNoRefund;
        bool hasNoClaim;
    }

    event DepositLend(
        address indexed from,
        address indexed token,
        uint256 amount,
        uint256 mintAmount
    );
    event RefundLend(
        address indexed from,
        address indexed token,
        uint256 refund
    );
    event ClaimLend(
        address indexed from,
        address indexed token,
        uint256 amount
    );
    event WithdrawLend(
        address indexed from,
        address indexed token,
        uint256 amount,
        uint256 burnAmount
    );
    event DepositBorrow(
        address indexed from,
        address indexed token,
        uint256 amount,
        uint256 mintAmount
    );
    event RefundBorrow(
        address indexed from,
        address indexed token,
        uint256 refund
    );
    event ClaimBorrow(
        address indexed from,
        address indexed token,
        uint256 amount
    );
    event WithdrawBorrow(
        address indexed from,
        address indexed token,
        uint256 amount,
        uint256 burnAmount
    );
    event Swap(
        address indexed fromCoin,
        address indexed toCoin,
        uint256 fromValue,
        uint256 toValue
    );
    event EmergencyBorrowWithdrawal(
        address indexed from,
        address indexed token,
        uint256 amount
    );
    event EmergencyLendWithdrawal(
        address indexed from,
        address indexed token,
        uint256 amount
    );
    event StateChange(
        uint256 indexed pid,
        uint256 indexed beforeState,
        uint256 indexed afterState
    );

    event SetFee(uint256 indexed newLendFee, uint256 indexed newBorrowFee);
    event SetSwapRouterAddress(
        address indexed oldSwapAddress,
        address indexed newSwapAddress
    );
    event SetFeeAddress(
        address indexed oldFeeAddress,
        address indexed newFeeAddress
    );
    event SetMinAmount(
        uint256 indexed oldMinAmount,
        uint256 indexed newMinAmount
    );

    constructor() {
        __AccessControl_init();
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function createPoolInfo(
        uint256 _settleTime,
        uint256 _endTime,
        uint256 _interestRate,
        uint256 _maxSupply,
        uint256 _lendSupply,
        uint256 _borrowSupply,
        uint256 _martgageRate,
        address _lendToken,
        address _borrowToken,
        address _spToken,
        address _jpToken,
        uint256 _autoLiquidateThreshold,
        PoolState _state
    ) public {
        require(_endTime > _settleTime, "project end");
        require(
            _spToken == address(0) || _jpToken == address(0),
            "address invalid"
        );

        pool = PoolBaseInfo({
            settleTime: _settleTime,
            endTime: _endTime,
            interestRate: _interestRate,
            maxSupply: _maxSupply,
            lendSupply: _lendSupply,
            borrowSupply: _borrowSupply,
            martgageRate: _martgageRate,
            lendToken: _lendToken,
            borrowToken: _borrowToken,
            spToken: _spToken,
            jpToken: _jpToken,
            autoLiquidateThreshold: _autoLiquidateThreshold,
            state: _state
        });
        poolBaseInfo.push(pool);

         poolDataInfo.push(PoolDataInfo({
        settleAmountLend: 0,
        settleAmountBorrow: 0,
        finishAmountLend: 0,
        finishAmountBorrow: 0,
        liquidationAmounLend: 0,
        liquidationAmounBorrow: 0
    }));
    }

    //设置费用
    function setFee(uint256 _lendFee, uint256 _borrowFee)
        public
        onlyRole(ADMIN_ROLE)
    {
        lendFee = _lendFee;
        borrowFee = _borrowFee;
         emit SetFee(_lendFee, _borrowFee);
    }

    //设置交换路由器地址
    function setSwapRouterAddress(address _swapRouterAddres)
        public
        onlyRole(ADMIN_ROLE)
    {
        require(_swapRouterAddres != address(0), "address not be zero");

         emit SetSwapRouterAddress(swapRouterAddres, _swapRouterAddres);
        swapRouterAddres = _swapRouterAddres;
    }

    //设置手续费接收地址
    function setFee(address payable _feeAddress) public onlyRole(ADMIN_ROLE) {
        require(_feeAddress != address(0), "address not be blank");
         emit SetFeeAddress(feeAddress, _feeAddress);
        feeAddress = _feeAddress;
    }

    //设置最小金额
    function setMinAmount(uint256 _minAmount) public {
        emit SetMinAmount(minAmount, _minAmount);
        minAmount = _minAmount;
    }

    //1 存款借出
    function depositLend(uint256 pid, uint256 stakeAmount) public {
        PoolBaseInfo storage mPool = poolBaseInfo[pid];
        LendInfo storage mLendInfo = userLendInfo[msg.sender][pid];

        require(
            block.timestamp < mPool.settleTime,
            "time later than settle time"
        );
        require(state == PoolState.MATCH, "state not match");
        require(
            stakeAmount <= mPool.maxSupply - mPool.lendSupply,
            "stakeAmount too high"
        );
        require(
            stakeAmount > minAmount,
            "stakeAmount should higher than minAmount"
        );
//  uint256 amount = getPayableAmount(pool.lendToken, _stakeAmount);
 uint256 amount = 0;
   
        mPool.lendSupply -= stakeAmount;
        mLendInfo.stakeAmount += stakeAmount;

        mLendInfo.hasNoClaim = false;
        mLendInfo.hasNoRefund = false;

        emit DepositLend(msg.sender, mPool.lendToken, stakeAmount, amount);

    }

    //2 存款借入
    function depositBorrow(uint256 pid, uint256 stakeAmount) public {
        PoolBaseInfo storage mPool = poolBaseInfo[pid];
        BorrowInfo storage mBorrowInfo = userBorrowInfo[msg.sender][pid];

        require(
            block.timestamp < mPool.settleTime,
            "time later than settle time"
        );
        require(state == PoolState.MATCH, "state not match");

        require(stakeAmount > 0, "stakeAmount should higher than 0");

        mPool.borrowSupply -= stakeAmount;
        mBorrowInfo.stakeAmount += stakeAmount;
    }

    //3 领取借出
    function claimLend(uint256 _pid) public {
        PoolBaseInfo storage mPool = poolBaseInfo[_pid];
        PoolDataInfo storage data = poolDataInfo[_pid];
        LendInfo storage mLendInfo = userLendInfo[msg.sender][_pid];

        require(
            state != PoolState.MATCH && state != PoolState.UNDONE,
            "state should not be match or undone"
        );
        require(mLendInfo.hasNoClaim == true, "user has nothing to claim");
        uint256 userShare = mLendInfo.stakeAmount / mPool.lendSupply; //用户占总供应量比例

        uint256 totalSpAmount = data.settleAmountLend;
        uint256 spAmount = totalSpAmount * userShare;

        mLendInfo.hasNoClaim = true;
    }

    //4 领取接入
    function claimBorrow(uint256 _pid) public {
        PoolBaseInfo storage mPool = poolBaseInfo[_pid];
        PoolDataInfo storage data = poolDataInfo[_pid];
        BorrowInfo storage mBorrowInfo = userBorrowInfo[msg.sender][_pid];

        require(
            state != PoolState.MATCH && state != PoolState.UNDONE,
            "state should not be match or undone"
        );
        require(mBorrowInfo.hasNoClaim == true, "user has nothing to claim");
        uint256 userShare = mBorrowInfo.stakeAmount / mPool.borrowSupply; //用户占总供应量比例

        uint256 totalJpAmount = data.settleAmountLend * mPool.martgageRate;
        uint256 jpAmount = userShare * totalJpAmount;
        // pool.jpCoin.mint(msg.sender, jpAmount);
        uint256 borrowAmount = data.settleAmountLend * userShare;

        mBorrowInfo.hasNoClaim = true;
    }

    //5 提取借出
    function withdrawLend(uint256 _pid, uint256 _spAmount) public {
        PoolBaseInfo storage mPool = poolBaseInfo[_pid];
        PoolDataInfo storage data = poolDataInfo[_pid];
        require(
            state == PoolState.FINISH || state == PoolState.LIQUIDATION,
            "state not FINISH or LIQUIDATION"
        );

        require(_spAmount > 0, "spAmount not enough");
        LendInfo storage mLendInfo = userLendInfo[msg.sender][_pid];

        // if (mLendInfo.stakeAmount >= spAmount) {
        //     mLendInfo.stakeAmount -= spAmount;
        // } else {
        //     mLendInfo.stakeAmount = 0;
        // }

        // pool.spCoin.burn(msg.sender, _spAmount);
        uint256 totalSpAmount = data.settleAmountLend;
        uint256 spShare = (_spAmount * calDecimal) / (totalSpAmount);

        if (mPool.state == PoolState.FINISH) {
            require(
                block.timestamp > mPool.endTime,
                "withdrawLend: less than end time"
            );
            uint256 redeemAmount = (data.finishAmountLend * (spShare)) /
                (calDecimal);
            // _redeem(msg.sender,  mPool.lendToken, redeemAmount);
            emit WithdrawLend(msg.sender,  mPool.lendToken, redeemAmount, _spAmount);
        }

        if (mPool.state == PoolState.LIQUIDATION) {
            require(
                block.timestamp > mPool.settleTime,
                "withdrawLend: less than match time"
            );
            uint256 redeemAmount = (data.liquidationAmounLend * (spShare)) /
                (calDecimal);
            // _redeem(msg.sender,  mPool.lendToken, redeemAmount);
            emit WithdrawLend(msg.sender,  mPool.lendToken, redeemAmount, _spAmount);
        }
    }

    //6 提取借入
    function withdrawBorrow(uint256 _pid, uint256 _jpAmount) public {
        PoolBaseInfo storage mPool = poolBaseInfo[_pid];
        PoolDataInfo storage data = poolDataInfo[_pid];
        require(
            state == PoolState.FINISH || state == PoolState.LIQUIDATION,
            "state not FINISH or LIQUIDATION"
        );

        require(_jpAmount > 0, "jpAmount not enough");
        BorrowInfo storage mBorrowInfo = userBorrowInfo[msg.sender][_pid];
        uint256 totalJpAmount = (data.settleAmountLend * mPool.martgageRate) /
            baseDecimal;
        uint256 jpShare = (_jpAmount * calDecimal) / (totalJpAmount);

        if (mPool.state == PoolState.FINISH) {
            require(
                block.timestamp > mPool.endTime,
                "withdrawBorrow: less than end time"
            );
            uint256 redeemAmount = (data.finishAmountBorrow * (jpShare)) /
                (calDecimal);
            // _redeem(msg.sender, mPool.borrowToken, redeemAmount);
            // emit WithdrawBorrow(msg.sender,  mPool.borrowToken, _jpAmount, redeemAmount);
        }

        if (mPool.state == PoolState.LIQUIDATION) {
            require(
                block.timestamp > mPool.settleTime,
                "withdrawBorrow: less than match time"
            );
            uint256 redeemAmount = (data.liquidationAmounLend * (jpShare)) /
                (calDecimal);
            // _redeem(msg.sender,  mPool.borrowToken, redeemAmount);
            // emit WithdrawBorrow(msg.sender,  mPool.borrowToken, _jpAmount,redeemAmount);
        }
    }

    //退款借出
    function refundLend(uint256 _pid) public {
        PoolBaseInfo storage pool = poolBaseInfo[_pid];
        PoolDataInfo storage data = poolDataInfo[_pid];
        LendInfo storage lendInfo = userLendInfo[msg.sender][_pid];
        require(lendInfo.stakeAmount > 0, "refundLend: not pledged");
        require(
            pool.lendSupply - (data.settleAmountLend) > 0,
            "refundLend: not refund"
        );
        require(!lendInfo.hasNoRefund, "refundLend: repeat refund");

        uint256 userShare = (lendInfo.stakeAmount * (calDecimal)) /
            (pool.lendSupply);
        uint256 refundAmount = ((pool.lendSupply - (data.settleAmountLend)) *
            (userShare)) / (calDecimal);
        // _redeem(msg.sender, pool.lendToken, refundAmount);

        lendInfo.hasNoRefund = true;
        lendInfo.refundAmount = lendInfo.refundAmount + (refundAmount);
        // emit RefundLend(msg.sender, pool.lendToken, refundAmount);
    }

    //退款借入
    function refundBorrow(uint256 _pid) public {
        PoolBaseInfo storage pool = poolBaseInfo[_pid];
        PoolDataInfo storage data = poolDataInfo[_pid];
        BorrowInfo storage borrowInfo = userBorrowInfo[msg.sender][_pid];
        require(
            pool.borrowSupply - (data.settleAmountBorrow) > 0,
            "refundBorrow: not refund"
        );
        require(borrowInfo.stakeAmount > 0, "refundBorrow: not pledged");
        require(!borrowInfo.hasNoRefund, "refundBorrow: again refund");
        uint256 userShare = (borrowInfo.stakeAmount * (calDecimal)) /
            (pool.borrowSupply);
        uint256 refundAmount = ((pool.borrowSupply -
            (data.settleAmountBorrow)) * (userShare)) / (calDecimal);
        // _redeem(msg.sender, pool.borrowToken, refundAmount);_
        borrowInfo.refundAmount = borrowInfo.refundAmount + (refundAmount);
        borrowInfo.hasNoRefund = true;
        // emit RefundBorrow(msg.sender, pool.borrowToken, refundAmount);
    }
}
