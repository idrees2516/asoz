#[contract]
mod GovernanceContract {
    use starknet::ContractAddress;
    use core::array::ArrayTrait;
    use core::option::OptionTrait;

    #[event]
    fn ProposalCreated(
        proposal_id: u256,
        proposer: ContractAddress,
        description: felt252,
        timestamp: u64
    ) {}

    #[event]
    fn VoteCast(
        proposal_id: u256,
        voter: ContractAddress,
        support: bool,
        votes: u256,
        timestamp: u64
    ) {}

    #[event]
    fn ProposalExecuted(
        proposal_id: u256,
        executor: ContractAddress,
        timestamp: u64
    ) {}

    #[event]
    fn ParameterUpdated(
        parameter: felt252,
        old_value: u256,
        new_value: u256,
        timestamp: u64
    ) {}

    struct Storage {
        proposals: LegacyMap::<u256, Proposal>,
        votes: LegacyMap::<(u256, ContractAddress), Vote>,
        parameters: LegacyMap::<felt252, u256>,
        next_proposal_id: u256,
        voting_delay: u64,
        voting_period: u64,
        proposal_threshold: u256,
        quorum_votes: u256,
        timelock_delay: u64,
        admin: ContractAddress,
        guardian: ContractAddress
    }

    struct Proposal {
        id: u256,
        proposer: ContractAddress,
        description: felt252,
        start_block: u64,
        end_block: u64,
        executed: bool,
        canceled: bool,
        for_votes: u256,
        against_votes: u256,
        targets: Array<ContractAddress>,
        values: Array<u256>,
        signatures: Array<felt252>,
        calldatas: Array<Array<felt252>>
    }

    struct Vote {
        support: bool,
        votes: u256
    }

    #[constructor]
    fn constructor(
        admin_address: ContractAddress,
        guardian_address: ContractAddress,
        initial_voting_delay: u64,
        initial_voting_period: u64,
        initial_proposal_threshold: u256,
        initial_quorum_votes: u256,
        initial_timelock_delay: u64
    ) {
        admin::write(admin_address);
        guardian::write(guardian_address);
        voting_delay::write(initial_voting_delay);
        voting_period::write(initial_voting_period);
        proposal_threshold::write(initial_proposal_threshold);
        quorum_votes::write(initial_quorum_votes);
        timelock_delay::write(initial_timelock_delay);
        next_proposal_id::write(0);
    }

    #[external]
    fn propose(
        targets: Array<ContractAddress>,
        values: Array<u256>,
        signatures: Array<felt252>,
        calldatas: Array<Array<felt252>>,
        description: felt252
    ) -> u256 {
        let caller = starknet::get_caller_address();
        assert(
            get_votes(caller) >= proposal_threshold::read(),
            'Below proposal threshold'
        );
        
        // Validate proposal
        assert(
            targets.len() == values.len() &&
            values.len() == signatures.len() &&
            signatures.len() == calldatas.len(),
            'Proposal: param length mismatch'
        );
        
        let proposal_id = next_proposal_id::read();
        let start_block = starknet::get_block_number() + voting_delay::read();
        let end_block = start_block + voting_period::read();
        
        // Create proposal
        let proposal = Proposal {
            id: proposal_id,
            proposer: caller,
            description,
            start_block,
            end_block,
            executed: false,
            canceled: false,
            for_votes: 0,
            against_votes: 0,
            targets,
            values,
            signatures,
            calldatas
        };
        
        proposals::write(proposal_id, proposal);
        next_proposal_id::write(proposal_id + 1);
        
        // Emit event
        ProposalCreated(
            proposal_id,
            caller,
            description,
            starknet::get_block_timestamp()
        );
        
        proposal_id
    }

    #[external]
    fn cast_vote(
        proposal_id: u256,
        support: bool
    ) -> bool {
        let caller = starknet::get_caller_address();
        let proposal = proposals::read(proposal_id);
        
        assert(
            state(proposal_id) == 'active',
            'Proposal not active'
        );
        
        let vote_weight = get_votes(caller);
        assert(vote_weight > 0, 'No voting power');
        
        // Record vote
        votes::write(
            (proposal_id, caller),
            Vote { support, votes: vote_weight }
        );
        
        // Update proposal votes
        if support {
            proposal.for_votes += vote_weight;
        } else {
            proposal.against_votes += vote_weight;
        }
        proposals::write(proposal_id, proposal);
        
        // Emit event
        VoteCast(
            proposal_id,
            caller,
            support,
            vote_weight,
            starknet::get_block_timestamp()
        );
        
        true
    }

