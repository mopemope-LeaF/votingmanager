pragma solidity 0.4.24;

import "./math/SafeMath.sol";
import "./math/SafeMath64.sol";
// import "./interfaces/IExecute.sol";

contract Voting {

    using SafeMath for uint256;
    using SafeMath64 for uint64;

    enum VoterState {Absent, Yea, Nay}

    uint64 public constant PCT_BASE = 10 ** 18; // 0% = 0; 1% = 10^16; 100% = 10^18

    string private constant ERROR_NO_VOTE = "VOTING_NO_VOTE";
    string private constant ERROR_INIT_PCTS = "VOTING_INIT_PCTS";
    string private constant ERROR_INIT_SUPPORT_TOO_BIG = "VOTING_INIT_SUPPORT_TOO_BIG";
    string private constant ERROR_CAN_NOT_VOTE = "VOTING_CAN_NOT_VOTE";
    string private constant ERROR_CAN_NOT_EXECUTE = "VOTING_CAN_NOT_EXECUTE";

    struct Vote {
        bool executed;
        uint64 startDate;
        uint64 snapshotBlock;
        uint64 supportRequiredPct;
        uint64 minAcceptQuorumPct;
        uint256 yea;
        uint256 nay;
        address executableContract;
        mapping (address => VoterState) voters;
    }

    // MiniMeToken public token;
    uint64 public supportRequiredPct;
    // uint64 public minAcceptQuorumPct;
    uint64 public voteTime;

    mapping (uint256 => Vote) internal votes;
    uint256 public votesLength;

    event StartVote(uint256 indexed voteId, address indexed creator);
    event CastVote(uint256 indexed voteId, address indexed voter, bool supports);
    event ExecuteVote(uint256 indexed voteId);

    modifier voteExists(uint256 _voteId) {
        require(_voteId < votesLength, ERROR_NO_VOTE);
        _;
    }

    function initialize(uint64 _supportRequiredPct, uint64 _voteTime) external {
        require(_supportRequiredPct < PCT_BASE, ERROR_INIT_SUPPORT_TOO_BIG);

        supportRequiredPct = _supportRequiredPct * PCT_BASE;
        voteTime = _voteTime;
    }

    function newVote(address _executableContract) external returns (uint256 voteId) {
        return _newVote(_executableContract);
    }

    function vote(uint256 _voteId, bool _supports) external voteExists(_voteId) {
        require(_canVote(_voteId, msg.sender), ERROR_CAN_NOT_VOTE);
        _vote(_voteId, _supports, msg.sender);
    }

    function executeVote(uint256 _voteId) external voteExists(_voteId) {
        _executeVote(_voteId);
    }

    function _newVote(address _executableContract) internal returns (uint256 voteId) {
        uint64 snapshotBlock = uint64(block.number) - 1; // avoid double voting in this very block

        voteId = votesLength++;

        Vote storage vote_ = votes[voteId];
        vote_.startDate = uint64(block.timestamp);
        vote_.snapshotBlock = snapshotBlock;
        vote_.supportRequiredPct = supportRequiredPct;
        // vote_.minAcceptQuorumPct = minAcceptQuorumPct;
        vote_.executableContract = _executableContract;

        emit StartVote(voteId, msg.sender);

        _vote(voteId, true, msg.sender);
    }

    function _vote(uint256 _voteId, bool _supports, address _voter) internal {
        Vote storage vote_ = votes[_voteId];

        VoterState state = vote_.voters[_voter];

        if (state == VoterState.Yea) {
            vote_.yea = vote_.yea.sub(1);
        } else if (state == VoterState.Nay) {
            vote_.nay = vote_.nay.sub(1);
        }

        if (_supports) {
            vote_.yea = vote_.yea.add(1);
        } else {
            vote_.nay = vote_.nay.add(1);
        }

        vote_.voters[_voter] = _supports ? VoterState.Yea : VoterState.Nay;

        emit CastVote(_voteId, _voter, _supports);
    }


    function _executeVote(uint256 _voteId) internal {
        require(_canExecute(_voteId), ERROR_CAN_NOT_EXECUTE);
        Vote storage vote_ = votes[_voteId];

        vote_.executed = true;
        // vote_.executableContract.execute(_voteId);
        bytes memory data = abi.encodeWithSignature("execute(uint256)", _voteId);
        vote_.executableContract.call(data);
        emit ExecuteVote(_voteId);
    }

    function _canVote(uint256 _voteId, address _voter) internal view returns (bool) {
        Vote storage vote_ = votes[_voteId];
        return _isVoteOpen(vote_); 
    }

    function _isVoteOpen(Vote storage vote_) internal view returns (bool) {
        return block.timestamp < vote_.startDate.add(voteTime) && !vote_.executed;
    }

    function _canExecute(uint256 _voteId) internal view returns (bool) {
        Vote storage vote_ = votes[_voteId];

        if (vote_.executed) {
            return false;
        }

        // Vote ended?
        if (_isVoteOpen(vote_)) {
            return false;
        }
        // Has enough support?
        uint256 totalVotes = vote_.yea.add(vote_.nay);
        if (!_isValuePct(vote_.yea, totalVotes, vote_.supportRequiredPct)) {
            return false;
        }

        return true;
    }

    function _isValuePct(uint256 _value, uint256 _total, uint256 _pct) internal pure returns (bool) {
        if (_total == 0) {
            return false;
        }

        uint256 computedPct = _value.mul(PCT_BASE) / _total;
        return computedPct > _pct;
    }

}