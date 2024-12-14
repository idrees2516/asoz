use core::traits::Into;
use core::option::OptionTrait;
use core::array::ArrayTrait;
use starknet::ContractAddress;

#[derive(Drop, Serde)]
struct SecurityConfig {
    max_retries: u8,
    lockout_duration: u64,
    min_signature_threshold: u8,
    max_transaction_value: u256,
    emergency_shutdown_threshold: u8
}

#[derive(Drop, Serde)]
struct SecurityIncident {
    id: felt252,
    incident_type: felt252,
    timestamp: u64,
    severity: u8,
    data: Array<felt252>,
    resolved: bool
}

#[derive(Drop, Serde)]
struct SecurityManager {
    config: SecurityConfig,
    incidents: LegacyMap<felt252, SecurityIncident>,
    incident_count: u256,
    retry_counts: LegacyMap<ContractAddress, u8>,
    lockouts: LegacyMap<ContractAddress, u64>,
    authorized_responders: LegacyMap<ContractAddress, bool>,
    governance: ContractAddress,
    paused: bool
}

#[starknet::interface]
trait ISecurityManager<TContractState> {
    fn initialize(
        ref self: TContractState,
        governance: ContractAddress,
        config: SecurityConfig
    );

    fn report_incident(
        ref self: TContractState,
        incident_type: felt252,
        severity: u8,
        data: Array<felt252>
    ) -> felt252;

    fn resolve_incident(
        ref self: TContractState,
        incident_id: felt252
    ) -> bool;

    fn check_security(
        ref self: TContractState,
        actor: ContractAddress,
        action_type: felt252,
        params: Array<felt252>
    ) -> bool;

    fn increment_retry(
        ref self: TContractState,
        actor: ContractAddress
    ) -> bool;

    fn check_lockout(
        self: @TContractState,
        actor: ContractAddress
    ) -> bool;

    fn verify_signature_threshold(
        self: @TContractState,
        signatures: Array<felt252>
    ) -> bool;

    fn verify_transaction_limit(
        self: @TContractState,
        value: u256
    ) -> bool;

    fn emergency_shutdown(
        ref self: TContractState,
        reason: felt252
    ) -> bool;

    fn add_responder(
        ref self: TContractState,
        responder: ContractAddress
    ) -> bool;

    fn remove_responder(
        ref self: TContractState,
        responder: ContractAddress
    ) -> bool;

    fn update_config(
        ref self: TContractState,
        new_config: SecurityConfig
    ) -> bool;

    fn get_incident(
        self: @TContractState,
        incident_id: felt252
    ) -> Option<SecurityIncident>;

    fn pause(ref self: TContractState) -> bool;
    fn unpause(ref self: TContractState) -> bool;
}

#[starknet::contract]
mod SecurityManagerContract {
    use super::{
        SecurityConfig, SecurityIncident, SecurityManager,
        ISecurityManager, ContractAddress
    };
    use starknet::{
        get_caller_address,
        get_block_timestamp
    };

    #[storage]
    struct Storage {
        manager: SecurityManager
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        governance: ContractAddress,
        config: SecurityConfig
    ) {
        self.manager.governance = governance;
        self.manager.config = config;
        self.manager.incident_count = 0;
        self.manager.paused = false;
    }

    #[external(v0)]
    impl SecurityManagerImpl of ISecurityManager<ContractState> {
        fn initialize(
            ref self: ContractState,
            governance: ContractAddress,
            config: SecurityConfig
        ) {
            assert(
                self.manager.incident_count == 0,
                'Already initialized'
            );
            self.manager.governance = governance;
            self.manager.config = config;
        }

        fn report_incident(
            ref self: ContractState,
            incident_type: felt252,
            severity: u8,
            data: Array<felt252>
        ) -> felt252 {
            assert(!self.manager.paused, 'Contract is paused');
            
            // Generate incident ID
            let incident_id = generate_incident_id(
                incident_type,
                get_block_timestamp()
            );
            
            let incident = SecurityIncident {
                id: incident_id,
                incident_type,
                timestamp: get_block_timestamp(),
                severity,
                data,
                resolved: false
            };
            
            self.manager.incidents.insert(incident_id, incident);
            self.manager.incident_count += 1;
            
            // Check for emergency shutdown
            if severity >= self.manager.config.emergency_shutdown_threshold {
                self.emergency_shutdown(incident_type);
            }
            
            incident_id
        }

