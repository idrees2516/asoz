use core::traits::Into;
use core::option::OptionTrait;
use core::array::ArrayTrait;
use starknet::ContractAddress;
use starknet::testing::{set_caller_address, set_contract_address};

use super::super::protocol::{
    ASOZProtocol, Transaction, PrivateTransaction, AuditReport
};
use super::super::bulletproofs::BulletproofSystem;
use super::super::zksnark::SnarkSystem;
use super::super::auditor::AuditorFramework;
use super::super::key_management::KeyManagement;

#[test]
fn test_protocol_initialization() {
    // Initialize test addresses
    let owner_address = contract_address_const::<1>();
    let auditor1_address = contract_address_const::<2>();
    let auditor2_address = contract_address_const::<3>();
    let auditor3_address = contract_address_const::<4>();

    // Set up initial auditors
    let mut initial_auditors = ArrayTrait::new();
    initial_auditors.append(auditor1_address);
    initial_auditors.append(auditor2_address);
    initial_auditors.append(auditor3_address);

    // Deploy protocol contract
    set_contract_address(owner_address);
    let contract = ASOZProtocol::deploy(initial_auditors, 2_u256);

    // Verify initialization
    assert(contract.auditor_framework.read().get_threshold() == 2_u256, 'Invalid threshold');
    assert(contract.bulletproof_system.read().is_initialized(), 'Bulletproof not initialized');
    assert(contract.snark_system.read().is_initialized(), 'SNARK not initialized');
}

#[test]
fn test_private_transaction_submission() {
    // Initialize protocol
    let contract = setup_protocol();
    
    // Create a private transaction
    let transaction = create_test_transaction();
    let private_tx = create_test_private_transaction(transaction);

    // Submit transaction
    let result = contract.submit_transaction(private_tx);
    assert(result.is_ok(), 'Transaction submission failed');

    // Verify transaction status
    let tx_id = result.unwrap();
    let status = contract.get_transaction_status(tx_id).unwrap();
    assert(status == 0, 'Invalid initial status'); // Should be pending
}

#[test]
fn test_audit_report_submission() {
    // Initialize protocol
    let contract = setup_protocol();
    
    // Submit a transaction first
    let transaction = create_test_transaction();
    let private_tx = create_test_private_transaction(transaction);
    let tx_id = contract.submit_transaction(private_tx).unwrap();

    // Create and submit audit reports
    let auditor1_address = contract_address_const::<2>();
    let auditor2_address = contract_address_const::<3>();

    let report1 = create_test_audit_report(tx_id, auditor1_address, true);
    let report2 = create_test_audit_report(tx_id, auditor2_address, true);

    // Submit reports
    set_caller_address(auditor1_address);
    let result1 = contract.submit_audit_report(report1);
    assert(result1.is_ok(), 'First report submission failed');

    set_caller_address(auditor2_address);
    let result2 = contract.submit_audit_report(report2);
    assert(result2.is_ok(), 'Second report submission failed');

    // Verify final status
    let status = contract.get_transaction_status(tx_id).unwrap();
    assert(status == 2, 'Invalid final status'); // Should be fully verified
}

// Helper functions
fn setup_protocol() -> ASOZProtocol {
    let owner_address = contract_address_const::<1>();
    let mut initial_auditors = ArrayTrait::new();
    initial_auditors.append(contract_address_const::<2>());
    initial_auditors.append(contract_address_const::<3>());
    initial_auditors.append(contract_address_const::<4>());

    set_contract_address(owner_address);
    ASOZProtocol::deploy(initial_auditors, 2_u256)
}

fn create_test_transaction() -> Transaction {
    Transaction {
        sender: contract_address_const::<5>(),
        recipient: contract_address_const::<6>(),
        amount: 1000_u256,
        nonce: 1_u64,
        timestamp: 1640995200_u64 // 2022-01-01 00:00:00
    }
}

fn create_test_private_transaction(tx: Transaction) -> PrivateTransaction {
    // Create dummy proofs for testing
    let mut commitment = ArrayTrait::new();
    commitment.append(1234_felt252);

    let mut range_proof = ArrayTrait::new();
    range_proof.append(5678_felt252);

    let mut snark_proof = ArrayTrait::new();
    snark_proof.append(9012_felt252);

    PrivateTransaction {
        transaction: tx,
        commitment,
        range_proof,
        snark_proof
    }
}

fn create_test_audit_report(
    tx_id: felt252,
    auditor: ContractAddress,
    approve: bool
) -> AuditReport {
    let mut findings = ArrayTrait::new();
    if !approve {
        findings.append(1_felt252); // Add a finding if not approving
    }

    AuditReport {
        transaction_id: tx_id,
        auditor,
        findings,
        timestamp: 1640995200_u64
    }
}
