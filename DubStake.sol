pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


/**
 * @title Staking Token (3M)
 * @author Kaylon Daniels
 * @notice Implements a basic ERC20 staking token with incentive distribution.
 */
contract DubStake is ERC20, Ownable {
    using SafeMath for uint256;

    uint256 internal triggerdate;

    /**
     * @notice We usually require to know who are all the stakeholders.
     */
    address[] internal stakeholders;

    /**
     * @notice The stakes for each stakeholder.
     */
    mapping(address => uint256) internal stakes;

    mapping(address => uint256) internal stakestart;

    /**
     * @notice The accumulated rewards for each stakeholder.
     */
    mapping(address => uint256) internal rewards;

    /**
     * @notice The constructor for the Staking Token.
     * @param _owner The address to receive all tokens on construction.
     * @param _supply The amount of tokens to mint on construction.
     */
    //constructor(address _owner, uint256 _supply) public
    //{ 
    //    _mint(_owner, _supply);
    //}

    constructor(address _owner, string memory name, string memory symbol, uint256 _supply) ERC20(name, symbol) {
        _mint(_owner, _supply);
        triggerdate = block.timestamp;
    }
    
    function removeStakeStartDate(address _stakeHolder) public {
                     
        stakestart[_stakeHolder] = 0;
     }

    // ————- USDC ONLY ————-
   
    address internal payout;

    // max number of coins to stake
    uint256 max_stake = 5000000;

    mapping(address => bool) public tokenApproved;
    address constant public usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    event Deposit (
        address indexed from,
        address indexed token,
        uint amount
    );

    function receiveTokens(address token, uint amount) public {
        
        tokenApproved[usdc] = true;
        require(tokenApproved[token], "We don't accept those");
        IERC20(token).transferFrom(msg.sender, address(payout), amount);
        emit Deposit(msg.sender, token, amount);
    }

    // ---------- STAKES ----------

    /**
     * @notice A method for a stakeholder to create a stake.

     * @param _stake The size of the stake to be created.
     */
    function createStake(uint256 _stake)
        public
    {
        if (availableStakes(_stake)) {
            _burn(msg.sender, _stake);
            if(stakes[msg.sender] == 0) addStakeholder(msg.sender);
            stakes[msg.sender] = stakes[msg.sender].add(_stake);
        }
    }

    function availableStakes(uint256 _stake) internal view returns (bool) {
        uint256 amtstake = _stake + totalStakes();
        bool available = false;

        if (amtstake <= max_stake) available = true;

        return available;
    }

    /**
     * @notice A method for a stakeholder to remove a stake.
     * @param _stake The size of the stake to be removed.
     */
    function removeStake(uint256 _stake)
        public
    {
        stakes[msg.sender] = stakes[msg.sender].sub(_stake);
        if(stakes[msg.sender] == 0) removeStakeholder(msg.sender);
        _mint(msg.sender, _stake);
    }

    /**
     * @notice A method to retrieve the stake for a stakeholder.
     * @param _stakeholder The stakeholder to retrieve the stake for.
     * @return uint256 The amount of wei staked.
     */
    function stakeOf(address _stakeholder)
        public
        view
        returns(uint256)
    {
        return stakes[_stakeholder];
    }

    /**
     * @notice A method to the aggregated stakes from all stakeholders.
     * @return uint256 The aggregated stakes from all stakeholders.
     */
    function totalStakes()
        public
        view
        returns(uint256)
    {
        uint256 _totalStakes = 0;
        for (uint256 s = 0; s < stakeholders.length; s += 1){
            _totalStakes = _totalStakes.add(stakes[stakeholders[s]]);
        }
        return _totalStakes;
    }

    // ---------- STAKEHOLDERS ----------

    /**
     * @notice A method to check if an address is a stakeholder.
     * @param _address The address to verify.
     * @return bool, uint256 Whether the address is a stakeholder, 
     * and if so its position in the stakeholders array.
     */
    function isStakeholder(address _address)
        public
        view
        returns(bool, uint256)
    {
        for (uint256 s = 0; s < stakeholders.length; s += 1){
            if (_address == stakeholders[s]) return (true, s);
        }
        return (false, 0);
    }

    /**
     * @notice A method to add a stakeholder.
     * @param _stakeholder The stakeholder to add.
     */
    function addStakeholder(address _stakeholder)
        public
    {
        (bool _isStakeholder, ) = isStakeholder(_stakeholder);
        if(!_isStakeholder) {
            stakeholders.push(_stakeholder);
            stakestart[_stakeholder] = block.timestamp;
        }
    }

    /**
     * @notice A method to remove a stakeholder.
     * @param _stakeholder The stakeholder to remove.
     */
    function removeStakeholder(address _stakeholder)
        public
    {
        (bool _isStakeholder, uint256 s) = isStakeholder(_stakeholder);
        if(_isStakeholder){
            stakeholders[s] = stakeholders[stakeholders.length - 1];
            stakeholders.pop();

            removeStakeStartDate(_stakeholder);

        } 
    }

    // ---------- REWARDS ----------
    
    /**
     * @notice A method to allow a stakeholder to check his rewards.
     * @param _stakeholder The stakeholder to check rewards for.
     */
    function rewardOf(address _stakeholder) 
        public
        view
        returns(uint256)
    {
        return rewards[_stakeholder];
    }

    /**
     * @notice A method to the aggregated rewards from all stakeholders.
     * @return uint256 The aggregated rewards from all stakeholders.
     */
    function totalRewards()
        public
        view
        returns(uint256)
    {
        uint256 _totalRewards = 0;
        for (uint256 s = 0; s < stakeholders.length; s += 1){
            _totalRewards = _totalRewards.add(rewards[stakeholders[s]]);
        }
        return _totalRewards;
    }

    /** 
     * @notice A simple method that calculates the rewards for each stakeholder.
     * @param _stakeholder The stakeholder to calculate rewards for.
     */
    function calculateReward(address _stakeholder)
        public
        view
        returns(uint256)
    {
        uint256 profit = stakes[_stakeholder] / 5;
        return profit / 12;
    }

    /**
     * @notice A method to distribute rewards to all stakeholders.
     */
    function distributeRewards() 
        public
        onlyOwner
    {
        for (uint256 s = 0; s < stakeholders.length; s += 1) {
            address stakeholder = stakeholders[s];
            uint256 reward = calculateReward(stakeholder);
            rewards[stakeholder] = rewards[stakeholder].add(reward);
        }
    }

    /**
     * @notice A method to allow a stakeholder to withdraw his rewards.
     */
    function withdrawReward() 
        public
    {
        uint256 reward = rewards[msg.sender];
        rewards[msg.sender] = 0;
        _mint(msg.sender, reward);
    }
}
