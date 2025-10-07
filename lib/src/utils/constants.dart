// lib/src/utils/constants.dart
import 'package:arcane/src/models/game_models.dart'; // For PlayerStat, MainTaskTemplate

// Initial Main Task Templates (Moved from game_models.dart)
List<MainTaskTemplate> initialMainTaskTemplates = [
  MainTaskTemplate(
      id: "build_routine",
      name: "Routine & Reflection",
      description: "Establish routines, track progress, reflect.",
      theme: "order",
      colorHex: "FF4CAF50") // Green
];

Map<String, PlayerStat> basePlayerGameStats = {
  'strength': PlayerStat(
      name: 'STRENGTH',
      value: 10,
      base: 10,
      description: 'Increases physical damage dealt.',
      icon: 'mdi-sword'), // MDI Icon
  'runic': PlayerStat(
      name: 'RUNIC',
      value: 5,
      base: 5,
      description: 'Increases elemental and special attack damage.',
      icon: 'mdi-fire'), // MDI Icon
  'defense': PlayerStat(
      name: 'DEFENSE',
      value: 5,
      base: 5,
      description: 'Reduces all damage taken.',
      icon: 'mdi-shield'), // MDI Icon
  'vitality': PlayerStat(
      name: 'VITALITY',
      value: 100,
      base: 100,
      description: 'Increases maximum Health.',
      icon: 'mdi-heart'), // MDI Icon
  'luck': PlayerStat(
      name: 'LUCK',
      value: 1,
      base: 1,
      description: 'Increases Perk activation, XP, and Coin gains.',
      icon: 'mdi-clover'), // MDI Icon
  'cooldown': PlayerStat(
      name: 'COOLDOWN',
      value: 0,
      base: 0,
      description: 'Reduces recharge time of special abilities.',
      icon: 'mdi-clock-fast'), // MDI Icon
  // bonusXPMod is handled dynamically in GameProvider, not a base displayed stat.
};

// Game constants
// ignore_for_file: constant_identifier_names
const double xpPerLevelBase = 150; // Increased base XP
const double xpLevelMultiplier = 1.22; // Increased multiplier
const double baseMaxPlayerEnergy = 100;
const double playerEnergyPerLevelVitality = 5;
const double energyPerAttack = 10;
const double energyRegenPerMinuteTasked = 2;

const double subtaskCompletionXpBase = 5;
const double subtaskCompletionCoinBase = 2;

const double xpPerMinuteSubtask = 0.2;
const double coinsPerMinuteSubtask = 0.05;
const double xpPerCountUnitSubtask = 0.5;
const double coinsPerCountUnitSubtask = 0.1;

const double subSubtaskCompletionXpBase = 1;
const double subSubtaskCompletionCoinBase = 0.5;

const double xpPerCountUnitSubSubtask = 0.1;
const double coinsPerCountUnitSubSubtask = 0.02;

const double blacksmithUpgradeCostMultiplier = 1.5;
const int dailyTaskGoalMinutes = 15;
const double streakBonusCoins = 10;
const double streakBonusXp = 20;
const double artifactSellPercentage = 0.3;

// Initial Game Locations (Moved from game_models.dart and made part of constants for pre-build)
// AI can add to this list via GameProvider.
List<GameLocation> initialGameLocations = [
  GameLocation(
      id: "loc_dark_forest",
      name: "Dark Forest",
      description: "A menacing forest teeming with shadowy beasts.",
      minPlayerLevelToUnlock: 1,
      iconEmoji: "🌲",
      associatedTheme: "nature",
      bossEnemyIdToUnlockNextLocation: "enemy_forest_guardian"),
  GameLocation(
      id: "loc_ruined_temple",
      name: "Ruined Temple",
      description: "Ancient ruins guarded by forgotten constructs.",
      minPlayerLevelToUnlock: 3,
      iconEmoji: "🏛️",
      associatedTheme: "ancient",
      bossEnemyIdToUnlockNextLocation: "enemy_temple_golem"),
  // AI can generate more, or they can be added here.
];

