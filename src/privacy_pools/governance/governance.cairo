use core::traits::Into;
use core::option::OptionTrait;
use core::array::ArrayTrait;
use starknet::ContractAddress;

#[derive(Drop, Serde)]
struct Proposal {
    id: u256,
    proposer: ContractAddress,
    description: felt252,
    execution_payload: Array<felt252>,
    voting_start: u64,
    voting_end: u64,
    executed: bool,
    votes_for: u256,
    votes_against: u256,
    quorum: u256
}

#[derive(Drop, Serde)]
struct GovernanceConfig {
    voting_delay: u64,
    voting_period: u64,
    proposal_threshold: u256,
    quorum_threshold: u256,
    timelock_delay: u64,
    guardian: ContractAddress
}

#[starknet::interface]
trait IGovernance<TContractState> {
    fn initialize(
        ref self: TContractState,
        config: GovernanceConfig
    );

    fn propose(
        ref self: TContractState,
        description: felt252,
        execution_payload: Array<felt252>
    ) -> u256;

    fn cast_vote(
        ref self: TContractState,
        proposal_id: u256,
        support: bool
    ) -> bool;

    fn execute_proposal(
        ref self: TContractState,
        proposal_id: u256
    ) -> bool;

    fn queue_proposal(
        ref self: TContractState,
        proposal_id: u256
    ) -> bool;

    fn cancel_proposal(
        ref self: TContractState,
        proposal_id: u256
    ) -> bool;

    fn get_proposal(
        self: @TContractState,
        proposal_id: u256
    ) -> Option<Proposal>;

    fn get_voting_power(
        self: @TContractState,
        account: ContractAddress
    ) -> u256;

    fn update_config(
        ref self: TContractState,
        new_config: GovernanceConfig
    ) -> bool;

    fn set_guardian(
        ref self: TContractState,
        new_guardian: ContractAddress
    ) -> bool;
}

#[starknet::contract]
mod GovernanceContract {
    use super::{
        Proposal, GovernanceConfig, IGovernance,
        ContractAddress
    };
    use starknet::{
        get_caller_address,
        get_block_timestamp
    };

    #[storage]
    struct Storage {
        config: GovernanceConfig,
        proposals: LegacyMap<u256, Proposal>,
        proposal_count: u256,
        voting_power: LegacyMap<ContractAddress, u256>,
        votes: LegacyMap<(u256, ContractAddress), bool>,
        timelock_queue: LegacyMap<u256, u64>,
        guardian_actions: LegacyMap<felt252, bool>
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        initial_config: GovernanceConfig
    ) {
        self.config = initial_config;
        self.proposal_count = 0;
    }

    #[external(v0)]
    impl GovernanceImpl of IGovernance<ContractState> {
        fn initialize(
            ref self: ContractState,
            config: GovernanceConfig
        ) {
            assert(self.proposal_count == 0, 'Already initialized');
            self.config = config;
        }

        fn propose(
            ref self: ContractState,
            description: felt252,
            execution_payload: Array<felt252>
        ) -> u256 {
            let caller = get_caller_address();
            let voting_power = self.get_voting_power(caller);
            
            assert(
                voting_power >= self.config.proposal_threshold,
                'Insufficient voting power'
            );

            let proposal_id = self.proposal_count + 1;
            let current_time = get_block_timestamp();
            
            let proposal = Proposal {
                id: proposal_id,
                proposer: caller,
                description,
                execution_payload,
                voting_start: current_time + self.config.voting_delay,
                voting_end: current_time + self.config.voting_delay + self.config.voting_period,
                executed: false,
                votes_for: 0,
                votes_against: 0,
                quorum: self.config.quorum_threshold
            };

            self.proposals.insert(proposal_id, proposal);
            self.proposal_count = proposal_id;
            
            proposal_id
        }

        fn cast_vote(
            ref self: ContractState,
            proposal_id: u256,
            support: bool
        ) -> bool {
            let caller = get_caller_address();
            let proposal = self.get_proposal(proposal_id).expect('Proposal not found');
            let current_time = get_block_timestamp();
            
            assert(
                current_time >= proposal.voting_start,
                'Voting not started'
            );
            assert(
                current_time <= proposal.voting_end,
                'Voting ended'
            );
            assert(
                !self.votes.get((proposal_id, caller)),
                'Already voted'
            );

            let voting_power = self.get_voting_power(caller);
            assert(voting_power > 0, 'No voting power');

            // Record vote
            self.votes.insert((proposal_id, caller), true);
            
            if support {
                proposal.votes_for += voting_power;
            } else {
                proposal.votes_against += voting_power;
            }

            self.proposals.insert(proposal_id, proposal);
            true
        }

