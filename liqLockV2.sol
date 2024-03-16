/**

    Locker inspired from the Unibot Liquidity locker, made available for anyone

**/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

////// lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol
// OpenZeppelin Contracts v4.4.0 (token/ERC20/IERC20.sol)

/* pragma solidity ^0.8.0; */

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

contract UniswapV2LiquidityLocker is Ownable {
    bool locked = false;
    mapping(address => mapping(address => uint)) public lpUnlockTime;
    mapping(address => mapping(address => uint)) public lpBalanceOfOwner;

    /**
     * @dev Emitted when a lp token is locked.
     */
    event lpLocked(
        address indexed from,
        address indexed lpTokenAddress,
        uint256 indexed tokenId,
        uint unlockEpochTime
    );

    /**
     * @dev Emitted when a lp token lock time is increased.
     */
    event increaseLockTime(
        address indexed from,
        address indexed lpTokenAddress,
        uint256 indexed tokenId,
        uint newUnlockEpochTime
    );

    /**
     *  @dev Emitted when a lp token is unlocked.
     */
    event lpUnlocked(
        address indexed from,
        address indexed lpTokenAddress,
        uint256 indexed tokenId
    );

    constructor() {}

    receive() external payable {}

    // @dev Deposits and locks tokens until unlockEpochTime
    function lockLiquidity(
        address lpTokenAddress,
        uint unlockEpochTime
    ) external {
        require(
            unlockEpochTime > lpUnlockTime[lpTokenAddress][_msgSender()],
            "Unlock time must be greater than previous locks"
        );

        require(
            unlockEpochTime >= block.timestamp + 2592000,
            "Unlock time must be greater than a month"
        );

        require(
            lpBalanceOfOwner[lpTokenAddress][_msgSender()] == 0,
            "LP token already locked, withdraw first or increase current lock for lp"
        );

        // require(unlockEpochTime >= block.timestamp + 180, "Unlock time must be greater than 3 minutes"); // -- FOR TESTING

        IERC20 tokenForLock = IERC20(lpTokenAddress);

        uint userBalance = tokenForLock.balanceOf(msg.sender);
        require(userBalance > 0, "Sender does not hold any LP tokens");

        lpUnlockTime[lpTokenAddress][_msgSender()] = unlockEpochTime;
        lpBalanceOfOwner[lpTokenAddress][_msgSender()] = userBalance;
        tokenForLock.transferFrom(_msgSender(), address(this), userBalance);
        emit lpLocked(
            _msgSender(),
            lpTokenAddress,
            userBalance,
            unlockEpochTime
        );
    }

    // @dev Extends token lock
    function extendLiquidityLock(
        address lpTokenAddress,
        uint newUnlockEpochTime
    ) external {
        require(
            newUnlockEpochTime > lpUnlockTime[lpTokenAddress][_msgSender()],
            "LP is still locked"
        );

        require(
            lpUnlockTime[lpTokenAddress][_msgSender()] != 0,
            "LP does not have a set unlock time"
        );

        emit increaseLockTime(
            _msgSender(),
            lpTokenAddress,
            0,
            newUnlockEpochTime
        );
    }

    // @dev Unlocks and withdraws LP if current time is past unlock time
    function unlockWithdrawLP(address lpTokenAddress) external {
        uint dueLP = lpBalanceOfOwner[lpTokenAddress][_msgSender()];
        require(
            dueLP != 0,
            "Recipient does not hold any LP tokens or LP is already withdrawn"
        );

        require(
            block.timestamp > lpUnlockTime[lpTokenAddress][_msgSender()],
            "LP is still locked"
        );

        require(
            lpUnlockTime[lpTokenAddress][_msgSender()] != 0,
            "LP does not have a set unlock time"
        );

        lpBalanceOfOwner[lpTokenAddress][_msgSender()] = 0;
        IERC20(lpTokenAddress).transfer(_msgSender(), dueLP);
        emit lpUnlocked(_msgSender(), lpTokenAddress, dueLP);
    }

    function withdrawStuckEth() external onlyOwner {
        require(!locked, "Contract is not locked"); //prevent theoretical reentrancy
        locked = true;
        (bool success, ) = _msgSender().call{value: address(this).balance}("");
        require(success);
        locked = false;
    }

    function lockedLiquidityOf(
        address lpTokenAddress
    ) external view returns (uint) {
        return lpUnlockTime[lpTokenAddress][_msgSender()];
    }
}
