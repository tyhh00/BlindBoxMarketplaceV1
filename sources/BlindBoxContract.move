module projectOwnerAdr::BlindBoxContract_Crystara_TestV4 {
    
    use std::signer;
    use std::vector;
    use std::string::{Self, String};
    use std::error;
    use std::table;
    ///use std::option::{Self, Option};
    use supra_framework::account::{Self, SignerCapability};
    use supra_framework::supra_account;
    use aptos_token::token;
    use supra_framework::coin::{Self, Coin};
    use supra_framework::event;
    use supra_framework::timestamp;
    use supra_framework::guid::GUID;

    /// Error Codes
    /// Action not authorized because the signer is not the admin of this module
    const ENOT_AUTHORIZED: u64 = 1;
    /// Collection already exists
    const ECOLLECTION_EXISTS: u64 = 2;
    const EINSUFFICIENT_BALANCE: u64 = 3;
    const ELOOTBOX_NOT_FOUND: u64 = 4;
    const ENOT_ENOUGH_STOCK: u64 = 5;
    const ELOOTBOX_EXISTS: u64 = 6;
    const EMAX_ROLLS_REACHED: u64 = 7;
    const ERESOURCE_FORFIXEDPRICE_EXISTS: u64 = 8;
    const EINVALID_INPUT_LENGTHS: u64 = 9;
    const ETOKEN_NAME_ALREADY_EXISTS: u64 = 11;

    // Market Settings
    //use projectOwnerAdr::BlindBoxAdminContract_Crystara_TestV1::get_resource_address as adminResourceAddressSettings;
    
    //Event Types
    #[event]
    struct CollectionCreatedEvent has copy, drop, store {
        creator: address,  // Address of the creator
        collection_name: vector<u8>,  // Name of the collection
        metadata_uri: vector<u8>,  // Metadata URI
        timestamp: u64,  // Block timestamp
    }

    #[event]
    struct LootboxCreatedEvent has copy, drop, store {
        creator: address,
        collection_name: vector<u8>,
        price: u64,
        price_coinType: String,
        timestamp: u64,
    }

    //Structs
    //#[resource_group_member(group = supra_framework::object::ObjectGroup)]
    struct Lootbox has store {
      creator: address,
      collectionName: String, // Used to access collection by Creator + CollName in aptos_token::token
      // ^ As good as storing the "Collection" Object because thats all we need to access it
      rarities: table::Table<String, u64>, // Map rarity name to weight
      rarities_showItemWhenRoll: table::Table<String, bool>,
      
      stock: u64, //Available stock
      maxRolls: u64, //Maximum Rolls ever
      rolled: u64, //Amount of this lootbox that has been rolled
      
      whitelistMode: bool,
      allow_mintList: table::Table<address, u64>,

      priceResourceAddress: address,
      
      //Probably Use a resource account, the Seed is the Addr+CollectionName
      //Store it there, the fixed price for this collection
      //Link up the resource adr here
      
      requiresKey: bool,
      keysCollectionName: String,
      
      tokensInLootbox: vector<String>, //Token Data IDs involved
    }

    /// Table to store all lootboxes by creator and collection name
    struct Lootboxes has key {
        lootbox_table: table::Table<String, Lootbox>, // Key: collection_name
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    struct FixedPriceListing<phantom CoinType> has key, store {
        /// The price to purchase the item up for listing.
        price: u64,
    }

    //Entry Functions
    
    // https://github.com/Entropy-Foundation/aptos-core/blob/dev/aptos-move/framework/aptos-token/sources/token.move#L1103
    public entry fun create_lootbox<CoinType>(
      source_account: &signer,
      collection_name: vector<u8>,
      description: vector<u8>,
      collection_uri: vector<u8>,
      maximum_supply: u64,
      initial_stock: u64,
      max_stock: u64,
      price: u64,

      requiresKey: bool,
      keys_collection_name: vector<u8>,
      keys_collection_description: vector<u8>,
      keys_collection_url: vector<u8>,
    ) acquires Lootboxes {
      let account_addr = signer::address_of(source_account);

      //Check if Underlying Collection Name was used before
      assert!(
        !token::check_collection_exists(account_addr, string::utf8(collection_name))
        , 
        error::not_found(ECOLLECTION_EXISTS)
      );

      //Check if Lootboxes Table Exists for Creator, If No, Init Table.
      if (!exists<Lootboxes>(account_addr)) {
        move_to(source_account, Lootboxes {
            lootbox_table: table::new<String, Lootbox>(),
        });
      };
      
      // Convert the vectors to strings
      let collection_name_str = string::utf8(collection_name);
      let description_str = string::utf8(description);
      let collection_uri_str = string::utf8(collection_uri);

      let lootboxes = borrow_global_mut<Lootboxes>(account_addr);
      assert!(
        !table::contains(&lootboxes.lootbox_table, collection_name_str),
        error::already_exists(ELOOTBOX_EXISTS)
      );


      let lootbox_resource_account_seed = vector::empty<u8>(); 
      vector::append(&mut lootbox_resource_account_seed, b"Lootbox");
      vector::append(&mut lootbox_resource_account_seed, collection_name);
      vector::append(&mut lootbox_resource_account_seed, b"BlindboxModule");

      // Check exist in global record. If it exist, it will throw an error.
      let resource_address = account::create_resource_address(&account_addr, lootbox_resource_account_seed);
      assert!(!account::exists_at(resource_address), error::already_exists(ERESOURCE_FORFIXEDPRICE_EXISTS));
      
      let (lootbox_resource_account_signer, lootbox_resource_account_signCapability) = account::create_resource_account(source_account, lootbox_resource_account_seed);
      let lootbox_resource_account_addr = signer::address_of(&lootbox_resource_account_signer);
      
      // Check exist in global record. If it exist, it will throw an error.
      assert!(!exists<FixedPriceListing<CoinType>>(lootbox_resource_account_addr), error::already_exists(ERESOURCE_FORFIXEDPRICE_EXISTS));
      
      let fixed_price_listing = FixedPriceListing<CoinType> {
            price,
        };

      move_to(&lootbox_resource_account_signer, fixed_price_listing);

      let new_lootbox = Lootbox {
        creator: account_addr,
        collectionName: collection_name_str,

        rarities: table::new<String, u64>(),
        rarities_showItemWhenRoll: table::new<String, bool>(),

        stock: initial_stock,
        maxRolls: max_stock,
        rolled: 0,

        whitelistMode: true,
        allow_mintList: table::new<address, u64>(),

        //price: fixed_price_listing,
        priceResourceAddress: lootbox_resource_account_addr,

        requiresKey: requiresKey,
        keysCollectionName: string::utf8(keys_collection_name),

        tokensInLootbox: vector::empty<String>(),
      };

      // Borrow a mutable reference to the `Lootboxes` resource
      let lootboxes = borrow_global_mut<Lootboxes>(account_addr);

      // Check if the lootbox already exists
      assert!(!table::contains(&lootboxes.lootbox_table, collection_name_str), error::already_exists(ELOOTBOX_EXISTS));
      // Insert the new lootbox into the `lootbox_table`
      table::add(&mut lootboxes.lootbox_table, collection_name_str, new_lootbox);

      // Create the collection with mutability settings
      let mutability_settings = vector::empty<bool>();
      vector::push_back(&mut mutability_settings , true); //Description
      vector::push_back(&mut mutability_settings , true); //URI
      vector::push_back(&mut mutability_settings , true); //Maximum
  
      // Create the collection using the new standard
      token::create_collection(
          source_account,
          collection_name_str,
          description_str,
          collection_uri_str,
          maximum_supply,
          mutability_settings
      );

      //TODO if need key, create key collection
      
      let lootbox_event = LootboxCreatedEvent {
        creator: account_addr,
        collection_name: collection_name,
        price: price,
        price_coinType: string::utf8(b"TODO: This is not done yet cuz chains dont store these info at runtime"),
        timestamp: timestamp::now_microseconds(), 
      };
      event::emit(lootbox_event);

      // Create the collection creation event
      let new_event = CollectionCreatedEvent {
            creator: account_addr,
            collection_name: collection_name,
            metadata_uri: collection_uri,
            timestamp: timestamp::now_microseconds(), 
        };
        // Emit the event
      event::emit(new_event);
    }




    public entry fun set_rarities(
      collection_owner: &signer,
      lootbox_name: vector<u8>,
      rarity_names: vector<vector<u8>>,
      rarity_weights: vector<u64>,
      show_items_on_roll: vector<bool>
    ) acquires Lootboxes {
        let owner_addr = signer::address_of(collection_owner);
        let lootbox_name_str = string::utf8(lootbox_name);

        // Get the lootbox
        let lootboxes = borrow_global_mut<Lootboxes>(owner_addr);
        let lootbox = table::borrow_mut(&mut lootboxes.lootbox_table, lootbox_name_str);
        
        // Verify the signer is the creator
        assert!(lootbox.creator == owner_addr, error::permission_denied(ENOT_AUTHORIZED));
        
        // Verify input vectors have same length
        let len = vector::length(&rarity_names);
        assert!(
            len == vector::length(&rarity_weights) && 
            len == vector::length(&show_items_on_roll),
            error::invalid_argument(EINVALID_INPUT_LENGTHS)
        );

        // Remove old entries by checking each new rarity name
        let i = 0;
        while (i < len) {
            let rarity_name = string::utf8(*vector::borrow(&rarity_names, i));
            if (table::contains(&lootbox.rarities, rarity_name)) {
                table::remove(&mut lootbox.rarities, rarity_name);
                table::remove(&mut lootbox.rarities_showItemWhenRoll, rarity_name);
            };
            i = i + 1;
        };

        // Add new entries
        let i = 0;
        while (i < len) {
            let rarity_name = string::utf8(*vector::borrow(&rarity_names, i));
            let weight = *vector::borrow(&rarity_weights, i);
            let show_item = *vector::borrow(&show_items_on_roll, i);

            table::add(&mut lootbox.rarities, rarity_name, weight);
            table::add(&mut lootbox.rarities_showItemWhenRoll, rarity_name, show_item);
            
            i = i + 1;
        };
    }

  //Add Token To Lootbox
    public entry fun add_token_to_lootbox(
      creator: &signer,
      collection_name: vector<u8>,
      token_name: vector<u8>,
      token_uri: vector<u8>,
      metadata_uri: vector<u8>,
      rarity: vector<u8>,
      max_supply: u64
    ) acquires Lootboxes {
        let creator_addr = signer::address_of(creator);
        let collection_name_str = string::utf8(collection_name);
        let token_name_str = string::utf8(token_name);

        // Check if token with this name already exists
        let token_data_id = token::create_token_data_id(
            creator_addr,
            collection_name_str,
            token_name_str
        );
        assert!(
            !token::check_tokendata_exists(creator_addr, collection_name_str, token_name_str),
            error::already_exists(ETOKEN_NAME_ALREADY_EXISTS)
        );
        
        // Get the lootbox
        let lootboxes = borrow_global_mut<Lootboxes>(creator_addr);
        let lootbox = table::borrow_mut(&mut lootboxes.lootbox_table, collection_name_str);
        
        // Verify the signer is the creator
        assert!(lootbox.creator == creator_addr, error::permission_denied(ENOT_AUTHORIZED));
        
        // Verify rarity exists in lootbox configuration
        let rarity_str = string::utf8(rarity);
        assert!(
            table::contains(&lootbox.rarities, rarity_str),
            error::invalid_argument(EINVALID_RARITY)
        );

        // Set up token properties including rarity
        let property_keys = vector[string::utf8(b"rarity")];
        let property_types = vector[string::utf8(b"String")];
        let property_values = vector[rarity];  // Store rarity as a property

        // Create token metadata in the collection
        let token_data_id = token::create_token_script(
            creator,
            collection_name_str,
            string::utf8(token_name),
            string::utf8(b""),
            max_supply,
            string::utf8(token_uri),
            creator_addr,
            100,
            5,
            vector[false, true, true, true, true],
            property_keys,
            property_types,
            property_values
        );

        // Store token data id only
        vector::push_back(&mut lootbox.tokensInLootbox, token_data_id);
    }

  // Helper function to get all tokens of a specific rarity
  fun get_tokens_by_rarity(
    lootbox: &Lootbox,
    rarity: String
    ): vector<String> {
        let tokens_of_rarity = vector::empty<String>();
        let i = 0;
        let len = vector::length(&lootbox.tokensInLootbox);
        
        while (i < len) {
            let token_id = *vector::borrow(&lootbox.tokensInLootbox, i);
            
            // Get the rarity property of the token
            let token_rarity = token::get_property_value(
                &token_id,
                &string::utf8(b"rarity")
            );
            
            // If token has matching rarity, add it to our result vector
            if (token_rarity == rarity) {
                vector::push_back(&mut tokens_of_rarity, token_id);
            };
            
            i = i + 1;
        };
        
        tokens_of_rarity
    }

    //TODO Modify Token Metadata by ID
public entry fun modify_token_metadata(
    creator: &signer,
    collection_name: vector<u8>,
    token_name: vector<u8>,
    new_uri: vector<u8>,
    new_description: vector<u8>,
    new_rarity: vector<u8>,
    // For other properties
    property_keys: vector<String>,
    property_types: vector<String>,
    property_values: vector<vector<u8>>
) acquires Lootboxes {
    let creator_addr = signer::address_of(creator);
    let collection_name_str = string::utf8(collection_name);
    let token_name_str = string::utf8(token_name);
    
    // Get the lootbox to verify ownership
    let lootboxes = borrow_global_mut<Lootboxes>(creator_addr);
    let lootbox = table::borrow_mut(&mut lootboxes.lootbox_table, collection_name_str);
    
    // Verify the signer is the creator
    assert!(lootbox.creator == creator_addr, error::permission_denied(ENOT_AUTHORIZED));

    // Get token data id
    let token_data_id = token::create_token_data_id(
        creator_addr,
        collection_name_str,
        token_name_str
    );

    // If changing rarity, verify the new rarity exists in lootbox configuration
    if (vector::length(&new_rarity) > 0) {
        let new_rarity_str = string::utf8(new_rarity);
        assert!(
            table::contains(&lootbox.rarities, new_rarity_str),
            error::invalid_argument(EINVALID_RARITY)
        );

        // Update rarity property
        token::mutate_tokendata_property(
            creator,
            token_data_id,
            string::utf8(b"rarity"),
            string::utf8(b"String"),
            new_rarity
        );
    };

    // Modify URI if provided
    if (vector::length(&new_uri) > 0) {
        token::mutate_tokendata_uri(
            creator,
            token_data_id,
            string::utf8(new_uri)
        );
    };

    // Modify description if provided
    if (vector::length(&new_description) > 0) {
        token::mutate_tokendata_description(
            creator,
            token_data_id,
            string::utf8(new_description)
        );
    };

    // Modify other properties if provided
    let property_len = vector::length(&property_keys);
    let i = 0;
    while (i < property_len) {
        let key = *vector::borrow(&property_keys, i);
        let type = *vector::borrow(&property_types, i);
        let value = *vector::borrow(&property_values, i);

        token::mutate_tokendata_property(
            creator,
            token_data_id,
            key,
            type,
            value
        );
        
        i = i + 1;
    };
}


    /// Purchase a lootbox
    public entry fun purchase_lootbox<CoinType>(
        buyer: &signer,
        creator_addr: address,
        collection_name: vector<u8>
      ) acquires FixedPriceListing, Lootboxes {
        let buyer_addr = signer::address_of(buyer);
        let collection_name_str = string::utf8(collection_name);

        // Fetch the lootbox
        let lootboxes = borrow_global_mut<Lootboxes>(creator_addr);
        let lootbox = table::borrow_mut(&mut lootboxes.lootbox_table, collection_name_str);
        assert!(lootbox.stock > 0, error::not_found(ENOT_ENOUGH_STOCK));
        assert!(lootbox.maxRolls < lootbox.rolled, error::not_found(EMAX_ROLLS_REACHED) );

        let FixedPriceListing {
            price,
        } = move_from<FixedPriceListing<CoinType>>(lootbox.priceResourceAddress);

        // Check buyer's balance
        let buyer_balance = coin::balance<CoinType>(buyer_addr);
        assert!(buyer_balance >= price, error::invalid_argument(EINSUFFICIENT_BALANCE));

        // Distribute payment
        let marketplace_cut = price / 10; // 10%
        let creator_cut = price - marketplace_cut; // 90%

        // Deduct payment from the buyer
        let marketplace_cut_coins = coin::withdraw<CoinType>(buyer, marketplace_cut);
        let creator_cut_coins = coin::withdraw<CoinType>(buyer, creator_cut);

        supra_account::deposit_coins(lootbox.creator, creator_cut_coins);
        supra_account::deposit_coins(@projectOwnerAdr, marketplace_cut_coins);

        // Update lootbox state
        lootbox.stock = lootbox.stock - 1;
        lootbox.rolled = lootbox.rolled + 1;

        // RNG logic placeholder
        // TODO: Implement random number generation and token assignment.
    }

  

    public fun append_to_vector(v: &mut vector<u8>, element: u8) {
        // Append the element to the vector
        vector::push_back(v, element);
    }


}