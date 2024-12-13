use core::traits::Into;
use core::option::OptionTrait;
use core::array::ArrayTrait;
use super::constants::MERKLE_TREE_DEPTH;
use super::types::{Error, MerkleProof};
use super::crypto::utils::hash_u256;

#[derive(Drop, Serde)]
struct MerkleTree {
    leaves: Array<u256>,
    nodes: Array<Array<u256>>,
    current_size: u32
}

trait MerkleTreeTrait {
    fn new() -> MerkleTree;
    fn insert(ref self: MerkleTree, leaf: u256) -> Result<u32, Error>;
    fn get_proof(ref self: MerkleTree, index: u32) -> Result<MerkleProof, Error>;
    fn verify_proof(proof: MerkleProof) -> Result<bool, Error>;
    fn get_root(self: @MerkleTree) -> u256;
}

impl MerkleTreeImpl of MerkleTreeTrait {
    // Initialize a new Merkle tree
    fn new() -> MerkleTree {
        let mut nodes = ArrayTrait::new();
        let mut i = 0;
        
        while i <= MERKLE_TREE_DEPTH {
            let level = ArrayTrait::new();
            nodes.append(level);
            i += 1;
        }

        MerkleTree {
            leaves: ArrayTrait::new(),
            nodes,
            current_size: 0
        }
    }

    // Insert a new leaf into the tree
    fn insert(ref self: MerkleTree, leaf: u256) -> Result<u32, Error> {
        if self.current_size >= 2.pow(MERKLE_TREE_DEPTH) {
            return Result::Err(Error::SystemError);
        }

        // Add leaf to leaves array
        self.leaves.append(leaf);
        let index = self.current_size;

        // Update tree nodes
        let mut current_hash = leaf;
        let mut current_index = index;
        let mut level = 0;

        while level < MERKLE_TREE_DEPTH {
            let level_array = self.nodes[level];
            
            if current_index % 2 == 0 {
                // Left child, wait for right child
                level_array.append(current_hash);
                level += 1;
            } else {
                // Right child, compute parent
                let left_sibling = level_array[current_index - 1];
                current_hash = hash_u256(left_sibling, current_hash);
                level_array.append(current_hash);
                current_index /= 2;
                level += 1;
            }
        }

        self.current_size += 1;
        Result::Ok(index)
    }

    // Generate Merkle proof for a leaf
    fn get_proof(ref self: MerkleTree, index: u32) -> Result<MerkleProof, Error> {
        if index >= self.current_size {
            return Result::Err(Error::InvalidInput);
        }

        let mut proof_path = ArrayTrait::new();
        let mut current_index = index;
        let mut level = 0;

        while level < MERKLE_TREE_DEPTH {
            let level_array = self.nodes[level];
            let sibling_index = if current_index % 2 == 0 {
                current_index + 1
            } else {
                current_index - 1
            };

            if sibling_index < level_array.len() {
                proof_path.append((current_index % 2 == 1, level_array[sibling_index]));
            } else {
                // If sibling doesn't exist, use zero hash
                proof_path.append((current_index % 2 == 1, 0));
            }

            current_index /= 2;
            level += 1;
        }

        Result::Ok(MerkleProof {
            root: self.get_root(),
            leaf: self.leaves[index],
            path: proof_path
        })
    }

    // Verify a Merkle proof
    fn verify_proof(proof: MerkleProof) -> Result<bool, Error> {
        let mut current_hash = proof.leaf;
        let mut i = 0;

        while i < proof.path.len() {
            let (is_right, sibling) = proof.path[i];
            current_hash = if is_right {
                hash_u256(sibling, current_hash)
            } else {
                hash_u256(current_hash, sibling)
            };
            i += 1;
        }

        Result::Ok(current_hash == proof.root)
    }

    // Get the current root of the tree
    fn get_root(self: @MerkleTree) -> u256 {
        if self.current_size == 0 {
            return 0;
        }

        let top_level = self.nodes[MERKLE_TREE_DEPTH - 1];
        if top_level.len() > 0 {
            top_level[top_level.len() - 1]
        } else {
            0
        }
    }
}

// Helper functions for tree manipulation
impl MerkleTreeHelpers of MerkleTreeTrait {
    // Get the index of the parent node
    fn get_parent_index(index: u32) -> u32 {
        (index - 1) / 2
    }

    // Get the index of the left child
    fn get_left_child_index(index: u32) -> u32 {
        2 * index + 1
    }

    // Get the index of the right child
    fn get_right_child_index(index: u32) -> u32 {
        2 * index + 2
    }

    // Check if a node is a leaf
    fn is_leaf(self: @MerkleTree, index: u32) -> bool {
        index >= 2.pow(MERKLE_TREE_DEPTH - 1) - 1
    }

    // Get the level of a node
    fn get_level(index: u32) -> u32 {
        let mut i = index + 1;
        let mut level = 0;
        while i > 0 {
            i /= 2;
            level += 1;
        }
        level
    }
}
