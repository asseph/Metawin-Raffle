// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./IVRFv2Consumer.sol";

contract MetawinRaffle {
    // SafeMath is a solidity math library especially designed to support safe math operations: safe means that it prevents overflow when working with uint. You can find it in zeppelin-solidity SafeMath.
    using SafeMath for uint256;  

    enum RaffleStatus {
        ONGOING,
        PENDING_COMPLETION,
        COMPLETE
    }

    //NFT raffle struct
    //what is struct?: where variables of diverse data types can be bundled into one variable or a custom-made type
    struct NftRaffle {
        address creator;
        address nftContractAddress;
        uint256 nftId;
        uint256 ticketPrice;
        uint256 totalPrice; //?
        uint256 maxEntries;
        uint256 period;
        address[] tickets;
        uint256 winnerIndex;
        uint256 createdAt;
        RaffleStatus status;
    }

    //Eth Raffle struct
    struct EthRaffle {
        address creator;
        uint256 rewardEth;
        uint256 ticketPrice;
        uint256 totalPrice;
        uint256 maxEntries;
        uint256 period;
        address[] tickets;
        uint256 numWinner;
        uint256[] winners;
        uint256 createdAt;
        RaffleStatus status;
    }

    //Contract owner address
    address public owner;

    IVRFv2Consumer vrfConsumer;

    //NFT Raffles
    NftRaffle[] public nftRaffles;
    //Eth Raffles
    EthRaffle[] public ethRaffles;

    modifier onlyOwner {
        require(msg.sender == owner);
        _; // meaning?
    }

    constructor(address _vrfConsumer) {
        owner = msg.sender;
        vrfConsumer = IVRFv2Consumer(_vrfConsumer);
    }

    //Create a new NFT raffle
    //nftContract.approve should be called before this function
    function createNftRaffle(
        IERC721 _nftContract,
        uint256 _nftId,
        uint256 _ticketPrice,
        uint256 _numTickets,
        uint256 _rafflePeriod
    ) onlyOwner public returns (uint256) {
        //transfer the NFT from the raffle creator to this contract
        _nftContract.transferFrom(
            msg.sender,
            address(this),
            _nftId
        );

         //init tickets
        address[] memory _tickets;
        //create raffle
        NftRaffle memory _raffle = NftRaffle(
            msg.sender,
            address(_nftContract),
            _nftId,
            _ticketPrice,
            0,
            _numTickets,
            _rafflePeriod,
            _tickets,
            _numTickets,
            block.timestamp,
            RaffleStatus.ONGOING
        );

        //store raffel in state
        nftRaffles.push(_raffle);

        //emit event
        emit NftRaffleCreated(nftRaffles.length - 1, msg.sender);

        return nftRaffles.length;
    }

    //Cancel NFT Raffle
    function cancelNftRaffle(
        uint256 _raffleId
    ) onlyOwner public {
        require(
            block.timestamp > nftRaffles[_raffleId].createdAt + nftRaffles[_raffleId].period,
            "Raffle is not ended yet"
        );

        require(
            nftRaffles[_raffleId].totalPrice == 0, "The winner was chosen" 
        );

        //transfer the NFT from the contract to the raffle creator
        IERC721(nftRaffles[_raffleId].nftContractAddress).transferFrom(
            address(this),
            msg.sender,
            nftRaffles[_raffleId].nftId
        );
    }

    //Create a new Eth Raffle
    function createEthRaffle(
        uint256 _rewardEth,
        uint256 _ticketPrice,
        uint256 _numTickets,
        uint256 _numWinner,
        uint256 _rafflePeriod
    ) onlyOwner public payable returns (uint256) {
        require(msg.value == _rewardEth, "Raffle reward is not set exactly");

        address[] memory _tickets;
        uint256[] memory _winners;

        EthRaffle memory _raffle = EthRaffle(
            msg.sender,
            _rewardEth,
            _ticketPrice,
            0,
            _numTickets,
            _rafflePeriod,
            _tickets,
            _numWinner,
            _winners,
            block.timestamp,
            RaffleStatus.ONGOING
        );

        ethRaffles.push(_raffle);

        emit EthRaffleCreated(ethRaffles.length - 1, msg.sender);

        return ethRaffles.length;
    }

    //Cancel Eth raffle
    function cancelEthRaffle(uint256 _raffleId) onlyOwner public {
        require(
            block.timestamp > ethRaffles[_raffleId].createdAt + ethRaffles[_raffleId].period,
            "Raffle is not ended yet" 
        );

        require(
            ethRaffles[_raffleId].totalPrice == 0, "The winner was chosen" 
        );

        (bool sent, ) = ethRaffles[_raffleId].creator.call{value: ethRaffles[_raffleId].rewardEth}("");
            require(sent, "Failed to send Ether");
    }

    //enter a user in the draw for a given NFT raffle
    function enterNftRaffle(uint256 _raffleId, uint256 _tickets) public payable {
        require(
            uint256(nftRaffles[_raffleId].status) == uint256(RaffleStatus.ONGOING),
            "NFT Raffle no longer active"
        );

        require(block.timestamp < (nftRaffles[_raffleId].createdAt + nftRaffles[_raffleId].period), "Raffle period is over");

        require(
            _tickets.add(nftRaffles[_raffleId].tickets.length) <= nftRaffles[_raffleId].maxEntries,
            "Not enough tickets available"
        );

        require(_tickets > 0, "Not enough _tickets purchased");

        if(_tickets == 1) {
            require(msg.value == nftRaffles[_raffleId].ticketPrice, "Ticket price not paid");
        } else if(_tickets == 15) {
            require(msg.value == 0.12 ether, "Ticket price not paid");
        } else if(_tickets == 35) {
            require(msg.value == 0.24 ether, "Ticket price not paid");
        } else if(_tickets == 75) {
            require(msg.value == 0.48 ether, "Ticket price not paid");
        } else if(_tickets == 155) {
            require(msg.value == 0.96 ether, "Ticket price not paid");
        } else {
            require(msg.value == _tickets.mul(nftRaffles[_raffleId].ticketPrice), "Ticket price not paid");
        }

        //add _tickets
        for (uint256 i = 0; i < _tickets; i++) {
            nftRaffles[_raffleId].tickets.push(payable(msg.sender));
        }

        nftRaffles[_raffleId].totalPrice += msg.value;
        
        emit NftTicketPurchased(_raffleId, msg.sender, _tickets);
    }

    //enter a user in the draw for a given ETH raffle
    function enterEthRaffle(uint256 _raffleId, uint256 _tickets) public payable {
        require(
            uint256(ethRaffles[_raffleId].status) == uint256(RaffleStatus.ONGOING),
            "NFT Raffle no longer active"
        );

        require(
            _tickets.add(ethRaffles[_raffleId].tickets.length) <= ethRaffles[_raffleId].maxEntries,
            "Not enough tickets available"
        );
        
        require(_tickets > 0, "Not enough _tickets purchased");

        if(ethRaffles[_raffleId].period != 0) {
            require(block.timestamp < (ethRaffles[_raffleId].createdAt + ethRaffles[_raffleId].period), "Raffle period is over");

            if(_tickets == 1) {
                require(msg.value == ethRaffles[_raffleId].ticketPrice, "Ticket price not paid");
            } else if(_tickets == 15) {
                require(msg.value == 0.095 ether, "Ticket price not paid");
            } else if(_tickets == 35) {
                require(msg.value == 0.19 ether, "Ticket price not paid");
            } else if(_tickets == 75) {
                require(msg.value == 0.38 ether, "Ticket price not paid");
            } else if(_tickets == 155) {
                require(msg.value == 0.76 ether, "Ticket price not paid");
            } else {
                require(msg.value == _tickets.mul(nftRaffles[_raffleId].ticketPrice), "Ticket price not paid");
            }
        }
        
        for (uint256 i = 0; i < _tickets; i++) {
            ethRaffles[_raffleId].tickets.push(payable(msg.sender));
        }

        ethRaffles[_raffleId].totalPrice += msg.value;

        emit EthTicketPurchased(_raffleId, msg.sender, _tickets);
    }

    function chooseNftWinner(uint256 _raffleId) public returns (uint256) {
        NftRaffle storage raffle = nftRaffles[_raffleId];
        require(block.timestamp >= (raffle.createdAt + raffle.period), "Raffle is not ended yet");
        require(raffle.winnerIndex == raffle.maxEntries, "Winner is already chosen");

        uint256 requestId = vrfConsumer.requestRandomWords();
        // require(vrfConsumer.getRequestStatus(requestId) != 0, "Random result has not returned yet");

        // uint256 randomResult = vrfConsumer.getRequestStatus(requestId);

        // map randomness to value between 0 and raffle.tickets.length
        // (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
        uint256 winnerIndex = requestId % raffle.tickets.length;

        //Input winnerIndex to raffle struct
        raffle.winnerIndex = winnerIndex;

        //award winner
        IERC721(raffle.nftContractAddress).transferFrom(
            address(this),
            raffle.tickets[winnerIndex],
            raffle.nftId
        );

        //pay raffle creator
        (bool sent, ) = raffle.creator.call{value: (raffle.totalPrice)}("");
        require(sent, "Failed to send Ether");

        raffle.status = RaffleStatus.COMPLETE;

        emit NftRaffleCompleted(
            _raffleId,
            raffle.tickets[winnerIndex]
        );

        return winnerIndex;
    }

    function chooseEthWinner(uint256 _raffleId) public returns (uint256) {
        EthRaffle storage raffle = ethRaffles[_raffleId];

        require(block.timestamp >= (raffle.createdAt + raffle.period), "Raffle is not ended yet");
        require(raffle.winners.length == 0, "Winner is already chosen");

        uint256 winnerIdx;
        uint256 requestId;

        for (uint8 i = 0; i < raffle.numWinner; i++) {
            requestId = vrfConsumer.requestRandomWords();
            winnerIdx = requestId % raffle.tickets.length;
            raffle.winners.push(winnerIdx);

            (bool sent, ) = raffle.tickets[winnerIdx].call{value: (raffle.rewardEth.div(raffle.numWinner))}("");
            require(sent, "Failed to send Ether");
        }


        if(raffle.totalPrice > raffle.rewardEth) {
            (bool rewardSent, ) = raffle.creator.call{value: (raffle.totalPrice - raffle.rewardEth)}("");
            require(rewardSent, "Failed to send Ether");
        }

        raffle.status = RaffleStatus.COMPLETE;

        emit EthRaffleCompleted(
            _raffleId,
            raffle.winners
        );

        return winnerIdx;
    }

    event NftRaffleCreated(uint256 id, address creator);
    event NftTicketPurchased(uint256 raffleId, address buyer, uint256 numTickets);
    event NftRaffleCompleted(uint256 id, address winner);

    event EthRaffleCreated(uint256 id, address creator);
    event EthTicketPurchased(uint256 raffleId, address buyer, uint256 numTickets);
    event EthRaffleCompleted(uint256 id, uint256[] winners);
}
