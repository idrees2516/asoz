use core::traits::Into;
use core::option::OptionTrait;
use core::array::ArrayTrait;
use starknet::ContractAddress;

#[derive(Drop, Serde)]
struct State {
    version: u256,
    merkle_root: felt252,
    timestamp: u64,
    validator: ContractAddress,
    signature: Array<felt252>
}

#[derive(Drop, Serde)]
struct StateUpdate {
    id: felt252,
    old_state: State,
    new_state: State,
    changes: Array<felt252>,
    metadata: Array<felt252>
}

#[derive(Drop, Serde)]
struct StateManager {
    states: LegacyMap<u256, State>,
    updates: LegacyMap<felt252, StateUpdate>,
    current_version: u256,
    update_count: u256,
    authorized_validators: LegacyMap<ContractAddress, bool>,
    governance: ContractAddress,
    paused: bool
}

#[starknet::interface]
trait IStateManager<TContractState> {
    fn initialize(
        ref self: TContractState,
        governance: ContractAddress,
        initial_state: State
    );

    fn update_state(
        ref self: TContractState,
        new_merkle_root: felt252,
        changes: Array<felt252>,
        metadata: Array<felt252>
    ) -> felt252;

    fn verify_state(
        self: @TContractState,
        version: u256
    ) -> bool;

    fn get_state(
        self: @TContractState,
        version: u256
    ) -> Option<State>;

    fn get_update(
        self: @TContractState,
        update_id: felt252
    ) -> Option<StateUpdate>;

    fn get_current_state(
        self: @TContractState
    ) -> State;

    fn add_validator(
        ref self: TContractState,
        validator: ContractAddress
    ) -> bool;

    fn remove_validator(
        ref self: TContractState,
        validator: ContractAddress
    ) -> bool;

    fn pause(ref self: TContractState) -> bool;
    fn unpause(ref self: TContractState) -> bool;
}

#[starknet::contract]
mod StateManagerContract {
    use super::{
        State, StateUpdate, StateManager,
        IStateManager, ContractAddress
    };
    use starknet::{
        get_caller_address,
        get_block_timestamp
    };

    #[storage]
    struct Storage {
        manager: StateManager
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        governance: ContractAddress,
        initial_state: State
    ) {
        self.manager.governance = governance;
        self.manager.current_version = 0;
        self.manager.update_count = 0;
        self.manager.paused = false;
        
        // Store initial state
        self.manager.states.insert(0, initial_state);
    }

    #[external(v0)]
    impl StateManagerImpl of IStateManager<ContractState> {
        fn initialize(
            ref self: ContractState,
            governance: ContractAddress,
            initial_state: State
        ) {
            assert(
                self.manager.current_version == 0,
                'Already initialized'
            );
            self.manager.governance = governance;
            self.manager.states.insert(0, initial_state);
        }

        fn update_state(
            ref self: ContractState,
            new_merkle_root: felt252,
            changes: Array<felt252>,
            metadata: Array<felt252>
        ) -> felt252 {
            assert(!self.manager.paused, 'Contract is paused');
            assert(
                self.manager.authorized_validators
                    .get(get_caller_address()),
                'Not authorized validator'
            );
            
            // Get current state
            let old_state = self.manager.states
                .get(self.manager.current_version)
                .expect('State not found');
            
            // Create new state
            let new_state = State {
                version: self.manager.current_version + 1,
                merkle_root: new_merkle_root,
                timestamp: get_block_timestamp(),
                validator: get_caller_address(),
                signature: sign_state(
                    new_merkle_root,
                    get_caller_address()
                )
            };
            
            // Generate update ID
            let update_id = generate_update_id(
                old_state.merkle_root,
                new_merkle_root,
                get_block_timestamp()
            );
            
            // Create state update
            let update = StateUpdate {
                id: update_id,
                old_state,
                new_state: new_state.clone(),
                changes,
                metadata
            };
            
            // Store new state and update
            self.manager.states.insert(
                new_state.version,
                new_state
            );
            self.manager.updates.insert(update_id, update);
            
            // Update counters
            self.manager.current_version += 1;
            self.manager.update_count += 1;
            
            update_id
        }

        fn verify_state(
            self: @ContractState,
            version: u256
        ) -> bool {
            let state = self.manager.states.get(version)
                .expect('State not found');
            
            verify_state_signature(
                state.merkle_root,
                state.validator,
                state.signature.clone()
            )
        }

        fn get_state(
            self: @ContractState,
            version: u256
        ) -> Option<State> {
            self.manager.states.get(version)
        }

        fn get_update(
            self: @ContractState,
            update_id: felt252
        ) -> Option<StateUpdate> {
            self.manager.updates.get(update_id)
        }

        fn get_current_state(
            self: @ContractState
        ) -> State {
            self.manager.states.get(self.manager.current_version)
                .expect('State not found')
        }

        fn add_validator(
            ref self: ContractState,
            validator: ContractAddress
        ) -> bool {
            self.only_governance();
            self.manager.authorized_validators.insert(
                validator,
                true
            );
            true
        }

        fn remove_validator(
            ref self: ContractState,
            validator: ContractAddress
        ) -> bool {
            self.only_governance();
            self.manager.authorized_validators.insert(
                validator,
                false
            );
            true
        }

        fn pause(ref self: ContractState) -> bool {
            self.only_governance();
            self.manager.paused = true;
            true
        }

        fn unpause(ref self: ContractState) -> bool {
            self.only_governance();
            self.manager.paused = false;
            true
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn only_governance(self: @ContractState) {
            assert(
                get_caller_address() == self.manager.governance,
                'Only governance can call'
            );
        }
    }
}

// Helper functions
fn generate_update_id(
    old_root: felt252,
    new_root: felt252,
    timestamp: u64
) -> felt252 {
    // Generate unique update ID
    let mut hasher = HashFunctionTrait::new();
    hasher.update(old_root);
    hasher.update(new_root);
    hasher.update(timestamp.into());
    hasher.finalize()
}

fn sign_state(
    merkle_root: felt252,
    validator: ContractAddress
) -> Array<felt252> {
    // Generate state signature
    let mut signature = ArrayTrait::new();
    signature.append(merkle_root);
    signature.append(validator.into());
    signature
}

fn verify_state_signature(
    merkle_root: felt252,
    validator: ContractAddress,
    signature: Array<felt252>
) -> bool {
    // Verify state signature
    signature[0] == merkle_root &&
    signature[1] == validator.into()
}
