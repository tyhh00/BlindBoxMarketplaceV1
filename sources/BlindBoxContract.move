module projectOwnerAdr::BlindBoxContract_Crystara_TestV9 {
    
    use std::signer;
    use std::vector;
    use std::string::{Self, String};
    use std::error;
    use std::table;
    use std::type_info;
    use supra_framework::account::{Self, SignerCapability};
    use supra_framework::supra_account;
    use aptos_token::token;
    use aptos_token::property_map;
    use supra_framework::coin::{Self, Coin};
    use supra_framework::event;
    use supra_framework::timestamp;
    use supra_framework::guid::GUID;
    //DVRF
    use supra_addr::supra_vrf;

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
      signer_cap: account::SignerCapability
    }

    //Reward Structs
    struct PendingReward has store,drop {
      buyer: address,
      creator: address,
      collection_name: String,
      quantity: u64,
      nonce: u64,  // Link to the VRF request
    }

    //Entry Functions
    // Initialize the pending rewards storage
    fun init_module(publisher: &signer) {
        assert!(signer::address_of(publisher) == @projectOwnerAdr, error::unauthenticated(EYOU_ARE_NOT_PROJECT_OWNER));
        assert!(!exists<PendingRewards>(signer::address_of(publisher)), error::already_exists(EALREADY_INITIALIZED));

        // Create resource account with a seed
        let (resource_signer, signer_cap) = account::create_resource_account(publisher, b"LOOTBOX_RESOURCE_V9");
        
        // Store signer capability
        move_to(publisher, ResourceInfo {
            signer_cap: signer_cap
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
      ) acquires FixedPriceListing, Lootboxes, PendingRewards {
        let buyer_addr = signer::address_of(buyer);
        let collection_name_str = string::utf8(collection_name);

        // Fetch the lootbox
        let lootboxes = borrow_global_mut<Lootboxes>(creator_addr);
        let lootbox = table::borrow_mut(&mut lootboxes.lootbox_table, collection_name_str);
        assert!(lootbox.stock > 0, error::not_found(ENOT_ENOUGH_STOCK));
        assert!(lootbox.rolled < lootbox.maxRolls, error::not_found(EMAX_ROLLS_REACHED) );

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

        let buyer_addr = signer::address_of(buyer);
        let collection_name_str = string::utf8(collection_name);

        // Request VRF
        let callback_address = @projectOwnerAdr;
        let callback_module = string::utf8(b"BlindBoxContract_Crystara_TestV5");
        let callback_function = string::utf8(b"receive_dvrf");
        
        let client_seed = timestamp::now_microseconds();  // Use timestamp as seed
        let nonce = supra_vrf::rng_request(
            buyer, 
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

        // Get pending reward
        let pending_rewards = borrow_global_mut<PendingRewards>(@projectOwnerAdr);
        let pending_reward = table::remove(&mut pending_rewards.rewards, nonce);

        // Get lootbox
        let lootboxes = borrow_global_mut<Lootboxes>(pending_reward.creator);
        let lootbox = table::borrow_mut(&mut lootboxes.lootbox_table, pending_reward.collection_name);

        // Use random number to select rarity and token
        let random_num = *vector::borrow(&random_numbers, 0);
        
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
            pending_reward.creator,
            pending_reward.collection_name,
            selected_token
        );

        // Mint token into resource account
        let token_minted_id = token::mint_token(
            &collection_signer,
            token_data_id,
            1  // amount
        );

        // Transfer token to buyer
        token::transfer(
            &collection_signer,
            token_minted_id,
            pending_reward.buyer,
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
                random_number: *vector::borrow(&random_numbers, 0),
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

}