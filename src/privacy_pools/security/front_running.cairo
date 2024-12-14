use core::traits::Into;
use core::option::OptionTrait;
use core::array::ArrayTrait;
use starknet::ContractAddress;
use super::super::crypto::hash::{HashFunction, HashFunctionTrait};

#[derive(Drop, Serde)]
struct CommitReveal {
    commitment: felt252,
    revealed: bool,
    reveal_time: u64,
    value: Array<felt252>,
    sender: ContractAddress
}

#[derive(Drop, Serde)]
struct FrontRunningPrevention {
    commitments: LegacyMap<felt252, CommitReveal>,
    min_delay: u64,
    max_delay: u64,
    governance: ContractAddress,
    paused: bool
}

#[starknet::interface]
trait IFrontRunningPrevention<TContractState> {
    fn initialize(
        ref self: TContractState,
        governance: ContractAddress,
        min_delay: u64,
        max_delay: u64
    );

    fn submit_commitment(
        ref self: TContractState,
        commitment: felt252
    ) -> bool;

    fn reveal_commitment(
        ref self: TContractState,
        commitment: felt252,
        value: Array<felt252>
    ) -> bool;

    fn verify_commitment(
        self: @TContractState,
        commitment: felt252,
        value: Array<felt252>
    ) -> bool;

    fn get_commitment(
        self: @TContractState,
        commitment: felt252
    ) -> Option<CommitReveal>;

    fn update_delays(
        ref self: TContractState,
        new_min_delay: u64,
        new_max_delay: u64
    ) -> bool;

    fn pause(ref self: TContractState) -> bool;
    fn unpause(ref self: TContractState) -> bool;
}

#[starknet::contract]
mod FrontRunningPreventionContract {
    use super::{
        CommitReveal, FrontRunningPrevention,
        IFrontRunningPrevention, ContractAddress
    };
    use starknet::{
        get_caller_address,
        get_block_timestamp
    };

    #[storage]
    struct Storage {
        prevention: FrontRunningPrevention
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        governance: ContractAddress,
        min_delay: u64,
        max_delay: u64
    ) {
        self.prevention.governance = governance;
        self.prevention.min_delay = min_delay;
        self.prevention.max_delay = max_delay;
        self.prevention.paused = false;
    }

    #[external(v0)]
    impl FrontRunningPreventionImpl of IFrontRunningPrevention<ContractState> {
        fn initialize(
            ref self: ContractState,
            governance: ContractAddress,
            min_delay: u64,
            max_delay: u64
        ) {
            assert(min_delay < max_delay, 'Invalid delays');
            self.prevention.governance = governance;
            self.prevention.min_delay = min_delay;
            self.prevention.max_delay = max_delay;
        }

        fn submit_commitment(
            ref self: ContractState,
            commitment: felt252
        ) -> bool {
            assert(!self.prevention.paused, 'Contract is paused');
            let caller = get_caller_address();
            
            // Verify commitment doesn't exist
            assert(
                self.prevention.commitments.get(commitment).is_none(),
                'Commitment exists'
            );

            // Create new commitment
            let commit_reveal = CommitReveal {
                commitment,
                revealed: false,
                reveal_time: 0,
                value: ArrayTrait::new(),
                sender: caller
            };

            self.prevention.commitments.insert(
                commitment,
                commit_reveal
            );
            
            true
        }

        fn reveal_commitment(
            ref self: ContractState,
            commitment: felt252,
            value: Array<felt252>
        ) -> bool {
            assert(!self.prevention.paused, 'Contract is paused');
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            // Get commitment
            let mut commit_reveal = self.prevention.commitments
                .get(commitment)
                .expect('Commitment not found');
            
            // Verify caller
            assert(commit_reveal.sender == caller, 'Not commitment owner');
            assert(!commit_reveal.revealed, 'Already revealed');

            // Verify commitment matches value
            assert(
                self.verify_commitment(commitment, value.clone()),
                'Invalid commitment'
            );

            // Update commitment
            commit_reveal.revealed = true;
            commit_reveal.reveal_time = current_time;
            commit_reveal.value = value;

            self.prevention.commitments.insert(
                commitment,
                commit_reveal
            );
            
            true
        }

        fn verify_commitment(
            self: @ContractState,
            commitment: felt252,
            value: Array<felt252>
        ) -> bool {
            // Compute hash of value
            let computed_commitment = self.compute_commitment(value);
            commitment == computed_commitment
        }

        fn get_commitment(
            self: @ContractState,
            commitment: felt252
        ) -> Option<CommitReveal> {
            self.prevention.commitments.get(commitment)
        }

        fn update_delays(
            ref self: ContractState,
            new_min_delay: u64,
            new_max_delay: u64
        ) -> bool {
            self.only_governance();
            assert(new_min_delay < new_max_delay, 'Invalid delays');
            
            self.prevention.min_delay = new_min_delay;
            self.prevention.max_delay = new_max_delay;
            true
        }

        fn pause(ref self: ContractState) -> bool {
            self.only_governance();
            self.prevention.paused = true;
            true
        }

        fn unpause(ref self: ContractState) -> bool {
            self.only_governance();
            self.prevention.paused = false;
            true
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn only_governance(self: @ContractState) {
            assert(
                get_caller_address() == self.prevention.governance,
                'Only governance can call'
            );
        }

        fn compute_commitment(
            self: @ContractState,
            value: Array<felt252>
        ) -> felt252 {
            // Implement commitment computation using hash function
            let mut hasher = HashFunctionTrait::new();
            
            // Add all values to hash
            let mut i = 0;
            while i < value.len() {
                hasher.update(value[i]);
                i += 1;
            }
            
            hasher.finalize()
        }

        fn is_within_timelock(
            self: @ContractState,
            commit_time: u64,
            reveal_time: u64
        ) -> bool {
            let time_diff = reveal_time - commit_time;
            time_diff >= self.prevention.min_delay &&
            time_diff <= self.prevention.max_delay
        }
    }
}
