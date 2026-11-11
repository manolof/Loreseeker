-- Curated notable storylines, grouped by zone. Matched by quest NAME at runtime: any listed
-- quest that exists for this character tags its whole chain, so there are no hand-typed IDs.
-- Every name here was checked against the Forever quest database (LoreseekerDev/names.js).
-- Storylines for the other faction simply don't resolve; `/lore check` lists those.
-- Players can also star any chain themselves (saved per character).
local _, LW = ...

local S = { unresolved = {} }
LW.Storylines = S

local function L(zone, name, blurb, ...) return { zone = zone, name = name, blurb = blurb, quests = { ... } } end

S.list = {
  -- Elwynn Forest, Dun Morogh, Loch Modan ------------------------------------------------------
  L("Elwynn Forest", "The Collector", "Stolen gold from the Elwynn mines leads to a man with expensive tastes.",
    "The Collector", "Manhunt"),
  L("Elwynn Forest", "A Fishy Peril", "Murlocs upriver, and a guard nobody in Stormwind will listen to.",
    "A Fishy Peril", "Further Concerns", "Cloth and Leather Armor"),
  L("Loch Modan", "In Defense of the King's Lands", "Holding the Loch against the Stonesplinter troggs, valley by valley.",
    "In Defense of the King's Lands"),
  L("Loch Modan", "Ironband's Excavation", "The Explorers' League dig goes quiet. Somebody has to go and look.",
    "Ironband's Excavation", "Excavation Progress Report", "Report to Ironforge", "Gathering Idols"),
  L("Loch Modan", "The Stonewrought Dam", "Dark Iron saboteurs and the dam that holds back the Loch.",
    "A Dark Threat Looms", "Stormpike's Order", "Stormpike's Delivery"),

  -- Westfall, Redridge, Duskwood ----------------------------------------------------------------
  L("Westfall", "The Defias Brotherhood", "Stormwind's masons, cheated by its nobles, become an army. Ends in the Deadmines.",
    "The Defias Brotherhood", "The People's Militia"),
  L("Westfall", "The Coast Isn't Clear", "Murlocs on the Westfall shore and the lighthouse keeper's ghost.",
    "The Coast Isn't Clear", "Keeper of the Flame", "The Coastal Menace"),
  L("Redridge Mountains", "Missing In Action", "Corporal Keeshan, a prisoner of the Blackrock orcs. Get him out alive.",
    "Missing In Action", "Blackrock Menace", "Tharil'zun", "Shadow Magic"),
  L("Redridge Mountains", "The Missing Diplomat", "A vanished envoy leads from Stormwind's back alleys to Theramore and a far bigger plot.",
    "The Missing Diplomat"),
  L("Duskwood", "The Legend of Stalvan", "A love story turned murder, pieced together from letters across three zones.",
    "The Legend of Stalvan"),
  L("Duskwood", "Morgan Ladimore", "Duskwood's restless knight and the tragedy of the family he came home to.",
    "Morgan Ladimore", "Mor'Ladim", "The Daughter Who Lived", "A Daughter's Love", "The Weathered Grave"),
  L("Duskwood", "Bride of the Embalmer", "Abercrombie the hermit only wants a few supplies. Then the town finds out why.",
    "Bride of the Embalmer", "The Hermit", "Ghoulish Effigy", "Note to the Mayor"),
  L("Duskwood", "Morbent Fel", "Sven's family was murdered by a shadowy figure. The trail ends at a necromancer's door.",
    "Sven's Revenge", "Sven's Camp", "The Shadowy Figure", "Armed and Ready", "Morbent Fel"),
  L("Duskwood", "The Night Watch", "Darkshire's volunteers, holding the line because nobody else will.",
    "The Night Watch", "The Totem of Infliction"),
  L("Duskwood", "Worgen in the Woods", "Where Duskwood's worgen came from.",
    "Worgen in the Woods"),
  L("Duskwood", "Look To The Stars", "A blind stargazer, a stolen telescope part and what he sees coming.",
    "Look To The Stars"),
  L("Duskwood", "The Scythe of Elune", "A night elf's missing friend, a cursed scythe and the truth behind the worgen.",
    "The Howling Vale", "Velinde Starsong", "Velinde's Effects", "The Scythe of Elune", "Answered Questions"),

  -- Wetlands, Arathi, Hillsbrad, Alterac --------------------------------------------------------
  L("Wetlands", "The Greenwarden", "The marsh's keeper asks you to thin out what is poisoning it.",
    "The Greenwarden", "Tramping Paws", "Fire Taboo"),
  L("Wetlands", "The Third Fleet", "A drowned captain, a cursed crew and the paladin's relic that holds them here.",
    "The Third Fleet", "The Cursed Crew", "Lifting the Curse", "The Eye of Paleth", "Cleansing the Eye"),
  L("Wetlands", "Whelgar's Excavation", "The dig team is missing, and something in the fossils wants them to stay that way.",
    "In Search of The Excavation Team", "Ormer's Revenge", "Uncovering the Past"),
  L("Wetlands", "The Dragonmaw", "Dragonmaw orcs gather in the hills above Menethil under a new warlord.",
    "War Banners", "Nek'rosh's Gambit", "Defeat Nek'rosh"),
  L("Wetlands", "The Absent Minded Prospector", "Prospector Remtravel and a fossil that takes you across two continents.",
    "The Absent Minded Prospector"),
  L("Wetlands", "The Thandol Span", "Dark Irons hold the great bridge to Arathi.",
    "The Thandol Span", "Plea To The Alliance"),
  L("Arathi Highlands", "The Princess Trapped", "A voice from under the earth begs to be freed. Think carefully before you help Myzrael.",
    "The Princess Trapped", "Stones of Binding", "Breaking the Keystone", "Myzrael's Allies", "Summoning the Princess"),
  L("Arathi Highlands", "Stromgarde", "The fallen capital of the first human kingdom, fought over by everyone.",
    "Stromgarde Badges", "Worth Its Weight in Gold", "Northfold Manor"),
  L("Arathi Highlands", "Hints of a New Plague?", "A Forsaken courier, intercepted letters and what the apothecaries are brewing.",
    "Hints of a New Plague?"),
  L("Hillsbrad Foothills", "The Syndicate", "Assassins in Southshore, an encrypted letter and the nobles of fallen Alterac.",
    "Syndicate Assassins", "Encrypted Letter", "Letter to Stormpike", "Further Mysteries", "Dark Council", "Noble Deaths", "Assassin's Contract", "Baron's Demise"),

  -- Stranglethorn Vale --------------------------------------------------------------------------
  L("Stranglethorn Vale", "The Green Hills of Stranglethorn", "Hemet Nesingwary's lost book, page by page.",
    "The Green Hills of Stranglethorn"),
  L("Stranglethorn Vale", "Nesingwary's Expedition", "The great hunter's safari camp. A hunter's rite of passage.",
    "Big Game Hunter", "Raptor Mastery", "Panther Mastery", "Tiger Mastery", "Welcome to the Jungle"),
  L("Stranglethorn Vale", "Colonel Kurzen", "A Stormwind colonel went into the jungle and something else came back.",
    "Colonel Kurzen", "Bookie Herod", "The Hidden Key", "The Spy Revealed!", "Kurzen's Mystery", "Troll Witchery", "Mai'Zoth"),
  L("Stranglethorn Vale", "The Bloodsail Buccaneers", "Pirates, goblins and Booty Bay's uneasy peace.",
    "The Bloodsail Buccaneers", "Scaring Shaky", "Stoley's Debt", "Keep An Eye Out", "Up to Snuff"),
  L("Stranglethorn Vale", "Message in a Bottle", "A castaway princess on an island of ogres.",
    "Message in a Bottle", "The Captain's Chest", "The Captain's Cutlass", "Facing Negolash"),
  L("Stranglethorn Vale", "Zanzil's Secret", "The witch doctor who makes Booty Bay's dead get back up.",
    "Zanzil's Secret", "Stranglethorn Fever", "Venture Company Mining"),

  -- Swamp of Sorrows, Badlands, Searing Gorge, Burning Steppes, Blasted Lands --------------------
  L("Swamp of Sorrows", "The Atal'ai", "Exiled trolls, a sunken temple and the god they mean to bring back.",
    "Pool of Tears", "The Atal'ai Exile", "Into The Temple of Atal'Hakkar", "The Temple of Atal'Hakkar", "Jammal'an the Prophet", "The Essence of Eranikus"),
  L("Swamp of Sorrows", "Galen's Escape", "A Stormwind soldier caged by the Lost Ones.",
    "Galen's Escape", "Draenethyst Crystals", "The Lost Supplies"),
  L("Badlands", "Uldaman", "The titans' vault and the explorers who should not have opened it.",
    "Power Stones", "The Lost Dwarves", "Agmond's Fate", "Solution to Doom", "The Lost Tablets of Will", "A Sign of Hope", "Amulet of Secrets", "Prospect of Faith", "The Platinum Discs"),
  L("Badlands", "Lotwil's Elementals", "A gnome scientist with a plan that everyone but him can see ending badly.",
    "Study of the Elements: Rock", "This Is Going to Be Hard", "Fiery Blaze Enchantments", "Mirages"),
  L("Searing Gorge", "The Slag Pit", "Kalaran Windblade was a slave here. He has a list.",
    "Divine Retribution", "The Flawless Flame", "Forging the Shaft", "The Flame's Casing", "The Torch of Retribution", "Squire Maltrake", "Set Them Ablaze!", "Trinkets..."),
  L("Searing Gorge", "Dwarven Justice", "Dark Iron prisoners, and a key that opens more than a cell.",
    "Suntara Stones", "Dwarven Justice", "Release Them", "The Key to Freedom"),
  L("Burning Steppes", "The Great Masquerade", "Who really sits beside Stormwind's boy king? The Alliance road to Onyxia.",
    "Dragonkin Menace", "The True Masters", "Marshal Windsor", "Abandoned Hope", "A Crumpled Up Note", "A Shred of Hope", "Jail Break!", "Stormwind Rendezvous", "The Great Masquerade", "The Dragon's Eye", "Drakefire Amulet"),
  L("Burning Steppes", "The Champion of the Horde", "Thrall, Eitrigg and Rexxar: the Horde road to Onyxia.",
    "Warlord's Command", "Eitrigg's Wisdom", "For The Horde!", "What the Wind Carries", "The Champion of the Horde", "The Testament of Rexxar", "Oculus Illusions", "Emberstrife", "The Test of Skulls, Scryer", "Ascension...", "Blood of the Black Dragon Champion"),
  L("Blasted Lands", "The Fallen Hero of the Horde", "A dead orc's last request, and the demon who killed him.",
    "Fall From Grace", "The Disgraced One", "The Missing Orders", "The Swamp Talker", "A Tale of Sorrow", "The Stones That Bind Us", "Kirith", "The Cover of Darkness", "The Demon Hunter", "Loramus", "Breaking the Ward", "The Name of the Beast", "Azsharite", "The Formation of Felbane", "You Are Rakh'likh, Demon"),

  -- Plaguelands, Hinterlands --------------------------------------------------------------------
  L("Western Plaguelands", "The Scourge Cauldrons", "Breaking the plague cauldrons that keep Lordaeron dead.",
    "The Scourge Cauldrons", "A Plague Upon Thee", "Unfinished Business"),
  L("Western Plaguelands", "The Barov Family", "Two brothers, one living and one dead, each asking you to kill the other.",
    "Barov Family Fortune", "The Last Barov"),
  L("Western Plaguelands", "The Battle of Darrowshire", "A ghost child looking for her father. Relive the night her village fell.",
    "Sister Pamela", "Pamela's Doll", "Auntie Marlene", "A Strange Historian", "The Annals of Darrowshire", "Brother Carlin", "Villains of Darrowshire", "Heroes of Darrowshire", "Marauders of Darrowshire", "Return to Chromie", "The Battle of Darrowshire", "Hidden Treasures"),
  L("Western Plaguelands", "In Dreams", "Taelan Fordring's choice at Hearthglen. One of the great Classic stories.",
    "Scarlet Subterfuge", "In Dreams"),
  L("Eastern Plaguelands", "Tirion Fordring", "An exiled paladin, the orc he spared and the son he lost to the Scarlet Crusade.",
    "Demon Dogs", "Blood Tinged Skies", "Carrion Grubbage", "Redemption", "Of Forgotten Memories", "Of Lost Honor", "Of Love and Family"),
  L("Eastern Plaguelands", "The Restless Souls", "The dead of Stratholme cannot leave. Egan found a way to help them.",
    "The Restless Souls", "Zaeldarr the Outcast"),
  L("Eastern Plaguelands", "The Argent Dawn", "The order that still fights the Scourge when the kingdoms have given up.",
    "The Argent Hold", "The Flesh Does Not Lie", "The Active Agent", "Houses of the Holy", "The Archivist", "The Truth Comes Crashing Down", "Above and Beyond", "Lord Maxwell Tyrosus"),
  L("Eastern Plaguelands", "Scholomance", "The school where the Cult of the Damned trains its necromancers.",
    "Plagued Hatchlings", "Doctor Theolen Krastinov, the Butcher", "Krastinov's Bag of Horrors", "Kirtonos the Herald", "The Human, Ras Frostwhisper", "Soulbound Keepsake", "The Lich, Ras Frostwhisper", "Dawn's Gambit"),
  L("The Hinterlands", "Saving Sharpbeak", "A gryphon chick taken by the Witherbark trolls.",
    "Witherbark Cages", "The Altar of Zul", "Thadius Grimshade", "Nekrum's Medallion", "The Divination", "Return to Troyas", "Saving Sharpbeak"),
  L("The Hinterlands", "The God Hakkar", "Yeh'kinya's errands look harmless. They are the first steps toward the Blood God.",
    "Screecher Spirits", "The Prophecy of Mosh'aru", "The Ancient Egg", "The God Hakkar"),

  -- Kalimdor: Darkshore, Ashenvale, Stonetalon, Barrens -----------------------------------------
  L("Darkshore", "The Tower of Althalaxx", "A cult of the Twilight's Hammer, from Darkshore into Ashenvale.",
    "The Tower of Althalaxx"),
  L("Darkshore", "The Blackwood Corrupted", "The furbolgs were friends once. Find out what changed them.",
    "The Cliffspring River", "The Blackwood Corrupted", "Bashal'Aran", "The Fall of Ameth'Aran", "For Love Eternal"),
  L("Darkshore", "The Master's Glaive", "An ancient of lore sends you to where an Old God's servant fell.",
    "Onu", "The Master's Glaive", "The Twilight Camp", "Mathystra Relics"),
  L("Darkshore", "The Sleeper Has Awakened", "Escort a druid who keeps falling asleep on the road. You will remember it.",
    "The Sleeper Has Awakened", "Therylune's Escape", "The Powers Below"),
  L("Darkshore", "Gyromast's Revenge", "A gnome, his broken robot and a grudge.",
    "Gyromast's Retrieval", "Gyromast's Revenge"),
  L("Ashenvale", "Raene's Cleansing", "Purging the corruption from Ashenvale's forest, one relic at a time.",
    "Raene's Cleansing", "An Aggressive Defense", "The Branch of Cenarius", "Satyr Slaying!"),
  L("Ashenvale", "Kayneth Stillwind", "A druid cataloguing what the Forsaken have released into the wild.",
    "The Zoram Strand", "Pridewings of Stonetalon", "Kayneth Stillwind", "Forsaken Diseases", "Insane Druids"),
  L("Ashenvale", "Elune's Tear", "A fallen star and the shrine it belongs to.",
    "Elune's Tear", "The Ruins of Stardust", "Fallen Sky Lake"),
  L("Stonetalon Mountains", "Reclaiming the Charred Vale", "The Venture Company is stripping the mountain. The night elves want it stopped.",
    "Super Reaper 6000", "Further Instructions", "Journey to Stonetalon Peak", "Reclaiming the Charred Vale", "On Guard in Stonetalon"),
  L("The Barrens", "Lost in Battle", "Mankrik's wife, somewhere in the Barrens.",
    "Lost in Battle"),
  L("The Barrens", "The Wailing Caverns", "Druids who went to sleep to heal the land, and the nightmare that kept them.",
    "Leaders of the Fang", "In Nightmares", "The Glowing Shard", "Deviate Eradication", "Smart Drinks", "Trouble at the Docks"),

  -- Desolace, Dustwallow, Thousand Needles, Tanaris ---------------------------------------------
  L("Desolace", "Legends of Maraudon", "Zaetar's children and Princess Theradras, in Desolace's sacred caverns.",
    "Legends of Maraudon", "The Scepter of Celebras", "Corruption of Earth and Seed", "Twisted Evils", "The Pariah's Instructions", "Vyletongue Corruption"),
  L("Desolace", "Strange Alliance", "Two centaur clans at war. You can only be a friend to one.",
    "The Kolkar of Desolace", "Khan Dez'hepah", "Centaur Bounty", "Strange Alliance", "Raid on the Kolkar", "Stealing Supplies"),
  L("Desolace", "The Karnitol Shipwreck", "A wrecked ship, a locked chest and a captain's last map.",
    "The Karnitol Shipwreck", "Claim Rackmore's Treasure!"),
  L("Desolace", "Vahlarriel's Search", "A night elf scout looking for a friend the demons took.",
    "Vahlarriel's Search", "Search for Tyranis", "Escape Through Force", "Escape Through Stealth"),
  L("Dustwallow Marsh", "The Shady Rest Inn", "Someone burned an inn in the marsh, with a family inside. Both factions want to know who.",
    "The Lost Report", "Suspicious Hoofprints", "Lieutenant Paval Reethe", "The Black Shield", "Jarl Needs Eyes", "Jarl Needs a Blade"),
  L("Dustwallow Marsh", "The Brood of Onyxia", "Black dragon eggs in the marsh, and the lair they come from.",
    "The Brood of Onyxia", "Challenge Overlord Mok'Morokk", "Identifying the Brood", "Army of the Black Dragon"),
  L("Thousand Needles", "The Shimmering Flats", "Goblins against gnomes on the salt flats, and everything it takes to win a race.",
    "Rocket Car Parts", "Goblin Sponsorship", "The Eighteenth Pilot", "Razzeric's Tweaking", "Safety First", "Encrusted Tail Fins", "News for Fizzle", "The Rumormonger"),
  L("Tanaris", "Wastewander Justice", "Gadgetzan's water is being stolen. The goblins pay well for a fix.",
    "Water Pouch Bounty", "Wastewander Justice", "More Wastewander Justice", "WANTED: Caliph Scorpidsting", "WANTED: Andre Firebeard", "Pirate Hats Ahoy!"),
  L("Tanaris", "Zul'Farrak", "The Sandfury trolls and the hydra god under their city.",
    "Divino-matic Rod", "Gahz'rilla", "Troll Temper", "Scarab Shells", "Tiara of the Deep", "The Prophecy of Mosh'aru"),
  L("Tanaris", "The Thirsty Goblin", "A goblin's search for the perfect drink.",
    "The Thirsty Goblin", "In Good Taste", "Sprinkle's Secret Ingredient", "Delivery for Marin"),

  -- Feralas, Un'Goro, Azshara -------------------------------------------------------------------
  L("Feralas", "The Missing Courier", "A lost courier and the first sign of something stirring under the sand.",
    "The Missing Courier", "Boat Wreckage", "The Knife Revealed", "Psychometric Reading", "The Woodpaw Gnolls", "The Writhing Deep", "Freed from the Hive", "A Hero's Welcome", "Rise of the Silithid"),
  L("Feralas", "Against the Hatecrest", "Naga on the isle of Sardor, and the relic they came for.",
    "The Ruins of Solarsal", "Return to Feathermoon Stronghold", "Against the Hatecrest", "Against Lord Shalzaru", "Delivering the Relic"),
  L("Feralas", "The Giant Guardian", "A lost child of the mountain giants.",
    "The Giant Guardian", "Wandering Shay"),
  L("Feralas", "Dire Maul", "Eldre'Thalas: the last of the Highborne, their prisoner and the ogres upstairs.",
    "Elven Legends", "The Madness Within", "The Treasure of the Shen'dralar", "Pusillin and the Elder Azj'Tordin", "Lethtendris's Web", "Shards of the Felvine", "A Broken Trap", "The Gordok Ogre Suit", "Unfinished Gordok Business", "Free Knot!"),
  L("Un'Goro Crater", "Linken", "An amnesiac adventurer and a sword that remembers more than he does.",
    "It's a Secret to Everybody", "Linken's Sword", "It's Dangerous to Go Alone", "Linken's Adventure", "Linken's Memory", "Silver Heart", "Aquementas"),
  L("Un'Goro Crater", "Crystals of Power", "The pylons the titans left in the crater, and what they are for.",
    "Crystals of Power", "The Northern Pylon", "The Eastern Pylon", "The Western Pylon", "Making Sense of It"),
  L("Un'Goro Crater", "Marshal Expedition", "Williden Marshal's expedition did not go to plan.",
    "Expedition Salvation", "Williden's Journal", "Alien Ecology", "Shizzle's Flyer", "Lost!", "Beware of Pterrordax", "Roll the Bones"),
  L("Un'Goro Crater", "The Fare of Lar'korwi", "Hunting the queen of the crater's raptors.",
    "The Fare of Lar'korwi", "The Scent of Lar'korwi", "The Bait for Lar'korwi", "The Mighty U'cha", "The Apes of Un'Goro", "Chasing A-Me 01"),
  L("Azshara", "Hydraxis and the Molten Core", "A water lord with a grudge against Ragnaros.",
    "Poisoned Water", "Stormers and Rumblers", "Eye of the Emberseer", "The Molten Core", "Agent of Hydraxis", "Hands of the Enemy", "A Hero's Reward"),
  L("Azshara", "Spiritual Unrest", "The Highborne dead of Azshara have not left.",
    "Spiritual Unrest", "A Land Filled with Hatred", "Stealing Knowledge", "Kim'jael Indeed!"),

  -- Felwood, Winterspring, Silithus -------------------------------------------------------------
  L("Felwood", "Forces of Jaedenar", "The Shadow Council's stronghold, and a paladin who went in alone.",
    "Forces of Jaedenar", "Collection of the Corrupt Water", "Seeking Spiritual Aid", "Cleansed Water Returns to Felwood", "Dousing the Flames of Protection", "A Final Blow", "Rescue From Jaedenar", "Retribution of the Light", "The Remains of Trey Lightforge"),
  L("Felwood", "The Timbermaw", "The one furbolg tribe that stayed sane, and what it costs them.",
    "Timbermaw Ally", "Speak to Nafien", "Deadwood of the North", "Speak to Salfa", "Winterfall Activity"),
  L("Felwood", "Cleansing Felwood", "The Emerald Circle tries to heal a forest the Legion poisoned.",
    "Cleansing Felwood", "Corrupted Sabers", "Verifying the Corruption", "Well of Corruption"),
  L("Winterspring", "The Winterfall Furbolgs", "Something in their firewater is driving the Winterfall mad.",
    "Winterfall Firewater", "Falling to Corruption", "Mystery Goo", "Toxic Horrors", "Winterfall Runners", "High Chief Winterfall", "The Final Piece", "Words of the High Chief"),
  L("Winterspring", "Are We There, Yeti?", "A goblin, a mechanical yeti and three people he would like to frighten.",
    "Are We There, Yeti?"),
  L("Winterspring", "Guardians of the Altar", "The moonkin of Winterspring and the altar they have guarded since the Sundering.",
    "Wild Guardians", "Guardians of the Altar", "Wildkin of Elune", "Enraged Wildkin"),
  L("Silithus", "The Twilight's Hammer", "The cult in the desert, its lexicon and who it is praying to.",
    "The Twilight Mystery", "The Deserter", "The Twilight Lexicon", "A Terrible Purpose", "True Believers", "Securing the Supply Lines"),
  L("Silithus", "Dearest Natalia", "A Cenarion commander's love has walked into the hive. Find out what she heard.",
    "Dearest Natalia", "Into The Maw of Madness", "Breaking the Code", "Glyph Chasing", "Unraveling the Mystery"),
  L("Silithus", "Scepter of the Shifting Sands", "The bronze dragonflight and the gates of Ahn'Qiraj.",
    "What Tomorrow Brings", "Only One May Rise", "The Path of the Righteous", "The Hand of the Righteous", "Anachronos", "Long Forgotten Memories", "The Charge of the Dragonflights", "Bang a Gong!"),

  -- Dungeons ------------------------------------------------------------------------------------
  L("Dungeons", "The Deadmines", "Edwin VanCleef's hideout under Moonbrook.",
    "Oh Brother. . .", "Underground Assault", "Red Silk Bandanas", "Collecting Memories"),
  L("Dungeons", "The Stockade Riots", "Stormwind's prison has been taken over by the people inside it.", "The Color of Blood", "Quell The Uprising", "Crime and Punishment", "The Fury Runs Deep", "The Stockade Riots"),
  L("Dungeons", "Gnomeregan", "The gnomes irradiated their own city to save it. It did not work.",
    "Save Techbot's Brain!", "Gnogaine", "The Grand Betrayal", "Data Rescue", "Gyrodrillmatic Excavationators", "Essential Artificials", "A Fine Mess"),
  L("Dungeons", "Blackfathom Deeps", "A temple of Elune, drowned, with the Twilight's Hammer living in it.",
    "Knowledge in the Deeps", "Researching the Corruption", "Twilight Falls", "In Search of Thaelrid", "Blackfathom Villainy"),
  L("Dungeons", "Shadowfang Keep", "The archmage behind Silverpine's worgen.",
    "Arugal Must Die", "The Dead Fields", "The Book of Ur", "Deathstalkers in Shadowfang"),
  L("Dungeons", "The Scarlet Monastery", "The Scarlet Crusade's fortress, and what the Light has become there.",
    "In the Name of the Light", "Mythology of the Titans", "Brother Anton", "Down the Scarlet Path"),
  L("Dungeons", "Blackrock Depths", "Thaurissan's empire under the mountain, and the princess who will not be rescued.",
    "Dark Iron Legacy", "Kharan Mighthammer", "The Bearer of Bad News", "The Fate of the Kingdom", "The Princess's Surprise", "Hurley Blackbreath", "Overmaster Pyron", "Incendius!", "The Heart of the Mountain", "The Good Stuff", "The Love Potion", "Attunement to the Core"),
  L("Dungeons", "Blackrock Spire", "Rend Blackhand's Horde, and the dragon it answers to.",
    "Maxwell's Mission", "Seal of Ascension", "General Drakkisath's Demise", "Mother's Milk", "Put Her Down", "Kibler's Exotic Pets", "En-Ay-Es-Tee-Why", "The Matron Protectorate", "Doomrigger's Clasp"),
  L("Dungeons", "Stratholme", "The city Arthas burned, and the two armies still fighting over the ashes.",
    "The Medallion of Faith", "Aurius' Reckoning", "Ramstein", "Menethil's Gift", "Menethil's Gift"),

  -- Hunter --------------------------------------------------------------------------------------
  L("Hunter", "Taming the Beast", "Every hunter's first companion.",
    "Taming the Beast", "Training the Beast"),
  L("Hunter", "Rhok'delar", "The ancient bow, earned by proving yourself against four demons, alone.",
    "The Hunter's Charm", "The Ancient Leaf", "Ancient Sinew Wrapped Lamina", "Stave of the Ancients", "A Proper String"),
}