        fn execute_proposal(
            ref self: ContractState,
            proposal_id: u256
        ) -> bool {
            let proposal = self.get_proposal(proposal_id).expect('Proposal not found');
            let current_time = get_block_timestamp();
            
            assert(!proposal.executed, 'Already executed');
            assert(
                current_time > proposal.voting_end,
                'Voting not ended'
            );
            assert(
                proposal.votes_for > proposal.votes_against,
                'Proposal not passed'
            );
            assert(
                proposal.votes_for + proposal.votes_against >= proposal.quorum,
                'Quorum not reached'
            );

            let timelock = self.timelock_queue.get(proposal_id);
            assert(
                current_time >= timelock + self.config.timelock_delay,
                'Timelock not elapsed'
            );

            // Execute proposal
            self.execute_payload(proposal.execution_payload);
            
            let mut updated_proposal = proposal;
            updated_proposal.executed = true;
            self.proposals.insert(proposal_id, updated_proposal);
            
            true
        }

        fn queue_proposal(
            ref self: ContractState,
            proposal_id: u256
        ) -> bool {
            let proposal = self.get_proposal(proposal_id).expect('Proposal not found');
            let current_time = get_block_timestamp();
            
            assert(
                current_time > proposal.voting_end,
                'Voting not ended'
            );
            assert(
                proposal.votes_for > proposal.votes_against,
                'Proposal not passed'
            );
            assert(
                proposal.votes_for + proposal.votes_against >= proposal.quorum,
                'Quorum not reached'
            );

            self.timelock_queue.insert(
                proposal_id,
                current_time
            );
            
            true
        }

        fn cancel_proposal(
            ref self: ContractState,
            proposal_id: u256
        ) -> bool {
            let proposal = self.get_proposal(proposal_id).expect('Proposal not found');
            let caller = get_caller_address();
            
            assert(
                caller == proposal.proposer || caller == self.config.guardian,
                'Not authorized'
            );
            assert(!proposal.executed, 'Already executed');

            self.proposals.delete(proposal_id);
            self.timelock_queue.delete(proposal_id);
            
            true
        }

        fn get_proposal(
            self: @ContractState,
            proposal_id: u256
        ) -> Option<Proposal> {
            self.proposals.get(proposal_id)
        }

        fn get_voting_power(
            self: @ContractState,
            account: ContractAddress
        ) -> u256 {
            self.voting_power.get(account)
        }

        fn update_config(
            ref self: ContractState,
            new_config: GovernanceConfig
        ) -> bool {
            assert(
                get_caller_address() == self.config.guardian,
                'Only guardian'
            );
            self.config = new_config;
            true
        }

        fn set_guardian(
            ref self: ContractState,
            new_guardian: ContractAddress
        ) -> bool {
            assert(
                get_caller_address() == self.config.guardian,
                'Only guardian'
            );
            self.config.guardian = new_guardian;
            true
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn execute_payload(
            ref self: ContractState,
            payload: Array<felt252>
        ) {
            // Implement payload execution logic
            let mut i = 0;
            while i < payload.len() {
                let action = payload[i];
                // Execute action based on type
                match action {
                    'update_parameter' => {
                        let param_id = payload[i + 1];
                        let value = payload[i + 2];
                        self.update_parameter(param_id, value);
                        i += 3;
                    },
                    'upgrade_contract' => {
                        let contract_address = payload[i + 1].into();
                        let new_implementation = payload[i + 2].into();
                        self.upgrade_contract(contract_address, new_implementation);
                        i += 3;
                    },
                    _ => {
                        i += 1;
                    }
                }
            }
        }

        fn update_parameter(
            ref self: ContractState,
            param_id: felt252,
            value: felt252
        ) {
            // Implement parameter update logic
        }

        fn upgrade_contract(
            ref self: ContractState,
            contract_address: ContractAddress,
            new_implementation: ContractAddress
        ) {
            // Implement contract upgrade logic
        }
    }
}
