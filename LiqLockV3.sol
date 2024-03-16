/**

    Locker inspired from the Unibot Liquidity locker, updated for v3 pools, made available for anyone.

**/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
/**
 * @dev Required interface of an ERC-721 compliant contract.
 */
interface IERC721 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC-721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);
}

contract UniswapV3LiquidityLocker is Ownable {
    bool locked = false;
    mapping(address => mapping(uint => uint)) public lpUnlockTime;
    mapping(address => mapping(uint => address)) public lpToOwner;

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
        uint tokenId,
        uint unlockEpochTime
    ) external {
        require(
            unlockEpochTime > lpUnlockTime[lpTokenAddress][tokenId],
            "Unlock time must be greater than previous locks"
        );
        require(
            unlockEpochTime >= block.timestamp + 2592000,
            "Unlock time must be greater than a month"
        );

        // require(
        //     unlockEpochTime >= block.timestamp + 180,
        //     "Unlock time must be greater than 3 minutes"
        // ); // -- FOR TESTING

        require(
            lpToOwner[lpTokenAddress][tokenId] == address(0),
            "LP is already locked"
        );

        IERC721 tokenForLock = IERC721(lpTokenAddress);

        require(
            tokenForLock.ownerOf(tokenId) == _msgSender(),
            "provided LP isn't owned by caller"
        );
        lpUnlockTime[lpTokenAddress][tokenId] = unlockEpochTime;
        lpToOwner[lpTokenAddress][tokenId] = _msgSender();
        tokenForLock.transferFrom(_msgSender(), address(this), tokenId);
        emit lpLocked(_msgSender(), lpTokenAddress, tokenId, unlockEpochTime);
    }

    // @dev Extends token lock
    function extendLiquidityLock(
        address lpTokenAddress,
        uint tokenId,
        uint newUnlockEpochTime
    ) external {
        require(
            newUnlockEpochTime > lpUnlockTime[lpTokenAddress][tokenId],
            "you can't lock for less time than previously locked"
        );
        require(
            lpUnlockTime[lpTokenAddress][tokenId] != 0,
            "LP does not have a set unlock time"
        );

        IERC721 tokenForLock = IERC721(lpTokenAddress);
        require(
            tokenForLock.ownerOf(tokenId) == address(this),
            "can't increase lock time on LP that isn't locked"
        );

        require(
            lpToOwner[lpTokenAddress][tokenId] == _msgSender(),
            "you can't extend lock on LP you don't own"
        );

        lpUnlockTime[lpTokenAddress][tokenId] = newUnlockEpochTime;
        emit increaseLockTime(
            _msgSender(),
            lpTokenAddress,
            tokenId,
            newUnlockEpochTime
        );
    }

    // @dev Unlocks and withdraws LP if current time is past unlock time
    function unlockWithdrawLP(address lpTokenAddress, uint tokenId) external {
        address owner = lpToOwner[lpTokenAddress][tokenId];
        require(owner != address(0), "LP is already withdrawn");

        require(
            block.timestamp > lpUnlockTime[lpTokenAddress][tokenId],
            "LP is still locked"
        );
        require(
            lpUnlockTime[lpTokenAddress][tokenId] != 0,
            "LP does not have a set unlock time"
        );

        require(
            lpToOwner[lpTokenAddress][tokenId] == _msgSender(),
            "you can't withdraw LP you don't own"
        );

        lpToOwner[lpTokenAddress][tokenId] = address(0);
        lpUnlockTime[lpTokenAddress][tokenId] = 0;
        IERC721(lpTokenAddress).transferFrom(
            address(this),
            _msgSender(),
            tokenId
        );

        emit lpUnlocked(_msgSender(), lpTokenAddress, tokenId);
    }

    function withdrawStuckEth() external onlyOwner {
        require(!locked, "Contract is not locked"); //prevent theoretical reentrancy
        locked = true;
        (bool success, ) = _msgSender().call{value: address(this).balance}("");
        require(success);
        locked = false;
    }

    function lockedLiquidityOf(
        address lpTokenAddress,
        uint tokenId
    ) external view returns (uint) {
        return lpUnlockTime[lpTokenAddress][tokenId];
    }
}
