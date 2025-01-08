module projectOwnerAdr::BlindBoxContract {
    use std::signer;
    use std::vector;
    use std::string;
    use std::error;
    use std::option::{Self, Option};
    use supra_framework::account::{Self, SignerCapability};
    use supra_framework::supra_account;

    //use supra_addr::supra_vrf; //Not whitelisted yet
    use projectOwnerAdr::BlindBoxAdminContract::get_resource_address as adminResourceAddressSettings;

     // This struct stores an NFT collection's relevant information
    struct ModuleData has key {
        token_data_id: TokenDataId,
    }

    /// Action not authorized because the signer is not the admin of this module
    const ENOT_AUTHORIZED: u64 = 1;

    /// `init_module` is automatically called when publishing the module.
    /// In this function, we create an example NFT collection and an example token.
    public entry fun create_collection(
        source_account: &signer,
        collection_name: vector<u8>,
        description: vector<u8>,
        collection_uri: vector<u8>,
        token_name: vector<u8>,
        maximum_supply: u64,
        token_uri: vector<u8>
    ) {
        //Maximum Supply of 0 means infinite, amount means it is fixed.

        // This variable sets if we want to allow mutation for collection description, uri, and maximum.
        // Here, we are setting all of them to false, which means that we don't allow mutations to any CollectionData fields.
        let mutate_setting = vector<bool>[true, true, false];

        // Create the NFT collection using the parameters passed into the function.
        token::create_collection(
            source_account,
            string::utf8(&collection_name),
            string::utf8(&description),
            string::utf8(&collection_uri),
            maximum_supply,
            mutate_setting
        );

        // Example of multiple properties Creating the "metadata" on chain for the nft, that is
        // then move_to the signer address when move to is called, it means it mints at the signer's address. 
        // move to is helpful, we can store all the created tokens' metadata somewhere, then only when the user lands
        // on that item, we mint it. Also check how many has been minted before, if its maxed out, remove from the pool of
        // "active rolls" items and their chances, then the "Hisotrical rolls" pool will show the items that ran out already
        // indicating that they wont be dropped in this collection anymore.
        let token_data_id = token::create_tokendata(
            source_account,
            string::utf8(&collection_name),
            string::utf8(&token_name),
            string::utf8(b"Token description"),   // Token description
            0,
            string::utf8(&token_uri),
            signer::address_of(source_account),
            1,                                   // Royalty percentage
            0,                                   // Maximum supply
            token::create_token_mutability_config(
                &vector<bool>[false, false, false, false, true]
            ),
            // Property keys (e.g., traits, metadata, etc.)
            vector<String>[
                string::utf8(b"given_to"),      // Property 1: Key
                string::utf8(b"rarity"),        // Property 2: Key
                string::utf8(b"origin")         // Property 3: Key
            ],
            // Property values (must match the order of keys)
            vector<vector<u8>>[
                b"",                            // Property 1: Value (e.g., "given_to" not set yet)
                b"Legendary",                   // Property 2: Value (e.g., rarity level "Legendary")
                b"Japan"                        // Property 3: Value (e.g., origin country "Japan")
            ],
            // Property types (indicating the data type of the values)
            vector<String>[
                string::utf8(b"address"),       // Property 1: Type (e.g., "address" for given_to)
                string::utf8(b"string"),        // Property 2: Type (e.g., "string" for rarity)
                string::utf8(b"string")         // Property 3: Type (e.g., "string" for origin)
            ]
        );


        // Store the token data id within the module, so we can refer to it later
        // when we're minting the NFT and updating its property version.
        move_to(source_account, ModuleData {
            token_data_id,
        });
    }




}