--- Tag chains with curated storylines and the player's own stars. Runs inside the index job.
function S:Resolve()
  wipe(self.unresolved)
  local byName = LW.Index.byName
  for _, s in ipairs(self.list) do
    local chains, found = {}, false
    -- Quest IDs (generated; the same in every client language). The names are only the
    -- fallback for a storyline added without regenerating the ID file.
    local ids = LW.StorylineIds and LW.StorylineIds[s.name]
    if not ids then
      ids = {}
      for _, qname in ipairs(s.quests) do
        for _, id in ipairs(byName[qname] or {}) do ids[#ids + 1] = id end
      end
    end
    do
      for _, id in ipairs(ids) do
        local e = LW.Index.quests[id]
        local chain = e and LW.Chains:Get(e.chain)
        if chain then
          -- very long chains are whole starting zones, not one story
          if not chain.curated and chain.size <= 40 then
            chain.curated = s
            chains[#chains + 1] = chain
          end
        elseif e then
          e.curated = s -- a standalone quest can be a storyline too
        end
        if e then found = true end -- only quests this character can do count
      end
    end
    if not found then table.insert(self.unresolved, s.name) end
    -- One storyline can span several separate chains: the biggest keeps the plain name,
    -- the others show as "Storyline: first quest".
    table.sort(chains, function(a, b) return a.size > b.size end)
    s.parts = nil
    for i = 2, #chains do
      chains[i].part = true
      s.parts = s.parts or {}
      s.parts[#s.parts + 1] = chains[i]
    end
    LW.Yield()
  end
  self:ApplyStars()
end

local function starInfo(chain)
  return { name = chain.name, zone = LW.ZoneName(chain.root.zone), blurb = "Marked as notable by you.", user = true }
end

function S:ApplyStars()
  for _, chain in ipairs(LW.Chains.list) do
    local starred = LW.char.starred[chain.root.id]
    if starred and not chain.curated then
      chain.curated = starInfo(chain)
    elseif not starred and chain.curated and chain.curated.user then
      chain.curated = nil
    end
  end
end

function S:IsStarred(chain) return LW.char.starred[chain.root.id] and true or false end

function S:ToggleStar(chain)
  LW.char.starred[chain.root.id] = (not LW.char.starred[chain.root.id]) or nil
  self:ApplyStars()
  LW:Log("star", "%s %s", chain.name, tostring(self:IsStarred(chain)))
  LW.Router:Route()
end

--- A storyline's name in the client's language: a translation if there is one; else, when the
--- storyline is named after one of its quests, that quest's name as the game shows it; else English.
function LW.StorylineName(s)
  local L = LW.L
  if not s then return "" end
  if s.user or LW.locale == "enUS" or LW.locale == "enGB" then return s.name end
  local translated = rawget(L, s.name)
  if translated then return translated end
  local id = LW.StorylineNameQuest and LW.StorylineNameQuest[s.name]
  local questName = id and LibQuestieDB and LibQuestieDB.Quest.Get(id, "name")
  return questName or s.name
end

--- Curated storyline for a quest entry, if any.
function S:For(e)
  if not e then return nil end
  local chain = LW.Chains:Get(e.chain)
  return (chain and chain.curated) or e.curated
end