    #[external]
    fn execute(proposal_id: u256) -> bool {
        assert(
            state(proposal_id) == 'succeeded',
            'Proposal not succeeded'
        );
        
        let mut proposal = proposals::read(proposal_id);
        assert(!proposal.executed, 'Already executed');
        
        // Queue execution
        let execution_time = starknet::get_block_timestamp() +
            timelock_delay::read();
        
        // Execute proposal
        let mut i = 0;
        while i < proposal.targets.len() {
            execute_transaction(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                execution_time
            );
            i += 1;
        }
        
        proposal.executed = true;
        proposals::write(proposal_id, proposal);
        
        // Emit event
        ProposalExecuted(
            proposal_id,
            starknet::get_caller_address(),
            starknet::get_block_timestamp()
        );
        
        true
    }

    #[external]
    fn cancel(proposal_id: u256) -> bool {
        let caller = starknet::get_caller_address();
        let mut proposal = proposals::read(proposal_id);
        
        assert(
            caller == proposal.proposer ||
            caller == guardian::read(),
            'Not authorized'
        );
        assert(!proposal.executed, 'Already executed');
        assert(!proposal.canceled, 'Already canceled');
        
        proposal.canceled = true;
        proposals::write(proposal_id, proposal);
        
        true
    }

    #[external]
    fn set_voting_delay(new_voting_delay: u64) {
        only_admin();
        let old_value = voting_delay::read();
        voting_delay::write(new_voting_delay);
        
        // Emit event
        ParameterUpdated(
            'voting_delay',
            old_value,
            new_voting_delay,
            starknet::get_block_timestamp()
        );
    }

    #[external]
    fn set_voting_period(new_voting_period: u64) {
        only_admin();
        let old_value = voting_period::read();
        voting_period::write(new_voting_period);
        
        // Emit event
        ParameterUpdated(
            'voting_period',
            old_value,
            new_voting_period,
            starknet::get_block_timestamp()
        );
    }

    #[external]
    fn set_proposal_threshold(new_proposal_threshold: u256) {
        only_admin();
        let old_value = proposal_threshold::read();
        proposal_threshold::write(new_proposal_threshold);
        
        // Emit event
        ParameterUpdated(
            'proposal_threshold',
            old_value,
            new_proposal_threshold,
            starknet::get_block_timestamp()
        );
    }

    #[external]
    fn set_quorum_votes(new_quorum_votes: u256) {
        only_admin();
        let old_value = quorum_votes::read();
        quorum_votes::write(new_quorum_votes);
        
        // Emit event
        ParameterUpdated(
            'quorum_votes',
            old_value,
            new_quorum_votes,
            starknet::get_block_timestamp()
        );
    }

    #[view]
    fn get_votes(account: ContractAddress) -> u256 {
        // Implement voting power calculation
        0
    }

    #[view]
    fn state(proposal_id: u256) -> felt252 {
        let proposal = proposals::read(proposal_id);
        let current_block = starknet::get_block_number();
        
        if proposal.canceled {
            return 'canceled';
        }
        
        if proposal.executed {
            return 'executed';
        }
        
        if current_block <= proposal.start_block {
            return 'pending';
        }
        
        if current_block <= proposal.end_block {
            return 'active';
        }
        
        if proposal.for_votes <= proposal.against_votes ||
           proposal.for_votes < quorum_votes::read() {
            return 'defeated';
        }
        
        'succeeded'
    }

    // Internal functions
    fn only_admin() {
        assert(
            starknet::get_caller_address() == admin::read(),
            'Only admin'
        );
    }

    fn execute_transaction(
        target: ContractAddress,
        value: u256,
        signature: felt252,
        calldata: Array<felt252>,
        execution_time: u64
    ) {
        // Implement transaction execution
    }
}
