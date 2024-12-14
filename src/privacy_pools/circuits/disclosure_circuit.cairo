use core::traits::Into;
use core::option::OptionTrait;
use core::array::ArrayTrait;
use super::super::super::crypto::field::{FieldElement, FieldElementTrait};

#[derive(Drop, Serde)]
struct DisclosureCircuit {
    inputs: Array<WireValue>,
    outputs: Array<WireValue>,
    constraints: Array<Constraint>,
    witness: Array<WireValue>
}

#[derive(Drop, Serde)]
struct WireValue {
    index: u32,
    value: FieldElement,
    is_public: bool
}

#[derive(Drop, Serde)]
struct Constraint {
    left: WireTerm,
    right: WireTerm,
    output: WireTerm
}

#[derive(Drop, Serde)]
struct WireTerm {
    wires: Array<(u32, FieldElement)>,
    constant: FieldElement
}

trait DisclosureCircuitTrait {
    fn new() -> DisclosureCircuit;
    fn add_input(ref self: DisclosureCircuit, value: FieldElement, is_public: bool) -> u32;
    fn add_output(ref self: DisclosureCircuit, value: FieldElement, is_public: bool) -> u32;
    fn add_witness(ref self: DisclosureCircuit, value: FieldElement) -> u32;
    fn add_constraint(ref self: DisclosureCircuit, constraint: Constraint);
    fn verify(ref self: DisclosureCircuit) -> bool;
}

impl DisclosureCircuitImplementation of DisclosureCircuitTrait {
    fn new() -> DisclosureCircuit {
        DisclosureCircuit {
            inputs: ArrayTrait::new(),
            outputs: ArrayTrait::new(),
            constraints: ArrayTrait::new(),
            witness: ArrayTrait::new()
        }
    }

    fn add_input(
        ref self: DisclosureCircuit,
        value: FieldElement,
        is_public: bool
    ) -> u32 {
        let index = (self.inputs.len() + self.outputs.len() + self.witness.len()) as u32;
        
        self.inputs.append(
            WireValue {
                index,
                value,
                is_public
            }
        );
        
        index
    }

    fn add_output(
        ref self: DisclosureCircuit,
        value: FieldElement,
        is_public: bool
    ) -> u32 {
        let index = (self.inputs.len() + self.outputs.len() + self.witness.len()) as u32;
        
        self.outputs.append(
            WireValue {
                index,
                value,
                is_public
            }
        );
        
        index
    }

    fn add_witness(
        ref self: DisclosureCircuit,
        value: FieldElement
    ) -> u32 {
        let index = (self.inputs.len() + self.outputs.len() + self.witness.len()) as u32;
        
        self.witness.append(
            WireValue {
                index,
                value,
                is_public: false
            }
        );
        
        index
    }

    fn add_constraint(
        ref self: DisclosureCircuit,
        constraint: Constraint
    ) {
        self.constraints.append(constraint);
    }

    fn verify(ref self: DisclosureCircuit) -> bool {
        let mut i = 0;
        while i < self.constraints.len() {
            let constraint = self.constraints[i];
            
            // Evaluate left term
            let left_value = evaluate_term(
                constraint.left,
                self.inputs,
                self.outputs,
                self.witness
            );
            
            // Evaluate right term
            let right_value = evaluate_term(
                constraint.right,
                self.inputs,
                self.outputs,
                self.witness
            );
            
            // Evaluate output term
            let output_value = evaluate_term(
                constraint.output,
                self.inputs,
                self.outputs,
                self.witness
            );
            
            // Check constraint satisfaction
            if left_value * right_value != output_value {
                return false;
            }
            
            i += 1;
        }
        
        true
    }
}

// Helper functions
fn evaluate_term(
    term: WireTerm,
    inputs: Array<WireValue>,
    outputs: Array<WireValue>,
    witness: Array<WireValue>
) -> FieldElement {
    let mut result = term.constant;
    let mut i = 0;
    
    while i < term.wires.len() {
        let (index, coefficient) = term.wires[i];
        let wire_value = get_wire_value(
            index,
            inputs,
            outputs,
            witness
        );
        
        result = result + coefficient * wire_value;
        i += 1;
    }
    
    result
}

