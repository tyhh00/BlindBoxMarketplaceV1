module projectOwnerAdr::BlindBoxContract_Crystara_TestV10 {
    
    /**
    *
    * Module Upgrade Notes:
    *
    * - Change the fun init_module resource seed to "LOOTBOX_RESOURCE_V(NEW VERSION)"
    * - Change the callback module name in purchase_lootbox to "BlindBoxContract_Crystara_TestV(NEW VERSION)"
    *
    *
    *
    *
    */

    use std::signer;
    use std::vector;
    use std::string::{Self, String};
    use std::error;
    use std::table;
    use std::type_info;
    use supra_framework::account::{Self, SignerCapability};
    use supra_framework::supra_account;
    use aptos_token::token::{Self, Collections};
    use aptos_token::property_map;
    use supra_framework::coin::{Self, Coin};
    use supra_framework::event;
    use supra_framework::timestamp;
    use supra_framework::guid::GUID;
    //DVRF
    use supra_addr::supra_vrf;

    // Constants
    const RESOURCE_ACCOUNT_SEED: vector<u8> = b"LOOTBOX_RESOURCE_V10";
    const USER_CLAIM_RESOURCE_SEED: vector<u8> = b"USER_CLAIM_RESOURCE_FIXED_v2";
    const CALLBACK_MODULE_NAME: vector<u8> = b"BlindBoxContract_Crystara_TestV10";

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
    const EINVALID_RARITY: u64 = 10;
    const ETOKEN_NAME_ALREADY_EXISTS: u64 = 11;
    const EALREADY_INITIALIZED: u64 = 12;
    const EYOU_ARE_NOT_PROJECT_OWNER: u64 = 13;
    const EINVALID_VECTOR_LENGTH: u64 = 14;  // Empty vectors or invalid lengths
    const EUNSAFE_NUMBER_CONVERSION: u64 = 15; // Overflow or unsafe conversion
    const ELOOTBOX_NOTEXISTS: u64 = 16;
    const EPRICE_NOT_SET_OR_INVALID_COIN_TYPE: u64 = 17;
    const EPENDING_REWARDS_NOT_INITIALIZED: u64 = 18;
    const EPENDING_REWARD_NOT_FOUND: u64 = 19;
    const EMETADATA_NOT_FOUND: u64 = 20;
    const ETOKEN_DATA_NOT_FOUND: u64 = 21;
    const ENO_TOKENS_TO_CLAIM: u64 = 22;
    const ENO_TOKENS_FOUND: u64 = 23;
    const ENO_TOKENS_CLAIMED: u64 = 24;
    const ENO_TOKENS_CLAIMED_SUCCESSFULLY: u64 = 25;
    const ENO_TOKENS_CLAIMED_FAILED: u64 = 26;
    const ERESOURCE_ACCOUNT_NOT_EXISTS: u64 = 27;
    const ENO_NONCE_NOT_FOUND: u64 = 28;
    const ERESOURCE_ESCROW_CLAIM_ACCOUNT_NOT_EXISTS: u64 = 29;

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

    #[event]
    struct LootboxPurchaseInitiatedEvent has drop, store {
        buyer: address,
        creator: address,
        collection_name: String,
        quantity: u64,
        nonce: u64,
        timestamp: u64
    }

    #[event]
    struct LootboxRewardDistributedEvent has drop, store {
        nonce: u64,
        buyer: address,
        creator: address,
        collection_name: String,
        selected_token: String,
        selected_rarity: String,
        random_number: u256,
        timestamp: u64
    }

    #[event]
    struct RaritiesSetEvent has drop, store {
      creator: address,
      collection_name: String,
      rarity_names: vector<String>,
      weights: vector<u64>,
      timestamp: u64
    }

    #[event]
    struct VRFCallbackReceivedEvent has drop, store {
        nonce: u64,
        caller_address: address,
        random_numbers: vector<u256>,
        timestamp: u64
    }

    #[event]
    struct TokenAddedEvent has drop, store {
        creator: address,
        collection_name: String,
        token_name: String,
        token_uri: String,
        rarity: String,
        max_supply: u64,
        timestamp: u64
    }

    // Add this event struct with your other events
    #[event]
    struct PriceUpdatedEvent has drop, store {
        creator: address,
        collection_name: String,
        price: u64,
        price_coinType: String,
        timestamp: u64
    }

    #[event]
    struct TokensClaimedEvent has drop, store {
        claimer: address,
        claim_resource_address: address,
        tokens_claimed: vector<TokenIdentifier>,
        total_tokens: u64,
        timestamp: u64
    }


    // Add event handle to PendingRewards struct
    struct PendingRewards has key {
        rewards: table::Table<u64, PendingReward>,
        next_nonce: u64,
    }

    //Structs
    //#[resource_group_member(group = supra_framework::object::ObjectGroup)]
    struct Lootbox has store {
      creator: address,
      collectionName: String, // Used to access collection by Creator + CollName in aptos_token::token

      collection_resource_address: address,
      collection_resource_signer_cap: account::SignerCapability,

      // ^ As good as storing the "Collection" Object because thats all we need to access it
      rarities: table::Table<String, u64>, // Map rarity name to weight
      rarities_showItemWhenRoll: table::Table<String, bool>,
      rarity_keys: vector<String>,         // Store rarity keys for iteration
      
      stock: u64, //Available stock
      maxRolls: u64, //Maximum Rolls ever
      rolled: u64, //Amount of this lootbox that has been rolled
      
      whitelistMode: bool,
      allow_mintList: table::Table<address, u64>,

      //FixedPriceListing with CoinType
      priceResourceAddress: address,
      
      tokensInLootbox: vector<String>, //Token names
      token_rarity_mapping: table::Table<String, String>, // Map token_name to rarity

      //Not Yet Implemented
      is_active: bool,
      mutable_if_active: bool, //If true, the lootbox can be modified while active

      requiresKey: bool, //Require Key to Roll and purchase lootbox
      keysCollectionName: String, //Collection Name of the keys by creator

      price_modifies_when_lack_of_certain_rarity: bool, //If true, the price will increase if the certain rarity is sold out
      rarities_price_modifier_if_sold_out: table::Table<String, u64>, //Map rarity to price modifier
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

    //DVRF SIgner Resource
    struct ResourceInfo has key {
      signer_cap: account::SignerCapability,
      signer_address: address
    }

    //Reward Structs
    struct PendingReward has store,drop {
      buyer: address,
      creator: address,
      collection_name: String,
      quantity: u64,
      nonce: u64,  // Link to the VRF request
    }

    // Escrow Resource for User Claim from Purchases
    struct UserClaimResourceInfo has key {
        resource_signer_cap: account::SignerCapability,
        resource_signer_address: address,
        claimable_tokens: vector<TokenIdentifier>
    }

    struct TokenIdentifier has store, drop {
        creator: address,
        collection: String,
        name: String
    }

    //Entry Functions
    // Initialize the pending rewards storage
    fun init_module(publisher: &signer) {
        assert!(signer::address_of(publisher) == @projectOwnerAdr, error::unauthenticated(EYOU_ARE_NOT_PROJECT_OWNER));
        let resource_account_seed = RESOURCE_ACCOUNT_SEED;

        let resource_address = account::create_resource_address(&signer::address_of(publisher), resource_account_seed);
        assert!(!account::exists_at(resource_address), error::already_exists(EALREADY_INITIALIZED));

        // Create resource account with a seed
        let (resource_signer, signer_cap) = account::create_resource_account(publisher, resource_account_seed);
        
        // Store signer capability
        move_to(publisher, ResourceInfo {
            signer_cap: signer_cap,
            signer_address: signer::address_of(&resource_signer)
        });
        
        //initialize pending rewards
        move_to(publisher, PendingRewards {
            rewards: table::new(),
            next_nonce: 0,
        });
    }
        
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
      let fresh_account = false;

      //Check if Lootboxes Table Exists for Creator, If No, Init Table.
      if (!exists<Lootboxes>(account_addr)) {
        move_to(source_account, Lootboxes {
            lootbox_table: table::new<String, Lootbox>(),
        });
        fresh_account = true;
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

      //Check if Underlying Collection Name was used before, also check if collections exists
      //Skip fresh accounts because they wouldnt have a collection yet under their resource account
      if(!fresh_account) {
        assert!(
            !token::check_collection_exists(lootbox_resource_account_addr, string::utf8(collection_name))
            , 
            error::not_found(ECOLLECTION_EXISTS)
        );
      };
      
      // Check exist in global record. If it exist, it will throw an error.
      assert!(!exists<FixedPriceListing<CoinType>>(lootbox_resource_account_addr), error::already_exists(ERESOURCE_FORFIXEDPRICE_EXISTS));
      
      let fixed_price_listing = FixedPriceListing<CoinType> {
            price,
        };

      move_to(&lootbox_resource_account_signer, fixed_price_listing);

      let new_lootbox = Lootbox {
        creator: account_addr,
        collectionName: collection_name_str,

        collection_resource_address: lootbox_resource_account_addr,
        collection_resource_signer_cap: lootbox_resource_account_signCapability,

        rarities: table::new<String, u64>(),
        rarities_showItemWhenRoll: table::new<String, bool>(),
        rarity_keys: vector::empty<String>(),

        stock: initial_stock,
        maxRolls: max_stock,
        rolled: 0,

        whitelistMode: true,
        allow_mintList: table::new<address, u64>(),

        //price: fixed_price_listing,
        priceResourceAddress: lootbox_resource_account_addr,

        tokensInLootbox: vector::empty<String>(),
        token_rarity_mapping: table::new<String, String>(),

        //Not Yet Implemented
        is_active: false,
        mutable_if_active: false,

        //Not Yet Implemented
        price_modifies_when_lack_of_certain_rarity: false,
        rarities_price_modifier_if_sold_out: table::new<String, u64>(),

        //Not Yet Implemented
        requiresKey: requiresKey,
        keysCollectionName: string::utf8(keys_collection_name),
        
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
          &lootbox_resource_account_signer,
          collection_name_str,
          description_str,
          collection_uri_str,
          maximum_supply,
          mutability_settings
      );

      //TODO if need key, create key collection

      // Get the type name of CoinType
      let coin_type_name = type_info::type_name<CoinType>();
      
      let lootbox_event = LootboxCreatedEvent {
        creator: account_addr,
        collection_name: collection_name,
        price: price,
        price_coinType: coin_type_name,
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

        // Clear existing rarities if any from rarity keys
        lootbox.rarity_keys = vector::empty<String>();

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
            vector::push_back(&mut lootbox.rarity_keys, rarity_name);
            
            i = i + 1;
        };

        // Emit event
        event::emit(
            RaritiesSetEvent {
                creator: owner_addr,
                collection_name: lootbox_name_str,
                rarity_names: lootbox.rarity_keys,
                weights: rarity_weights,
                timestamp: timestamp::now_microseconds()
            }
        );
    }

  //Add Token To Lootbox
    public entry fun add_token_to_lootbox(
      creator: &signer,
      collection_name: vector<u8>,
      token_uri: vector<u8>,
      rarity: vector<u8>,
      max_supply: u64
    ) acquires Lootboxes {
        let creator_addr = signer::address_of(creator);
        let collection_name_str = string::utf8(collection_name);

        // Get the lootbox
        let lootboxes = borrow_global_mut<Lootboxes>(creator_addr);
        let lootbox = table::borrow_mut(&mut lootboxes.lootbox_table, collection_name_str);
        // Verify the signer is the creator
        assert!(lootbox.creator == creator_addr, error::permission_denied(ENOT_AUTHORIZED));

        let collection_resource_address = lootbox.collection_resource_address;
        let collection_resource_signer = account::create_signer_with_capability(&lootbox.collection_resource_signer_cap);

        // Generate a new token name
        let token_count = vector::length(&lootbox.tokensInLootbox);
        let token_name_str = generate_token_name(token_count + 1);

        // Check if token with this name already exists
        let token_data_id = token::create_token_data_id(
            collection_resource_address,
            collection_name_str,
            token_name_str
        );
        assert!(
            !token::check_tokendata_exists(collection_resource_address, collection_name_str, token_name_str),
            error::already_exists(ETOKEN_NAME_ALREADY_EXISTS)
        );
        
        // Verify rarity exists in lootbox configuration
        let rarity_str = string::utf8(rarity);
        assert!(
            table::contains(&lootbox.rarities, rarity_str),
            error::invalid_argument(EINVALID_RARITY)
        );

        // Set up token properties including rarity
        let property_keys = vector[string::utf8(b"rarity")];
        let property_values = vector[rarity];
        let property_types = vector[string::utf8(b"String")];

        //Token Mutability Configuration
         //Max Supply, URI, Royalty, Description, Properties
        let mutability_settings = vector[false, true, true, true, true];
        let token_mutability_settings = token::create_token_mutability_config(&mutability_settings);

        // Create token metadata in the collection
        token::create_tokendata(
            &collection_resource_signer,
            collection_name_str,
            token_name_str,
            string::utf8(b""),
            max_supply,
            string::utf8(token_uri),
            creator_addr,
            100,
            5, //Royalty Percent
            token_mutability_settings,
            property_keys, 
            property_values,
            property_types,
        );

        // Store token data id only
        vector::push_back(&mut lootbox.tokensInLootbox, token_name_str);
        table::add(&mut lootbox.token_rarity_mapping, token_name_str, rarity_str);

        // Preparing Event Data
        let token_uri_str = string::utf8(token_uri);

        // Emit event
        event::emit(
            TokenAddedEvent {
                creator: creator_addr,
                collection_name: collection_name_str,
                token_name: token_name_str,
                token_uri: token_uri_str,
                rarity: rarity_str,
                max_supply,
                timestamp: timestamp::now_microseconds()
            }
        );
    }

  fun generate_token_name(id: u64): String {
      let prefix = b"TOKEN_";
      let name_bytes = vector::empty<u8>();
      vector::append(&mut name_bytes, prefix);
      
      // Convert id to string and append
      let id_str = number_to_string(id);  // You'll need to implement this
      vector::append(&mut name_bytes, *string::bytes(&id_str));
      
      string::utf8(name_bytes)
  }

  fun number_to_string(num: u64): String {
    if (num == 0) {
        return string::utf8(b"0")
    };
    
    let digits = vector::empty<u8>();
    let temp_num = num;
    
    while (temp_num > 0) {
        let digit = ((48 + (temp_num % 10)) as u8);  // Convert to ASCII
        vector::push_back(&mut digits, digit);
        temp_num = temp_num / 10;
    };
    
    // Reverse the digits since we added them in reverse order
    let len = vector::length(&digits);
    let i = 0;
    while (i < len / 2) {
        let j = len - i - 1;
        let temp = *vector::borrow(&digits, i);
        *vector::borrow_mut(&mut digits, i) = *vector::borrow(&digits, j);
        *vector::borrow_mut(&mut digits, j) = temp;
        i = i + 1;
    };
    
    string::utf8(digits)
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
          let token_name = *vector::borrow(&lootbox.tokensInLootbox, i);
          let token_rarity = *table::borrow(&lootbox.token_rarity_mapping, token_name);
          
          // If token has matching rarity, add its name to our result vector
          if (token_rarity == rarity) {
              vector::push_back(&mut tokens_of_rarity, token_name);
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

        let collection_resource_address = lootbox.collection_resource_address;
        let collection_resource_signer = account::create_signer_with_capability(&lootbox.collection_resource_signer_cap);

        // Get token data id
        let token_data_id = token::create_token_data_id(
            collection_resource_address,
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
            let rarity_keys = vector[string::utf8(b"rarity")];
            let rarity_values = vector[new_rarity];
            let rarity_types = vector[string::utf8(b"String")];

            token::mutate_tokendata_property(
                &collection_resource_signer,
                token_data_id,
                rarity_keys,
                rarity_values,
                rarity_types,
            );
        };

        // Modify URI if provided
        if (vector::length(&new_uri) > 0) {
            token::mutate_tokendata_uri(
                &collection_resource_signer,
                token_data_id,
                string::utf8(new_uri)
            );
        };

        // Modify description if provided
        if (vector::length(&new_description) > 0) {
            token::mutate_tokendata_description(
                &collection_resource_signer,
                token_data_id,
                string::utf8(new_description)
            );
        };

        // Modify other properties if provided
        if (vector::length(&property_keys) > 0) {
            token::mutate_tokendata_property(
                &collection_resource_signer,
                token_data_id,
                property_keys,
                property_values,
                property_types,
            );
        };
    }


    /// Purchase a lootbox
    public entry fun purchase_lootbox<CoinType>(
        buyer: &signer,
        creator_addr: address,
        collection_name: vector<u8>,
      ) acquires FixedPriceListing, Lootboxes, PendingRewards, ResourceInfo {
        let buyer_addr = signer::address_of(buyer);
        let collection_name_str = string::utf8(collection_name);

        // Check if user has initialized their claim escrow account
        let user_claim_seed = b"USER_CLAIM_RESOURCE_FIXED_v2";
        let user_claim_resource_address = account::create_resource_address(&buyer_addr, USER_CLAIM_RESOURCE_SEED);        
        if(!account::exists_at(user_claim_resource_address)){
            initialize_claim_account(buyer);
        };

        // Fetch the lootbox
        let lootboxes = borrow_global_mut<Lootboxes>(creator_addr);
        // Abort if the lootbox dosent exist
        assert!(table::contains(&lootboxes.lootbox_table, collection_name_str), error::not_found(ELOOTBOX_NOTEXISTS));
        // Fetch the lootbox
        let lootbox = table::borrow_mut(&mut lootboxes.lootbox_table, collection_name_str);
        // Check if there is stock and rolls are not maxed out
        assert!(lootbox.stock > 0, error::not_found(ENOT_ENOUGH_STOCK));
        assert!(lootbox.rolled < lootbox.maxRolls, error::not_found(EMAX_ROLLS_REACHED) );

        // Check if price is set
        assert!(exists<FixedPriceListing<CoinType>>(lootbox.priceResourceAddress), error::not_found(EPRICE_NOT_SET_OR_INVALID_COIN_TYPE));
        // Fetch the price
        let price = borrow_global<FixedPriceListing<CoinType>>(lootbox.priceResourceAddress).price;

        // Check buyer's balance
        let buyer_balance = coin::balance<CoinType>(buyer_addr);
        assert!(buyer_balance >= price, error::invalid_argument(EINSUFFICIENT_BALANCE));

        // Distribute payment
        let marketplace_cut = price / 10; // 10%
        let creator_cut = price - marketplace_cut; // 90%

        // Deduct payment from the buyer
        let marketplace_cut_coins = coin::withdraw<CoinType>(buyer, marketplace_cut);
        let creator_cut_coins = coin::withdraw<CoinType>(buyer, creator_cut);

        // Deposit the coins to the creator and marketplace
        supra_account::deposit_coins(lootbox.creator, creator_cut_coins);
        supra_account::deposit_coins(@projectOwnerAdr, marketplace_cut_coins);

        // Update lootbox state
        lootbox.stock = lootbox.stock - 1;
        lootbox.rolled = lootbox.rolled + 1;

        // Request VRF
        let callback_address = @projectOwnerAdr;
        let callback_module = string::utf8(CALLBACK_MODULE_NAME);
        let callback_function = string::utf8(b"receive_dvrf");

        // Get this module's own resource signer
        let module_resource_info = borrow_global<ResourceInfo>(@projectOwnerAdr);
        let module_resource_signer = account::create_signer_with_capability(&module_resource_info.signer_cap);
        
        let client_seed = timestamp::now_microseconds();  // Use timestamp as seed
        let nonce = supra_vrf::rng_request(
            buyer, //Only works with the blindbox account
            //&module_resource_signer, awaiting response from VRF team
            callback_address, 
            callback_module, 
            callback_function, 
            1,  // rng_count 
            client_seed,
            1   // num_confirmations
        );

        // Store pending reward
        let pending_rewards = borrow_global_mut<PendingRewards>(@projectOwnerAdr);
        let pending_reward = PendingReward {
            buyer: buyer_addr,
            creator: creator_addr,
            collection_name: collection_name_str,
            quantity: 1, //quantity
            nonce,
        };

        // Add to pending rewards
        table::add(&mut pending_rewards.rewards, nonce, pending_reward);

        // Emit purchase event
        event::emit(
            LootboxPurchaseInitiatedEvent {
                buyer: buyer_addr,
                creator: creator_addr,
                collection_name: collection_name_str,
                quantity:1,
                nonce: nonce,
                timestamp: timestamp::now_microseconds()
            }
        );
    }

    // Callback function for VRF
    public entry fun receive_dvrf(
      nonce: u64,
      message: vector<u8>,
      signature: vector<u8>,
      caller_address: address,
      rng_count: u8,
      client_seed: u64,
    ) acquires PendingRewards, Lootboxes {
        // Verify VRF result
        let random_numbers = supra_vrf::verify_callback(
            nonce, 
            message, 
            signature, 
            caller_address, 
            rng_count, 
            client_seed
        );

        // Verify we got at least one random number
        assert!(vector::length(&random_numbers) > 0, error::invalid_argument(EINVALID_VECTOR_LENGTH));

        // Emit VRF callback event
        event::emit(
            VRFCallbackReceivedEvent {
                nonce,
                caller_address,
                random_numbers: random_numbers,
                timestamp: timestamp::now_microseconds()
            }
        );

        // Use random number by DVRF CALLBACK
        let random_num = *vector::borrow(&random_numbers, 0);
        
        // Get pending reward
        let pending_rewards = borrow_global_mut<PendingRewards>(@projectOwnerAdr);
        assert!(table::contains(&pending_rewards.rewards, nonce), error::not_found(ENO_NONCE_NOT_FOUND));
        let pending_reward = table::remove(&mut pending_rewards.rewards, nonce);

        // Get lootbox
        let lootboxes = borrow_global_mut<Lootboxes>(pending_reward.creator);
        let lootbox = table::borrow_mut(&mut lootboxes.lootbox_table, pending_reward.collection_name);
        
        // Select rarity based on weights
        let selected_rarity = select_rarity(lootbox, random_num);
        
        // Get tokens of that rarity
        let tokens_of_rarity = get_tokens_by_rarity(lootbox, selected_rarity);
        
        // Select random token from that rarity
        let len = vector::length(&tokens_of_rarity);
    
        // Verify we have tokens to select from
        assert!(len > 0, error::invalid_state(EINVALID_VECTOR_LENGTH));
        
        // Safe conversion: len is guaranteed to fit in u256
        let len_u256 = (len as u256);
        
        // Calculate token index using full u256 randomness
        let token_index = random_num % len_u256;
        
        // Safe conversion back to u64: guaranteed to be less than len
        let token_index_u64 = (token_index as u64);
        assert!(token_index_u64 < len, error::invalid_state(EUNSAFE_NUMBER_CONVERSION));
        
        let selected_token = *vector::borrow(&tokens_of_rarity, token_index_u64);

        // Get collection signer
        let collection_signer = account::create_signer_with_capability(&lootbox.collection_resource_signer_cap);

        // Create token data id
        let token_data_id = token::create_token_data_id(
            lootbox.collection_resource_address,
            pending_reward.collection_name,
            selected_token
        );

        let user_claim_seed = USER_CLAIM_RESOURCE_SEED;
        let user_claim_resource_address = account::create_resource_address(&pending_reward.buyer, user_claim_seed);
        // If user claim resource account doesn't exist, create it
        assert!(account::exists_at(user_claim_resource_address), error::not_found(ERESOURCE_ESCROW_CLAIM_ACCOUNT_NOT_EXISTS)); 
        // Get the resource account signer using stored capability
        let claim_info = borrow_global_mut<UserClaimResourceInfo>(user_claim_resource_address);
        let user_claim_escrow_signer = account::create_signer_with_capability(&claim_info.resource_signer_cap);
        vector::push_back(&mut claim_info.claimable_tokens, TokenIdentifier {
            creator: lootbox.collection_resource_address,
            collection: pending_reward.collection_name,
            name: selected_token
        });

        // Mint token into collection owner resource account
        let token_minted_id = token::mint_token(
            &collection_signer,
            token_data_id,
            1  // amount
        );

        // Transfer token to buyer escrow resource account
        token::direct_transfer(
            &collection_signer,
            &user_claim_escrow_signer,
            token_minted_id,
            1 //amount
        );

        // Emit distribution event
        event::emit(
            LootboxRewardDistributedEvent {
                nonce,
                buyer: pending_reward.buyer,
                creator: pending_reward.creator,
                collection_name: pending_reward.collection_name,
                selected_token: selected_token,
                selected_rarity: selected_rarity,
                random_number: random_num,
                timestamp: timestamp::now_microseconds()
            }
        );

    }

    // Callback function for VRF
    public entry fun callback_test_manual_toremove(
      nonce: u64,
      caller_address: address,
      random_number: u256
    ) acquires PendingRewards, Lootboxes, UserClaimResourceInfo {

        // Emit VRF callback event
        event::emit(
            VRFCallbackReceivedEvent {
                nonce,
                caller_address,
                random_numbers: vector[random_number],
                timestamp: timestamp::now_microseconds()
            }
        );

        // Get pending reward
        let pending_rewards = borrow_global_mut<PendingRewards>(@projectOwnerAdr);
        assert!(table::contains(&pending_rewards.rewards, nonce), error::not_found(ENO_NONCE_NOT_FOUND));
        let pending_reward = table::remove(&mut pending_rewards.rewards, nonce);

        // Get lootbox
        let lootboxes = borrow_global_mut<Lootboxes>(pending_reward.creator);
        let lootbox = table::borrow_mut(&mut lootboxes.lootbox_table, pending_reward.collection_name);

        // Use random number to select rarity and token
        let random_num = random_number;
        
        // Select rarity based on weights
        let selected_rarity = select_rarity(lootbox, random_num);
        
        // Get tokens of that rarity
        let tokens_of_rarity = get_tokens_by_rarity(lootbox, selected_rarity);
        
        // Select random token from that rarity
        let len = vector::length(&tokens_of_rarity);
    
        // Verify we have tokens to select from
        assert!(len > 0, error::invalid_state(EINVALID_VECTOR_LENGTH));
        
        // Safe conversion: len is guaranteed to fit in u256
        let len_u256 = (len as u256);
        
        // Calculate token index using full u256 randomness
        let token_index = random_num % len_u256;
        
        // Safe conversion back to u64: guaranteed to be less than len
        let token_index_u64 = (token_index as u64);
        assert!(token_index_u64 < len, error::invalid_state(EUNSAFE_NUMBER_CONVERSION));
        
        let selected_token = *vector::borrow(&tokens_of_rarity, token_index_u64);

        // Get collection signer
        let collection_signer = account::create_signer_with_capability(&lootbox.collection_resource_signer_cap);

        // Create token data id
        let token_data_id = token::create_token_data_id(
            lootbox.collection_resource_address,
            pending_reward.collection_name,
            selected_token
        );

        let user_claim_seed = USER_CLAIM_RESOURCE_SEED;
        let user_claim_resource_address = account::create_resource_address(&pending_reward.buyer, user_claim_seed);
        // If user claim resource account doesn't exist, create it
        assert!(account::exists_at(user_claim_resource_address), error::not_found(ERESOURCE_ESCROW_CLAIM_ACCOUNT_NOT_EXISTS)); 
        // Get the resource account signer using stored capability
        let claim_info = borrow_global_mut<UserClaimResourceInfo>(user_claim_resource_address);
        let user_claim_escrow_signer = account::create_signer_with_capability(&claim_info.resource_signer_cap);
        vector::push_back(&mut claim_info.claimable_tokens, TokenIdentifier {
            creator: lootbox.collection_resource_address,
            collection: pending_reward.collection_name,
            name: selected_token
        });

        // Mint token into collection owner resource account
        let token_minted_id = token::mint_token(
            &collection_signer,
            token_data_id,
            1  // amount
        );

        // Transfer token to buyer escrow resource account
        token::direct_transfer(
            &collection_signer,
            &user_claim_escrow_signer,
            token_minted_id,
            1 //amount
        );

        // Emit distribution event
        event::emit(
            LootboxRewardDistributedEvent {
                nonce,
                buyer: pending_reward.buyer,
                creator: pending_reward.creator,
                collection_name: pending_reward.collection_name,
                selected_token: selected_token,
                selected_rarity: selected_rarity,
                random_number: random_number,
                timestamp: timestamp::now_microseconds()
            }
        );

    }

    // Helper function to select rarity based on weights
    fun select_rarity(lootbox: &Lootbox, random_num: u256): String {
        let total_weight = (0 as u256);
        let rarities = &lootbox.rarities;
        
        let len = vector::length(&lootbox.rarity_keys);
        assert!(len > 0, error::invalid_state(EINVALID_VECTOR_LENGTH));
        
        // Calculate total weight
        let i = 0;
        while (i < len) {
            let rarity = vector::borrow(&lootbox.rarity_keys, i);
            let weight = *table::borrow(rarities, *rarity);
            total_weight = total_weight + (weight as u256);
            i = i + 1;
        };
        
        // Use random number to select rarity
        let roll = random_num % total_weight;
        let current_weight = (0 as u256);
        
        i = 0;
        while (i < len) {
            let rarity = vector::borrow(&lootbox.rarity_keys, i);
            let weight = *table::borrow(rarities, *rarity);
            current_weight = current_weight + (weight as u256);
            
            if (roll < current_weight) {
                return *rarity
            };
            i = i + 1;
        };

        // Fallback to last rarity
        *vector::borrow(&lootbox.rarity_keys, len - 1)
    }

    public entry fun set_lootbox_price<CoinType>(
        creator: &signer,
        collection_name: vector<u8>,
        new_price: u64
    ) acquires Lootboxes, FixedPriceListing {
        let creator_addr = signer::address_of(creator);
        let collection_name_str = string::utf8(collection_name);

        // Get the lootbox
        let lootboxes = borrow_global_mut<Lootboxes>(creator_addr);
        assert!(
            table::contains(&lootboxes.lootbox_table, collection_name_str),
            error::not_found(ELOOTBOX_NOTEXISTS)
        );
        let lootbox = table::borrow_mut(&mut lootboxes.lootbox_table, collection_name_str);
        
        // Verify the signer is the creator
        assert!(lootbox.creator == creator_addr, error::permission_denied(ENOT_AUTHORIZED));

        // Get resource signer
        let resource_signer = account::create_signer_with_capability(&lootbox.collection_resource_signer_cap);

        // If price listing exists, update it, otherwise create new
        if (exists<FixedPriceListing<CoinType>>(lootbox.priceResourceAddress)) {
            let price_listing = borrow_global_mut<FixedPriceListing<CoinType>>(lootbox.priceResourceAddress);
            price_listing.price = new_price;
        } else {
            move_to(&resource_signer, FixedPriceListing<CoinType> {
                price: new_price,
            });
        };

        // Optionally emit an event
        // Add this event struct at the top with other events if you want to use it
        event::emit(
            PriceUpdatedEvent {
                creator: creator_addr,
                collection_name: collection_name_str,
                price: new_price,
                price_coinType: type_info::type_name<CoinType>(),
                timestamp: timestamp::now_microseconds()
            }
        );
    }

    // Initialize claim account function
    public entry fun initialize_claim_account(
        user: &signer
    ) {
        let user_addr = signer::address_of(user);
        let user_claim_seed = USER_CLAIM_RESOURCE_SEED;
        let user_claim_resource_address = account::create_resource_address(&user_addr, user_claim_seed);
        
        // Only create if it doesn't exist
        if (!account::exists_at(user_claim_resource_address)) {
            let (resource_account, resource_signer_cap) = account::create_resource_account(
                user,  // Using user's own signer
                user_claim_seed
            );
            
            move_to(&resource_account, UserClaimResourceInfo {
                resource_signer_cap: resource_signer_cap,
                resource_signer_address: signer::address_of(&resource_account),
                claimable_tokens: vector::empty<TokenIdentifier>()
            });
        };
    }

    // Claim all tokens function

    public entry fun claim_all_from_escrow(
        claimer: &signer
    ) acquires UserClaimResourceInfo {
        let claimer_addr = signer::address_of(claimer);
        let user_claim_seed = b"USER_CLAIM_RESOURCE_FIXED_v2";
        let user_claim_resource_address = account::create_resource_address(&claimer_addr, user_claim_seed);
        
        // Check if resource account exists
        assert!(
            account::exists_at(user_claim_resource_address),
            error::not_found(ERESOURCE_ACCOUNT_NOT_EXISTS)
        );

        // Check if UserClaimResourceInfo exists
        assert!(
            exists<UserClaimResourceInfo>(user_claim_resource_address),
            error::not_found(ERESOURCE_ACCOUNT_NOT_EXISTS)
        );
        
        // Get claim info and check if there are tokens to claim
        let claim_info = borrow_global_mut<UserClaimResourceInfo>(user_claim_resource_address);
        assert!(
            !vector::is_empty(&claim_info.claimable_tokens),
            error::invalid_state(ENO_TOKENS_TO_CLAIM)
        );

        let resource_signer = account::create_signer_with_capability(&claim_info.resource_signer_cap);
        let claimed_tokens = vector::empty<TokenIdentifier>();
        let total_claimed = 0;

        // Transfer all tokens
        while (!vector::is_empty(&claim_info.claimable_tokens)) {
            let token = vector::pop_back(&mut claim_info.claimable_tokens);
            
            // Create token data id first
            let token_data_id = token::create_token_data_id(
                token.creator,
                token.collection,
                token.name
            );

            // Create token id with property version 0
            let token_id = token::create_token_id(token_data_id, 0);
            
            // Get balance and transfer if available
            let balance = token::balance_of(claim_info.resource_signer_address, token_id);
            if (balance > 0) {
                token::direct_transfer(
                    &resource_signer,
                    claimer,
                    token_id,
                    balance
                );
                vector::push_back(&mut claimed_tokens, token);
                total_claimed = total_claimed + 1;
            };
        };

        // Emit detailed claim event
        event::emit(
            TokensClaimedEvent {
                claimer: claimer_addr,
                claim_resource_address: user_claim_resource_address,
                tokens_claimed: claimed_tokens,
                total_tokens: total_claimed,
                timestamp: timestamp::now_microseconds()
            }
        );
    }


}