        fn resolve_incident(
            ref self: ContractState,
            incident_id: felt252
        ) -> bool {
            assert(!self.manager.paused, 'Contract is paused');
            assert(
                self.manager.authorized_responders
                    .get(get_caller_address()),
                'Not authorized responder'
            );
            
            let mut incident = self.manager.incidents
                .get(incident_id)
                .expect('Incident not found');
            
            incident.resolved = true;
            self.manager.incidents.insert(incident_id, incident);
            
            true
        }

        fn check_security(
            ref self: ContractState,
            actor: ContractAddress,
            action_type: felt252,
            params: Array<felt252>
        ) -> bool {
            // Check lockout
            if self.check_lockout(actor) {
                return false;
            }
            
            // Verify action-specific security rules
            match action_type {
                'transaction' => {
                    let value = params[0].into();
                    if !self.verify_transaction_limit(value) {
                        return false;
                    }
                },
                'governance' => {
                    if !self.verify_signature_threshold(params) {
                        return false;
                    }
                },
                _ => {}
            }
            
            true
        }

        fn increment_retry(
            ref self: ContractState,
            actor: ContractAddress
        ) -> bool {
            let current_retries = self.manager.retry_counts.get(actor);
            
            if current_retries >= self.manager.config.max_retries {
                // Apply lockout
                self.manager.lockouts.insert(
                    actor,
                    get_block_timestamp() + 
                    self.manager.config.lockout_duration
                );
                // Reset retry count
                self.manager.retry_counts.insert(actor, 0);
                return false;
            }
            
            self.manager.retry_counts.insert(
                actor,
                current_retries + 1
            );
            true
        }

        fn check_lockout(
            self: @ContractState,
            actor: ContractAddress
        ) -> bool {
            let lockout_end = self.manager.lockouts.get(actor);
            lockout_end > get_block_timestamp()
        }

        fn verify_signature_threshold(
            self: @ContractState,
            signatures: Array<felt252>
        ) -> bool {
            let valid_signatures = count_valid_signatures(
                signatures.clone()
            );
            valid_signatures >= self.manager.config.min_signature_threshold
        }

        fn verify_transaction_limit(
            self: @ContractState,
            value: u256
        ) -> bool {
            value <= self.manager.config.max_transaction_value
        }

        fn emergency_shutdown(
            ref self: ContractState,
            reason: felt252
        ) -> bool {
            self.manager.paused = true;
            
            // Log emergency shutdown
            let shutdown_id = self.report_incident(
                'emergency_shutdown',
                255, // Maximum severity
                array![reason]
            );
            
            true
        }

        fn add_responder(
            ref self: ContractState,
            responder: ContractAddress
        ) -> bool {
            self.only_governance();
            self.manager.authorized_responders.insert(
                responder,
                true
            );
            true
        }

        fn remove_responder(
            ref self: ContractState,
            responder: ContractAddress
        ) -> bool {
            self.only_governance();
            self.manager.authorized_responders.insert(
                responder,
                false
            );
            true
        }

        fn update_config(
            ref self: ContractState,
            new_config: SecurityConfig
        ) -> bool {
            self.only_governance();
            self.manager.config = new_config;
            true
        }

        fn get_incident(
            self: @ContractState,
            incident_id: felt252
        ) -> Option<SecurityIncident> {
            self.manager.incidents.get(incident_id)
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
fn generate_incident_id(
    incident_type: felt252,
    timestamp: u64
) -> felt252 {
    // Generate unique incident ID
    let mut hasher = HashFunctionTrait::new();
    hasher.update(incident_type);
    hasher.update(timestamp.into());
    hasher.finalize()
}

fn count_valid_signatures(
    signatures: Array<felt252>
) -> u8 {
    // Count valid signatures
    let mut valid_count = 0_u8;
    let mut i = 0;
    while i < signatures.len() {
        if verify_signature(signatures[i]) {
            valid_count += 1;
        }
        i += 1;
    }
    valid_count
}

fn verify_signature(signature: felt252) -> bool {
    // Implement signature verification
    true
}
