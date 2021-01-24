pragma solidity ^0.4.24;

contract Execute {

    event ExecuteEvent(uint256 indexed voteId);

    function execute(uint256 _voteId) external {
        emit ExecuteEvent(_voteId); 
        // print("executed vote {}".format(_voteId));
    }
}