// Initial Enemy Templates
List<EnemyTemplate> initialEnemyTemplates = [
  EnemyTemplate(
      id: "enemy_goblin_scout",
      name: "Goblin Scout",
      theme: "nature",
      locationKey: "loc_dark_forest",
      minPlayerLevel: 1,
      health: 40,
      attack: 6,
      defense: 2,
      coinReward: 10,
      xpReward: 15,
      description: "A nimble but weak forest scout."),
  EnemyTemplate(
      id: "enemy_forest_spider",
      name: "Giant Forest Spider",
      theme: "nature",
      locationKey: "loc_dark_forest",
      minPlayerLevel: 1,
      health: 60,
      attack: 8,
      defense: 3,
      coinReward: 15,
      xpReward: 25,
      description: "A large, venomous arachnid."),
  EnemyTemplate(
      id: "enemy_forest_guardian",
      name: "Forest Guardian (Boss)",
      theme: "nature",
      locationKey: "loc_dark_forest",
      minPlayerLevel: 2,
      health: 150,
      attack: 12,
      defense: 5,
      coinReward: 50,
      xpReward: 70,
      description: "An ancient protector of the woods."),
  EnemyTemplate(
      id: "enemy_stone_servant",
      name: "Stone Servant",
      theme: "ancient",
      locationKey: "loc_ruined_temple",
      minPlayerLevel: 3,
      health: 80,
      attack: 10,
      defense: 8,
      coinReward: 25,
      xpReward: 40,
      description: "A magically animated stone guard."),
  EnemyTemplate(
      id: "enemy_temple_golem",
      name: "Temple Golem (Boss)",
      theme: "ancient",
      locationKey: "loc_ruined_temple",
      minPlayerLevel: 4,
      health: 200,
      attack: 15,
      defense: 10,
      coinReward: 80,
      xpReward: 100,
      description: "The formidable guardian of the temple's heart."),
];

// Initial Artifact Templates
List<ArtifactTemplate> initialArtifactTemplates = [
  // Weapons
  ArtifactTemplate(
      id: "art_rusty_sword",
      name: "Rusty Sword",
      type: "weapon",
      theme: null,
      description: "A basic, somewhat worn sword.",
      cost: 20,
      icon: "mdi-sword", // Keep as MDI for now
      baseAtt: 2,
      maxLevel: 3,
      upgradeBonus: {"att": 1}),
  ArtifactTemplate(
      id: "art_hunter_bow",
      name: "Hunter's Bow",
      type: "weapon",
      theme: "nature",
      description: "A simple bow, good for hunting.",
      cost: 50,
      icon: "🏹", // Emoji for this one
      baseAtt: 3,
      baseLuck: 1,
      maxLevel: 5,
      upgradeBonus: {"att": 1, "luck": 1}),
  // Armor
  ArtifactTemplate(
      id: "art_leather_jerkin",
      name: "Leather Jerkin",
      type: "armor",
      theme: null,
      description: "Basic leather protection.",
      cost: 30,
      icon: "🛡️", // Emoji
      baseDef: 1,
      baseHealth: 5,
      maxLevel: 3,
      upgradeBonus: {"def": 1, "health": 5}),
  ArtifactTemplate(
      id: "art_iron_greaves",
      name: "Iron Greaves",
      type: "armor",
      theme: "tech",
      description: "Sturdy leg protection.",
      cost: 60,
      icon: "mdi-shoe-sneaker", // MDI
      baseDef: 2,
      baseHealth: 10,
      maxLevel: 5,
      upgradeBonus: {
        "def": 1,
        "health": 8
      }), 
  // Talismans
  ArtifactTemplate(
      id: "art_lucky_clover",
      name: "Lucky Clover",
      type: "talisman",
      theme: "nature",
      description: "Might bring good fortune.",
      cost: 40,
      icon: "🍀", // Emoji
      baseLuck: 2,
      bonusXPMod: 0.02,
      maxLevel: 3,
      upgradeBonus: {"luck": 1, "bonusXPMod": 0}),
  // Powerups
  ArtifactTemplate(
      id: "art_healing_draught",
      name: "Healing Draught",
      type: "powerup",
      theme: null,
      description: "Restores a small amount of health.",
      cost: 25,
      icon: "🧪", // Emoji
      effectType: "heal_player",
      effectValue: 30,
      uses: 1),
];

// Park Management Constants
const double baseMaxParkEnergy = 100; // Player energy also used for park initially
const double parkEnergyRegenPerMinute = 5; // Player energy regen can be used for park tasks
const double fossilExcavationEnergyCost = 10; // Player Energy cost
const double incubationEnergyCost = 25; // Player Energy cost
const double feedDinoEnergyCost = 5; // Player Energy cost
const int enclosureBaseFoodCapacity = 100; // Food units an enclosure's feeder can hold
const int baseIncubationDuration = 5; // Age units for incubation
const int MAX_PARK_RATING_FOR_STARS = 1000; // Max rating for 5-star display
const int SKIP_MINUTE_ENERGY_COST = 10;
const int SKIP_MINUTE_PARK_DOLLAR_BONUS = 50; // Optional: Bonus dollars for skipping


