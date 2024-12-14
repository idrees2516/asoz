use core::traits::Into;
use core::option::OptionTrait;
use core::array::ArrayTrait;
use starknet::ContractAddress;
use super::super::crypto::hash::{HashFunction, HashFunctionTrait};

#[derive(Drop, Serde)]
struct DisclosureType {
    id: felt252,
    version: u32,
    verifier_address: ContractAddress,
    parameters: Array<felt252>,
    required_proofs: Array<felt252>,
    is_active: bool,
    min_stake: u256,
    max_participants: u32
}

#[derive(Drop, Serde)]
struct DisclosureRegistry {
    owner: ContractAddress,
    disclosure_types: LegacyMap<felt252, DisclosureType>,
    type_count: u32,
    governance_contract: ContractAddress,
    paused: bool,
    supported_hash_functions: Array<HashFunction>
}

#[starknet::interface]
trait IDisclosureRegistry<TContractState> {
    fn initialize(
        ref self: TContractState,
        owner: ContractAddress,
        governance: ContractAddress
    );

    fn add_disclosure_type(
        ref self: TContractState,
        disclosure_type: DisclosureType
    ) -> bool;

    fn update_disclosure_type(
        ref self: TContractState,
        type_id: felt252,
        new_version: DisclosureType
    ) -> bool;

    fn deactivate_disclosure_type(
        ref self: TContractState,
        type_id: felt252
    ) -> bool;

    fn get_disclosure_type(
        self: @TContractState,
        type_id: felt252
    ) -> Option<DisclosureType>;

    fn validate_disclosure(
        self: @TContractState,
        type_id: felt252,
        proof_data: Array<felt252>
    ) -> bool;

    fn is_valid_verifier(
        self: @TContractState,
        verifier_address: ContractAddress
    ) -> bool;

    fn add_supported_hash_function(
        ref self: TContractState,
        hash_function: HashFunction
    ) -> bool;

    fn remove_supported_hash_function(
        ref self: TContractState,
        hash_function_id: felt252
    ) -> bool;

    fn set_governance_contract(
        ref self: TContractState,
        new_governance: ContractAddress
    ) -> bool;

    fn pause(ref self: TContractState) -> bool;
    fn unpause(ref self: TContractState) -> bool;
}

#[starknet::contract]
mod DisclosureRegistryContract {
    use super::{
        DisclosureType, DisclosureRegistry, IDisclosureRegistry,
        ContractAddress, HashFunction
    };
    use starknet::get_caller_address;

    #[storage]
    struct Storage {
        registry: DisclosureRegistry
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        governance: ContractAddress
    ) {
        self.registry.owner = owner;
        self.registry.governance_contract = governance;
        self.registry.type_count = 0;
        self.registry.paused = false;
    }

    #[external(v0)]
    impl DisclosureRegistryImpl of IDisclosureRegistry<ContractState> {
        fn initialize(
            ref self: ContractState,
            owner: ContractAddress,
            governance: ContractAddress
        ) {
            assert(get_caller_address() == self.registry.owner, 'Only owner can initialize');
            self.registry.owner = owner;
            self.registry.governance_contract = governance;
        }

        fn add_disclosure_type(
            ref self: ContractState,
            disclosure_type: DisclosureType
        ) -> bool {
            self.only_governance();
            assert(!self.registry.paused, 'Contract is paused');
            
            let type_id = disclosure_type.id;
            assert(
                self.registry.disclosure_types.get(type_id).is_none(),
                'Type already exists'
            );

            self.registry.disclosure_types.insert(
                type_id,
                disclosure_type
            );
            self.registry.type_count += 1;
            true
        }

        fn update_disclosure_type(
            ref self: ContractState,
            type_id: felt252,
            new_version: DisclosureType
        ) -> bool {
            self.only_governance();
            assert(!self.registry.paused, 'Contract is paused');
            
            let current_type = self.registry.disclosure_types.get(type_id);
            assert(current_type.is_some(), 'Type does not exist');
            assert(
                new_version.version > current_type.unwrap().version,
                'Invalid version'
            );

            self.registry.disclosure_types.insert(
                type_id,
                new_version
            );
            true
        }

        fn deactivate_disclosure_type(
            ref self: ContractState,
            type_id: felt252
        ) -> bool {
            self.only_governance();
            
            let mut disclosure_type = self.registry.disclosure_types.get(type_id);
            assert(disclosure_type.is_some(), 'Type does not exist');
            
            let mut type_data = disclosure_type.unwrap();
            type_data.is_active = false;
            
            self.registry.disclosure_types.insert(
                type_id,
                type_data
            );
            true
        }

        fn get_disclosure_type(
            self: @ContractState,
            type_id: felt252
        ) -> Option<DisclosureType> {
            self.registry.disclosure_types.get(type_id)
        }

        fn validate_disclosure(
            self: @ContractState,
            type_id: felt252,
            proof_data: Array<felt252>
        ) -> bool {
            let disclosure_type = self.registry.disclosure_types.get(type_id);
            assert(disclosure_type.is_some(), 'Type does not exist');
            
            let type_data = disclosure_type.unwrap();
            assert(type_data.is_active, 'Type is not active');
            
            // Validate using the verifier contract
            let verifier = IVerifier::new(type_data.verifier_address);
            verifier.verify_proof(proof_data)
        }

        fn is_valid_verifier(
            self: @ContractState,
            verifier_address: ContractAddress
        ) -> bool {
            // Implement verifier validation logic
            true
        }

        fn add_supported_hash_function(
            ref self: ContractState,
            hash_function: HashFunction
        ) -> bool {
            self.only_governance();
            self.registry.supported_hash_functions.append(hash_function);
            true
        }

        fn remove_supported_hash_function(
            ref self: ContractState,
            hash_function_id: felt252
        ) -> bool {
            self.only_governance();
            // Implement hash function removal logic
            true
        }

        fn set_governance_contract(
            ref self: ContractState,
            new_governance: ContractAddress
        ) -> bool {
            assert(
                get_caller_address() == self.registry.owner,
                'Only owner can set governance'
            );
            self.registry.governance_contract = new_governance;
            true
        }

        fn pause(ref self: ContractState) -> bool {
            self.only_governance();
            self.registry.paused = true;
            true
        }

        fn unpause(ref self: ContractState) -> bool {
            self.only_governance();
            self.registry.paused = false;
            true
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn only_governance(self: @ContractState) {
            assert(
                get_caller_address() == self.registry.governance_contract,
                'Only governance can call'
            );
        }
    }
}

#[starknet::interface]
trait IVerifier<TContractState> {
    fn verify_proof(self: @TContractState, proof_data: Array<felt252>) -> bool;
}