fn get_wire_value(
    index: u32,
    inputs: Array<WireValue>,
    outputs: Array<WireValue>,
    witness: Array<WireValue>
) -> FieldElement {
    // Check inputs
    let mut i = 0;
    while i < inputs.len() {
        if inputs[i].index == index {
            return inputs[i].value;
        }
        i += 1;
    }
    
    // Check outputs
    i = 0;
    while i < outputs.len() {
        if outputs[i].index == index {
            return outputs[i].value;
        }
        i += 1;
    }
    
    // Check witness
    i = 0;
    while i < witness.len() {
        if witness[i].index == index {
            return witness[i].value;
        }
        i += 1;
    }
    
    FieldElement::zero()
}

// Circuit builder functions
fn build_identity_circuit() -> DisclosureCircuit {
    let mut circuit = DisclosureCircuitTrait::new();
    
    // Add input and output
    let input = circuit.add_input(FieldElement::one(), true);
    let output = circuit.add_output(FieldElement::one(), true);
    
    // Add identity constraint
    circuit.add_constraint(
        Constraint {
            left: WireTerm {
                wires: array![(input, FieldElement::one())],
                constant: FieldElement::zero()
            },
            right: WireTerm {
                wires: array![],
                constant: FieldElement::one()
            },
            output: WireTerm {
                wires: array![(output, FieldElement::one())],
                constant: FieldElement::zero()
            }
        }
    );
    
    circuit
}

fn build_range_circuit(bits: u32) -> DisclosureCircuit {
    let mut circuit = DisclosureCircuitTrait::new();
    
    // Add input
    let input = circuit.add_input(FieldElement::one(), true);
    
    // Add bit decomposition witnesses
    let mut bit_witnesses = ArrayTrait::new();
    let mut i = 0;
    while i < bits {
        bit_witnesses.append(
            circuit.add_witness(FieldElement::zero())
        );
        i += 1;
    }
    
    // Add bit constraints
    i = 0;
    while i < bits {
        let bit = bit_witnesses[i];
        
        // Boolean constraint: b * (1 - b) = 0
        circuit.add_constraint(
            Constraint {
                left: WireTerm {
                    wires: array![(bit, FieldElement::one())],
                    constant: FieldElement::zero()
                },
                right: WireTerm {
                    wires: array![(bit, FieldElement::one())],
                    constant: FieldElement::one()
                },
                output: WireTerm {
                    wires: array![],
                    constant: FieldElement::zero()
                }
            }
        );
        
        i += 1;
    }
    
    // Add sum constraint
    let mut sum_term = WireTerm {
        wires: array![],
        constant: FieldElement::zero()
    };
    
    i = 0;
    while i < bits {
        sum_term.wires.append(
            (bit_witnesses[i], FieldElement::from(1 << i))
        );
        i += 1;
    }
    
    circuit.add_constraint(
        Constraint {
            left: sum_term,
            right: WireTerm {
                wires: array![],
                constant: FieldElement::one()
            },
            output: WireTerm {
                wires: array![(input, FieldElement::one())],
                constant: FieldElement::zero()
            }
        }
    );
    
    circuit
}

fn build_membership_circuit(
    set: Array<FieldElement>
) -> DisclosureCircuit {
    let mut circuit = DisclosureCircuitTrait::new();
    
    // Add input
    let input = circuit.add_input(FieldElement::one(), true);
    
    // Add selector witnesses
    let mut selector_witnesses = ArrayTrait::new();
    let mut i = 0;
    while i < set.len() {
        selector_witnesses.append(
            circuit.add_witness(FieldElement::zero())
        );
        i += 1;
    }
    
    // Add selector sum constraint
    let mut sum_term = WireTerm {
        wires: array![],
        constant: FieldElement::zero()
    };
    
    i = 0;
    while i < selector_witnesses.len() {
        sum_term.wires.append(
            (selector_witnesses[i], FieldElement::one())
        );
        i += 1;
    }
    
    circuit.add_constraint(
        Constraint {
            left: sum_term,
            right: WireTerm {
                wires: array![],
                constant: FieldElement::one()
            },
            output: WireTerm {
                wires: array![],
                constant: FieldElement::one()
            }
        }
    );
    
    // Add membership constraints
    let mut value_term = WireTerm {
        wires: array![],
        constant: FieldElement::zero()
    };
    
    i = 0;
    while i < set.len() {
        value_term.wires.append(
            (selector_witnesses[i], set[i])
        );
        i += 1;
    }
    
    circuit.add_constraint(
        Constraint {
            left: value_term,
            right: WireTerm {
                wires: array![],
                constant: FieldElement::one()
            },
            output: WireTerm {
                wires: array![(input, FieldElement::one())],
                constant: FieldElement::zero()
            }
        }
    );
    
    circuit
}