// Initial Dinosaur Species
List<DinosaurSpecies> initialDinosaurSpecies = [
  DinosaurSpecies(
    id: "dino_triceratops",
    name: "Triceratops",
    description: "A large, herbivorous dinosaur known for its three prominent horns and large frill.",
    diet: "herbivore",
    incubationCostDollars: 15000,
    fossilExcavationEnergyCost: 50,
    baseRating: 200,
    comfortThreshold: 0.60, // 60%
    socialNeedsMin: 2,
    socialNeedsMax: 5,
    enclosureSizeNeeds: 10,
    icon: "🦕",
    minPlayerLevelToUnlock: 1,
  ),
  DinosaurSpecies(
    id: "dino_velociraptor",
    name: "Velociraptor",
    description: "A small, agile carnivore known for its intelligence and sickle-shaped claws.",
    diet: "carnivore",
    incubationCostDollars: 25000,
    fossilExcavationEnergyCost: 75,
    baseRating: 350,
    comfortThreshold: 0.50, // 50%
    socialNeedsMin: 3,
    socialNeedsMax: 6,
    enclosureSizeNeeds: 8,
    icon: "🦖",
    minPlayerLevelToUnlock: 3,
  ),
  DinosaurSpecies(
    id: "dino_tyrannosaurus_rex",
    name: "Tyrannosaurus Rex",
    description: "The tyrant lizard king, an apex predator with a fearsome reputation and powerful bite.",
    diet: "carnivore",
    incubationCostDollars: 100000,
    fossilExcavationEnergyCost: 150,
    baseRating: 950,
    comfortThreshold: 0.40, 
    socialNeedsMin: 1,
    socialNeedsMax: 2,
    enclosureSizeNeeds: 25,
    icon: "🦖",
    minPlayerLevelToUnlock: 15,
  ),
  DinosaurSpecies(
    id: "dino_brachiosaurus",
    name: "Brachiosaurus",
    description: "A colossal long-necked herbivore, one of the tallest dinosaurs to have ever lived.",
    diet: "herbivore",
    incubationCostDollars: 75000,
    fossilExcavationEnergyCost: 120,
    baseRating: 700,
    comfortThreshold: 0.65,
    socialNeedsMin: 1,
    socialNeedsMax: 3,
    enclosureSizeNeeds: 30, 
    icon: "🦕",
    minPlayerLevelToUnlock: 12,
  ),
  DinosaurSpecies(
    id: "dino_parasaurolophus",
    name: "Parasaurolophus",
    description: "A hadrosaur known for the distinctive cranial crest, likely used for display and communication.",
    diet: "herbivore",
    incubationCostDollars: 12000,
    fossilExcavationEnergyCost: 45,
    baseRating: 180,
    comfortThreshold: 0.70,
    socialNeedsMin: 3,
    socialNeedsMax: 10,
    enclosureSizeNeeds: 12,
    icon: "🦕",
    minPlayerLevelToUnlock: 5,
  ),
  DinosaurSpecies(
    id: "dino_gallimimus",
    name: "Gallimimus",
    description: "A fast, ostrich-like dinosaur that likely lived in flocks and foraged for small animals and plants.",
    diet: "omnivore", 
    incubationCostDollars: 8000,
    fossilExcavationEnergyCost: 30,
    baseRating: 120,
    comfortThreshold: 0.75, 
    socialNeedsMin: 5,
    socialNeedsMax: 15,
    enclosureSizeNeeds: 15, 
    icon: "🦕",
    minPlayerLevelToUnlock: 2,
  ),
  DinosaurSpecies(
    id: "dino_dilophosaurus",
    name: "Dilophosaurus",
    description: "A medium-sized carnivore with twin crests, known for its frill and venomous spit (in JP lore).",
    diet: "carnivore",
    incubationCostDollars: 18000,
    fossilExcavationEnergyCost: 60,
    baseRating: 280,
    comfortThreshold: 0.55,
    socialNeedsMin: 1,
    socialNeedsMax: 3,
    enclosureSizeNeeds: 9,
    icon: "🦖",
    minPlayerLevelToUnlock: 7,
  ),
  DinosaurSpecies(
    id: "dino_stegosaurus",
    name: "Stegosaurus",
    description: "A large herbivore easily recognized by the double row of kite-shaped plates along its back and tail spikes (thagomizer).",
    diet: "herbivore",
    incubationCostDollars: 20000,
    fossilExcavationEnergyCost: 65,
    baseRating: 250,
    comfortThreshold: 0.60,
    socialNeedsMin: 2,
    socialNeedsMax: 6,
    enclosureSizeNeeds: 14,
    icon: "🦕",
    minPlayerLevelToUnlock: 8,
  ),
  DinosaurSpecies(
    id: "dino_compsognathus",
    name: "Compsognathus",
    description: "A small, bipedal carnivore, often hunting in packs to overwhelm small prey.",
    diet: "carnivore",
    incubationCostDollars: 5000,
    fossilExcavationEnergyCost: 20,
    baseRating: 50, 
    comfortThreshold: 0.60,
    socialNeedsMin: 5,
    socialNeedsMax: 20,
    enclosureSizeNeeds: 5,
    icon: "🦖",
    minPlayerLevelToUnlock: 1,
  ),
  DinosaurSpecies(
    id: "dino_pteranodon", 
    name: "Pteranodon",
    description: "A large flying reptile (pterosaur) with a distinctive cranial crest and a leathery wingspan.",
    diet: "piscivore",
    incubationCostDollars: 30000,
    fossilExcavationEnergyCost: 80,
    baseRating: 400,
    comfortThreshold: 0.50,
    socialNeedsMin: 2,
    socialNeedsMax: 8,
    enclosureSizeNeeds: 18, 
    icon: "🐉", 
    minPlayerLevelToUnlock: 10,
  ),
  DinosaurSpecies(
    id: "dino_metriacanthosaurus",
    name: "Metriacanthosaurus",
    description: "A medium-to-large-sized theropod dinosaur from the Middle Jurassic period.",
    diet: "carnivore",
    incubationCostDollars: 35000,
    fossilExcavationEnergyCost: 90,
    baseRating: 450,
    comfortThreshold: 0.50,
    socialNeedsMin: 1,
    socialNeedsMax: 2,
    enclosureSizeNeeds: 16,
    icon: "🦖",
    minPlayerLevelToUnlock: 9,
  ),
  DinosaurSpecies(
    id: "dino_proceratosaurus",
    name: "Proceratosaurus",
    description: "An early, small-sized tyrannosauroid with a distinctive nasal crest.",
    diet: "carnivore",
    incubationCostDollars: 10000,
    fossilExcavationEnergyCost: 40,
    baseRating: 150,
    comfortThreshold: 0.65,
    socialNeedsMin: 2,
    socialNeedsMax: 5,
    enclosureSizeNeeds: 7,
    icon: "🦖",
    minPlayerLevelToUnlock: 4,
  ),
  DinosaurSpecies(
    id: "dino_herrerasaurus",
    name: "Herrerasaurus",
    description: "One of the earliest known dinosaurs, a bipedal carnivore from the Late Triassic period.",
    diet: "carnivore",
    incubationCostDollars: 16000,
    fossilExcavationEnergyCost: 55,
    baseRating: 220,
    comfortThreshold: 0.58,
    socialNeedsMin: 1,
    socialNeedsMax: 3,
    enclosureSizeNeeds: 10,
    icon: "🦖",
    minPlayerLevelToUnlock: 6,
  ),
  DinosaurSpecies(
    id: "dino_segisaurus",
    name: "Segisaurus",
    description: "A small, agile coelophysoid theropod known from a single incomplete fossil.",
    diet: "carnivore", 
    incubationCostDollars: 7000,
    fossilExcavationEnergyCost: 25,
    baseRating: 90,
    comfortThreshold: 0.70,
    socialNeedsMin: 2,
    socialNeedsMax: 7,
    enclosureSizeNeeds: 6,
    icon: "🦖",
    minPlayerLevelToUnlock: 2,
  ),
  DinosaurSpecies(
    id: "dino_baryonyx",
    name: "Baryonyx",
    description: "A large spinosaurid dinosaur with distinctive, large claws and a long, crocodile-like snout, adapted for catching fish.",
    diet: "piscivore",
    incubationCostDollars: 40000,
    fossilExcavationEnergyCost: 100,
    baseRating: 500,
    comfortThreshold: 0.50,
    socialNeedsMin: 1,
    socialNeedsMax: 2,
    enclosureSizeNeeds: 17, 
    icon: "🦖",
    minPlayerLevelToUnlock: 11,
  ),
  DinosaurSpecies(
    id: "dino_ankylosaurus", 
    name: "Ankylosaurus",
    description: "A heavily armored herbivore with a massive club-like tail, offering formidable defense.",
    diet: "herbivore",
    incubationCostDollars: 22000,
    fossilExcavationEnergyCost: 70,
    baseRating: 300,
    comfortThreshold: 0.55, 
    socialNeedsMin: 1,
    socialNeedsMax: 3,
    enclosureSizeNeeds: 15,
    icon: "🦕",
    minPlayerLevelToUnlock: 14,
  ),
];

