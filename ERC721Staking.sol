// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

/// @author Taimoor Malik

interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

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
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
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
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
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
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

interface IERC721 is IERC165 {
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );
    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    function balanceOf(address owner) external view returns (uint256 balance);

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function transferFrom(address from, address to, uint256 tokenId) external;

    function approve(address to, uint256 tokenId) external;

    function setApprovalForAll(address operator, bool _approved) external;

    function getApproved(
        uint256 tokenId
    ) external view returns (address operator);

    function isApprovedForAll(
        address owner,
        address operator
    ) external view returns (bool);

    function price() external view returns (uint256 tokenPrice);
}

contract NFTStaking is Ownable {
    uint256 public apyPercentage;
    address public nftAddress;
    address public rewardTokenAddress;

    struct Stake {
        uint256 startTime;
        bool withdrawn;
    }

    struct TotalStake {
        uint256 totalStake;
        uint256 startTime;
    }

    mapping(address => mapping(uint256 => Stake)) public stakes;

    mapping(address => TotalStake) public totalStake;

    event Staked(address indexed staker, uint256 startTime);
    event Claimed(address indexed staker, uint256 amount, uint256 reward);
    event Withdrawn(address indexed staker, uint256 amount, uint256 reward);

    constructor(
        address _nftAddress,
        address _rewardTokenAddress,
        uint256 _apyPercentage
    ) {
        nftAddress = _nftAddress;
        rewardTokenAddress = _rewardTokenAddress;
        apyPercentage = _apyPercentage;
    }

    /// @notice This is an external stake function, this function stakes an nft to claim rewards later
    /// @param _tokenId This parameter indicates address which requires to burn tokens
    function stake(uint256 _tokenId) external {
        require(
            IERC721(nftAddress).balanceOf(msg.sender) > 0,
            "You need to own at least one NFT"
        );
        require(
            IERC721(nftAddress).getApproved(_tokenId) == address(this),
            "You need to approve this contract to transfer your NFT"
        );
        IERC721(nftAddress).transferFrom(msg.sender, address(this), _tokenId);

        uint256 stakeTime;
        // stake time
        if (totalStake[msg.sender].totalStake > 0) {
            stakeTime = totalStake[msg.sender].startTime;
        } else {
            stakeTime = block.timestamp;
        }

        totalStake[msg.sender] = TotalStake(
            totalStake[msg.sender].totalStake + 1,
            stakeTime
        );
        stakes[msg.sender][_tokenId] = Stake(block.timestamp, false);
        emit Staked(msg.sender, block.timestamp);
    }

    /// @notice This is an external withdraw function, this function withdraws specific tokenid of a user with applicable claim rewards
    /// @param _tokenId This parameter indicates address which requires to burn tokens
    function withdraw(uint256 _tokenId) external {
        uint256 totalStaked = totalStake[msg.sender].totalStake;
        uint256 startTime = stakes[msg.sender][_tokenId].startTime;
        uint256 tokenId = _tokenId;

        require(totalStaked > 0, "You have no stake");

        uint256 rate = IERC721(nftAddress).price();
        uint256 per = (rate / 100) * apyPercentage;
        uint256 reward = ((block.timestamp - startTime) * totalStaked * per) /
            (365 days);

        stakes[msg.sender][_tokenId].withdrawn = true;

        if (IERC20(rewardTokenAddress).balanceOf(address(this)) > reward) {
            IERC20(rewardTokenAddress).transfer(msg.sender, reward);
        }

        IERC721(nftAddress).transferFrom(address(this), msg.sender, tokenId);

        totalStake[msg.sender].totalStake = totalStaked - 1;
        totalStake[msg.sender].startTime = block.timestamp;

        emit Withdrawn(msg.sender, totalStaked, reward);
        emit Claimed(msg.sender, totalStaked, reward);
    }

    /// @notice This is a public claimReward function, this function allows stakers to claim their staking reward
    function claimReward() public {
        uint256 totalStaked = totalStake[msg.sender].totalStake;
        uint256 startTime = totalStake[msg.sender].startTime;

        require(totalStaked > 0, "You have no stake");
        require(
            block.timestamp - startTime > 30 days,
            "Cannot claim before 30 days"
        );

        uint256 rate = IERC721(nftAddress).price();
        uint256 per = (rate / 100) * apyPercentage;
        uint256 reward = ((block.timestamp - startTime) * totalStaked * per) /
            (365 days);
        require(reward > 0, "No reward to claim");

        require(
            IERC20(rewardTokenAddress).balanceOf(address(this)) > reward,
            "Insufficient reward balance"
        );
        IERC20(rewardTokenAddress).transfer(msg.sender, reward);

        totalStake[msg.sender].startTime = block.timestamp;

        emit Claimed(msg.sender, totalStaked, reward);
    }

    /// @notice This is an external setAPY function, this function sets annual percentage yield value of staking
    /// @param _apyPercentage This parameter indicates amount of apy to be set
    function setAPY(uint256 _apyPercentage) external onlyOwner {
        apyPercentage = _apyPercentage;
    }

    /// @notice This is an flushContract setAPY function, this function flush all contract tokens to specified address
    /// @param _account This parameter indicates address which will receive all tokens
    function flushContract(address _account) external onlyOwner {
        uint256 balance = IERC20(rewardTokenAddress).balanceOf(address(this));
        IERC20(rewardTokenAddress).transfer(_account, balance);
    }
}
