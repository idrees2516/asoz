use core::traits::Into;
use core::option::OptionTrait;
use core::array::ArrayTrait;
use starknet::ContractAddress;

#[derive(Drop, Serde)]
struct Event {
    id: felt252,
    event_type: felt252,
    emitter: ContractAddress,
    timestamp: u64,
    data: Array<felt252>,
    processed: bool
}

#[derive(Drop, Serde)]
struct EventSubscription {
    subscriber: ContractAddress,
    event_types: Array<felt252>,
    active: bool,
    last_processed: u64
}

#[derive(Drop, Serde)]
struct EventManager {
    events: LegacyMap<felt252, Event>,
    subscriptions: LegacyMap<ContractAddress, EventSubscription>,
    event_count: u256,
    subscription_count: u256,
    governance: ContractAddress,
    paused: bool
}

#[starknet::interface]
trait IEventManager<TContractState> {
    fn initialize(
        ref self: TContractState,
        governance: ContractAddress
    );

    fn emit_event(
        ref self: TContractState,
        event_type: felt252,
        data: Array<felt252>
    ) -> felt252;

    fn subscribe(
        ref self: TContractState,
        event_types: Array<felt252>
    ) -> bool;

    fn unsubscribe(
        ref self: TContractState
    ) -> bool;

    fn process_events(
        ref self: TContractState,
        subscriber: ContractAddress
    ) -> Array<Event>;

    fn get_event(
        self: @TContractState,
        event_id: felt252
    ) -> Option<Event>;

    fn get_subscription(
        self: @TContractState,
        subscriber: ContractAddress
    ) -> Option<EventSubscription>;

    fn pause(ref self: TContractState) -> bool;
    fn unpause(ref self: TContractState) -> bool;
}

#[starknet::contract]
mod EventManagerContract {
    use super::{
        Event, EventSubscription, EventManager,
        IEventManager, ContractAddress
    };
    use starknet::{
        get_caller_address,
        get_block_timestamp
    };

    #[storage]
    struct Storage {
        manager: EventManager
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        governance: ContractAddress
    ) {
        self.manager.governance = governance;
        self.manager.event_count = 0;
        self.manager.subscription_count = 0;
        self.manager.paused = false;
    }

    #[external(v0)]
    impl EventManagerImpl of IEventManager<ContractState> {
        fn initialize(
            ref self: ContractState,
            governance: ContractAddress
        ) {
            assert(
                self.manager.event_count == 0,
                'Already initialized'
            );
            self.manager.governance = governance;
        }

        fn emit_event(
            ref self: ContractState,
            event_type: felt252,
            data: Array<felt252>
        ) -> felt252 {
            assert(!self.manager.paused, 'Contract is paused');
            
            let event_id = generate_event_id(
                event_type,
                get_caller_address(),
                get_block_timestamp()
            );
            
            let event = Event {
                id: event_id,
                event_type,
                emitter: get_caller_address(),
                timestamp: get_block_timestamp(),
                data,
                processed: false
            };
            
            self.manager.events.insert(event_id, event);
            self.manager.event_count += 1;
            
            // Notify subscribers
            self.notify_subscribers(event_id);
            
            event_id
        }

        fn subscribe(
            ref self: ContractState,
            event_types: Array<felt252>
        ) -> bool {
            assert(!self.manager.paused, 'Contract is paused');
            
            let subscriber = get_caller_address();
            
            // Check if already subscribed
            if self.manager.subscriptions.get(subscriber).is_some() {
                return false;
            }
            
            let subscription = EventSubscription {
                subscriber,
                event_types,
                active: true,
                last_processed: get_block_timestamp()
            };
            
            self.manager.subscriptions.insert(
                subscriber,
                subscription
            );
            self.manager.subscription_count += 1;
            
            true
        }

        fn unsubscribe(
            ref self: ContractState
        ) -> bool {
            assert(!self.manager.paused, 'Contract is paused');
            
            let subscriber = get_caller_address();
            
            // Get subscription
            let mut subscription = self.manager.subscriptions
                .get(subscriber)
                .expect('Not subscribed');
            
            subscription.active = false;
            self.manager.subscriptions.insert(
                subscriber,
                subscription
            );
            
            true
        }

        fn process_events(
            ref self: ContractState,
            subscriber: ContractAddress
        ) -> Array<Event> {
            assert(!self.manager.paused, 'Contract is paused');
            
            // Get subscription
            let mut subscription = self.manager.subscriptions
                .get(subscriber)
                .expect('Not subscribed');
            assert(subscription.active, 'Subscription inactive');
            
            let mut events = ArrayTrait::new();
            let mut i = 0;
            while i < self.manager.event_count {
                let event = self.manager.events.get(i.into());
                if event.is_some() {
                    let event_data = event.unwrap();
                    if !event_data.processed &&
                       event_data.timestamp > subscription.last_processed &&
                       is_subscribed_event_type(
                           event_data.event_type,
                           subscription.event_types.clone()
                       ) {
                        events.append(event_data);
                    }
                }
                i += 1;
            }
            
            // Update subscription
            subscription.last_processed = get_block_timestamp();
            self.manager.subscriptions.insert(
                subscriber,
                subscription
            );
            
            events
        }

        fn get_event(
            self: @ContractState,
            event_id: felt252
        ) -> Option<Event> {
            self.manager.events.get(event_id)
        }

        fn get_subscription(
            self: @ContractState,
            subscriber: ContractAddress
        ) -> Option<EventSubscription> {
            self.manager.subscriptions.get(subscriber)
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

        fn notify_subscribers(
            ref self: ContractState,
            event_id: felt252
        ) {
            let event = self.manager.events.get(event_id)
                .expect('Event not found');
            
            let mut i = 0;
            while i < self.manager.subscription_count {
                let subscription = self.manager.subscriptions
                    .get(i.into());
                if subscription.is_some() {
                    let sub_data = subscription.unwrap();
                    if sub_data.active &&
                       is_subscribed_event_type(
                           event.event_type,
                           sub_data.event_types.clone()
                       ) {
                        notify_subscriber(
                            sub_data.subscriber,
                            event_id
                        );
                    }
                }
                i += 1;
            }
        }
    }
}

// Helper functions
fn generate_event_id(
    event_type: felt252,
    emitter: ContractAddress,
    timestamp: u64
) -> felt252 {
    // Generate unique event ID
    let mut hasher = HashFunctionTrait::new();
    hasher.update(event_type);
    hasher.update(emitter.into());
    hasher.update(timestamp.into());
    hasher.finalize()
}

fn is_subscribed_event_type(
    event_type: felt252,
    subscribed_types: Array<felt252>
) -> bool {
    let mut i = 0;
    while i < subscribed_types.len() {
        if subscribed_types[i] == event_type {
            return true;
        }
        i += 1;
    }
    false
}

fn notify_subscriber(
    subscriber: ContractAddress,
    event_id: felt252
) {
    // Implement notification mechanism
    // This could be through a callback, event emission, etc.
}