// Initial Building Templates
List<BuildingTemplate> initialBuildingTemplates = [
  BuildingTemplate(
    id: "bldg_small_herb_enclosure",
    name: "Small Herbivore Paddock",
    type: "enclosure",
    costDollars: 10000,
    icon: "mdi-fence",
    capacity: 5, 
    operationalCostPerMinuteDollars: 100,
    parkRatingBoost: 50,
    sizeX: 3, sizeY: 3,
    powerRequired: 5, // Example power requirement
  ),
    BuildingTemplate(
    id: "bldg_small_carn_enclosure",
    name: "Small Carnivore Paddock",
    type: "enclosure",
    costDollars: 15000, 
    icon: "mdi-gate-alert",
    capacity: 3, 
    operationalCostPerMinuteDollars: 200,
    parkRatingBoost: 70,
    sizeX: 3, sizeY: 3,
    powerRequired: 7, // Example power requirement
  ),
  BuildingTemplate(
    id: "bldg_fossil_center",
    name: "Fossil Center",
    type: "fossil_center",
    costDollars: 20000,
    icon: "mdi-bone",
    operationalCostPerMinuteDollars: 500,
    parkRatingBoost: 20,
    sizeX: 2, sizeY: 2,
    powerRequired: 15,
  ),
  BuildingTemplate(
    id: "bldg_hatchery",
    name: "Hammond Creation Lab",
    type: "hatchery",
    costDollars: 30000,
    icon: "mdi-egg-outline",
    capacity: 1, 
    operationalCostPerMinuteDollars: 1000,
    parkRatingBoost: 30,
    sizeX: 2, sizeY: 3,
    powerRequired: 25,
  ),
   BuildingTemplate(
    id: "bldg_visitor_center",
    name: "Visitor Center",
    type: "visitor_center",
    costDollars: 30000,
    icon: "mdi-office-building",
    operationalCostPerMinuteDollars: 300,
    incomePerMinuteDollars: 1000, 
    parkRatingBoost: 100,
    sizeX: 2, sizeY: 2,
    powerRequired: 10, // Visitor centers also need some power
  ),
  BuildingTemplate(
    id: "bldg_food_station_herb",
    name: "Herbivore Feeder",
    type: "food_station",
    costDollars: 5000,
    icon: "mdi-food-apple-outline",
    capacity: enclosureBaseFoodCapacity, 
    operationalCostPerMinuteDollars: 50,
    sizeX: 1, sizeY: 1,
    powerRequired: 2,
  ),
  BuildingTemplate(
    id: "bldg_food_station_carn",
    name: "Carnivore Feeder",
    type: "food_station",
    costDollars: 7500,
    icon: "mdi-food-steak",
    capacity: enclosureBaseFoodCapacity, 
    operationalCostPerMinuteDollars: 100,
    sizeX: 1, sizeY: 1,
    powerRequired: 3,
  ),
  BuildingTemplate(
    id: "bldg_research_outpost",
    name: "Research Outpost",
    type: "research_outpost",
    costDollars: 25000,
    icon: "mdi-flask-outline",
    operationalCostPerMinuteDollars: 750,
    parkRatingBoost: 40,
    sizeX: 2, sizeY: 2,
    powerRequired: 20,
  ),
   BuildingTemplate(
    id: "bldg_gift_shop",
    name: "Gift Shop",
    type: "amenity_shop",
    costDollars: 20000,
    icon: "mdi-gift-outline",
    operationalCostPerMinuteDollars: 200,
    incomePerMinuteDollars: 1500,
    parkRatingBoost: 30,
    sizeX: 1, sizeY: 2,
    powerRequired: 5,
  ),
  BuildingTemplate(
    id: "bldg_power_plant_small",
    name: "Small Power Plant",
    type: "power_plant",
    costDollars: 30000,
    icon: "mdi-transmission-tower",
    operationalCostPerMinuteDollars: 1200,
    parkRatingBoost: 10,
    sizeX: 3, sizeY: 2,
    powerOutput: 100, // Generates 100 power units
    powerRequired: 0, // Power plants don't consume their own type of power
  ),
];