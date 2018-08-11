pragma solidity 0.4.24;


contract Betting {
    // /* Constructor function, where owner and outcomes are set */
    // function Betting(uint[] _outcomes) public {
    // }

    // /* Fallback function */
    // function() public payable {
    //     revert();
    // }

    struct Gambler {
        bool hasBetted; //if true, that gambler has already betted to prevent multiple betting
        uint expectedOutcome; //index of the selected outcome
        uint bettingWei; //wei amount putting for this bet
    }

    /* Standard state variables */
    // address public owner;
    // address public gamblerA;
    // address public gamblerB;

    // representing an outcome
    uint[] public outcomes;

    // Keeping balances information
    mapping (address => uint256) public balances;

    // Events
    event oracleSelected();
    event bettingStarted();
    event invalidBettingOutcomeEntered(address gAddr);
    event bettingEnded();
    event winnerAnnounced(uint winningOutcomeNumber);
    event gamblerBetted(address gambler);
    event rewardDispersed();
    event LogTransfer(address sender, address to, uint amount);

    // Flag to know if betting is open yet
    bool public bettingIsOpen = false;

    // Winning outcome
    uint winningOutcome;

    // Oracle
    address public oracle;

    // Owner
    address public contractOwner;

    // This declares a state variable that 
    // stores a `Gambler` struct for each possible address.
    mapping(address => Gambler) public gamblers;

    // Bet counter for gamblers
    mapping (address => uint) public betCounter;

    // Number of total bets
    uint public numberOfBets;

    // Total money poured in
    uint totalBetAmount;

    // Mapping for (bets outcome => gambler address)
    mapping (uint => address[]) public bets;

    // Mapping for (bets outcome => total amount poured in for particular outcomes)
    mapping (uint => uint) public outcomesAmount;

    // /* Structs are custom data structures with self-defined parameters */
    // struct Bet {
    //     uint outcome;
    //     uint amount;
    //     bool initialized;
    // }

    // /* Keep track of every gambler's bet */
    // mapping (address => Bet) bets;
    // /* Keep track of every player's winnings (if any) */
    // mapping (address => uint) winnings;
    // /* Keep track of all outcomes (maps index to numerical outcome) */
    // mapping (uint => uint) public outcomes;

    /* Add any events you think are necessary */
    event BetMade(address gambler);
    event BetClosed();

    /* Uh Oh, what are these? */
    modifier onlyOwner() {
        require(msg.sender == contractOwner);
        _; //continue executing rest of method body
    }
    modifier onlyOracle() {
        require(msg.sender == oracle);
        _; //continue executing rest of method body
    }

    modifier gamblerOnly() {
        require(msg.sender != oracle);
        require(msg.sender != contractOwner);
        _;
    }

    modifier canBetOnlyOnce(){
        require(betCounter[msg.sender] == 0);
        _;
    }

    // Create a new betting to choose one of `outcomeNumbers`.
    function Betting(uint[] outcomeNumbers) public {
        contractOwner = msg.sender;

        // Make sure there is at least two outcomes, else betting has no point
        require(outcomeNumbers.length > 1);

        for(uint i = 0; i < outcomeNumbers.length; i++){
            // Make sure these outcome numbers are unique - no duplicates
            if (!_check_uint_item_exists_in_array(outcomeNumbers[i], outcomes)){
                outcomes.push(outcomeNumbers[i]);
            }
        }
    }

    /* Owner chooses their trusted Oracle */
    function chooseOracle(address oracleAddress) public onlyOwner() {
        // Make sure bet has not started yet
        require(!bettingIsOpen && winningOutcome == 0 && oracle == 0X0);

        // Make sure owner cannot select himself / herself as the oracle
        require(oracleAddress != contractOwner);

        oracle = oracleAddress;
        oracleSelected();
        bettingIsOpen = true; // Open betting for gambler
        bettingStarted;
    }

    // /* Gamblers place their bets, preferably after calling checkOutcomes */
    // function makeBet(uint _outcome) public payable returns (bool) {
    // }

    // End Betting
    function endBetting() public onlyOwner {
        bettingIsOpen = false;
        bettingEnded();
    }

    // /* The oracle chooses which outcome wins */
    // function makeDecision(uint _outcome) public oracleOnly() outcomeExists(_outcome) {
        
    // }

    // Make a bet
    function makeABet(uint bettedOutcome) public payable gamblerOnly canBetOnlyOnce{
        address gamblerAddress = msg.sender;

        // Make sure gambling is open first
        require(bettingIsOpen);

        // weiAmount must be greater than 0
        require(msg.value > 0);

        // Make sure betted Outcome is amoung the defined outcomes
        if(!_check_uint_item_exists_in_array(bettedOutcome, outcomes)){
            invalidBettingOutcomeEntered(gamblerAddress);
            revert();
        }

        // Finally record the betting
        gamblers[gamblerAddress] = Gambler({
            hasBetted: true,
            expectedOutcome: bettedOutcome,
            bettingWei: msg.value
        });

        // Increment bet amount
        totalBetAmount += msg.value;

        // Save it for iterating at money dispering time
        bets[bettedOutcome].push(gamblerAddress);
        outcomesAmount[bettedOutcome] += msg.value;

        numberOfBets += 1;
        gamblerBetted(gamblerAddress);
    }

    // A utility function to find if an uint element exists in an array
    function _check_uint_item_exists_in_array(uint needle, uint[] haystack) public pure returns(bool decision){
        for (uint i = 0; i < haystack.length; i++){
            if(needle == haystack[i]){
                return true;
            }
        }
        return false;
    }

    // Select winning outcome
    function selectWinningOutcome(uint selectedOutcome) public onlyOracle {
        require(bettingIsOpen); // Betting is still open
        require(numberOfBets > 1); // Must have more than one gamblers participated till now

        for (uint i = 0; i < outcomes.length; i++){
            if(outcomes[i] == selectedOutcome){
                winningOutcome = outcomes[i];
                break;
            }
        }

        // Make sure the selectedOutcome is in the list of winningOutcome, else exit
        require(winningOutcome != 0);
        bettingIsOpen = false;

        bettingEnded();
        winnerAnnounced(winningOutcome);

        // Disperse the reward
        disperseReward(winningOutcome);
    }

    // Allocate reward
    function disperseReward(uint selectedOutcome) public onlyOracle payable {
        require(!bettingIsOpen); // Betting must be closed by now
        require(selectedOutcome != 0); // Winning outcome must have been selected

        // If no gambler betted to the winning outcome, the oracle wins the sum of the funds
        if (bets[selectedOutcome].length == 0){
            // Send money to oracle
            if (!transfer(oracle, totalBetAmount)){
                revert();
            }
        } else {
            // First find winning gamblers
            address[] storage winning_gamblers = bets[selectedOutcome];
            uint winning_gamblers_total_betted_amount = outcomesAmount[selectedOutcome];

            // The winners will receive a proportional share of the total funds at stake if they all bet on the correct outcome
            for (uint i = 0; i < winning_gamblers.length; i++){
                // TODO - use safemath here for the integer division
                uint amount_to_transfer = ((gamblers[winning_gamblers[i]].bettingWei) / winning_gamblers_total_betted_amount ) * totalBetAmount;
                transfer(winning_gamblers[i], amount_to_transfer);
            }
        }

        rewardDispersed();
    }

    // Transfer the reward
    function transfer(address to, uint value) public returns(bool success){
        if(balances[msg.sender] < value) revert();
        balances[msg.sender] -= value;
        to.transfer(value);
        LogTransfer(msg.sender, to, value);
        return true;
    }

    // Fall back function
    function () public payable {}

    /* Allow anyone to withdraw their winnings safely (if they have enough) */
    // function withdraw(uint withdrawAmount) public returns (uint) {
    // }
    
    // /* Allow anyone to check the outcomes they can bet on */
    // function checkOutcomes(uint outcome) public view returns (uint) {
    // }
    
    // /* Allow anyone to check if they won any bets */
    // function checkWinnings() public view returns(uint) {
    // }

    // /* Call delete() to reset certain state variables. Which ones? That's upto you to decide */
    // function contractReset() public ownerOnly() {
    // }
}
