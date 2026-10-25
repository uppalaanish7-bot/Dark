extends RefCounted
## Each supplied guardian owns a different element, move set and matching retinue.
const CENTERS := [Vector3(0, 0, 0), Vector3(0, 18, 0), Vector3(0, 36, 0), Vector3(0, 54, 0), Vector3(0, 72, 0), Vector3(0, 90, 0), Vector3(0, 108, 0), Vector3(0, 126, 0), Vector3(0, 144, 0), Vector3(0, 162, 0), Vector3(0, 180, 0)]
const ELEMENTS := ["stone", "water", "fire", "soul", "lightning", "wind", "poison", "ice", "gravity", "lava", "void"]
const NAMES := ["STELAE SENTINEL", "VESPER, TIDAL PALADIN", "PYRE, THE EMBER LORD", "MORVANE, SOUL SHEPHERD", "THE STORMBOUND KNIGHT", "THE GALE HEADSMAN", "PESTILENT PRAETOR", "FROSTBLADE, OATHBREAKER", "THE SIX-WINGED JUDGE", "AZRAEL, MOLTEN SUN", "NOX, THE LAST REAPER"]
const TITLES := ["Court of Stone", "Court of Tides", "Court of Cinders", "Court of Souls", "Court of Thunder", "Court of Gales", "Court of Blight", "Court of Frost", "Court of Gravity", "The Molten Sanctum", "Throne of the Void"]
const COLORS := [Color("e7c78c"), Color("42bff5"), Color("ff703d"), Color("70edc4"), Color("f0e371"), Color("a5e8de"), Color("a4d84c"), Color("a2deff"), Color("9e87ff"), Color("ff431e"), Color("b56beb")]
const DESCRIPTIONS := ["Floor 1 uses physical attacks only. Evade the sentinel's sword and counter during its recovery.", "Floor 2 uses physical attacks only. Keep clear of the paladin's committed sword swings and its retinue's punches.", "Flame breath arrives in bursts. Read the casting motion and move before the cinders erupt.", "Soul wells linger and the shepherd recalls two servants. Break the ritual retinue and evade the spirits.", "Forked lightning follows the knight's casting motion. Sidestep the strike and punish the recovery.", "Cyclones pull inward before the axe releases a gust. Cross the wind and dodge the outward blast.", "Poison gardens persist and spread. Fight on clean ground while weaving between spores and close weapon strikes.", "Frost briefly slows movement. Keep clear of the ice and evade the guardian's committed glacial step.", "Singularities pull toward their centers before starfall. Run out of the pull and through the gaps.", "Molten faults become lingering lava. Follow clear stone between eruptions and avoid the burning charge trail.", "Void rifts echo the reaper's strikes. Three phases end in four low eclipse waves: jump, evade, counter."]
const ANIMATION_CUES := ["Stone_Slam", "Water_Sweep", "Fire_Combo", "Soul_Channel", "Lightning_Lunge", "Wind_Cyclone", "Poison_Cast", "Ice_Cleave", "Gravity_Pulse", "Lava_Crash", "Void_Reap"]
const HEALTH := [640.0, 740.0, 850.0, 880.0, 960.0, 1080.0, 1120.0, 1260.0, 1500.0, 2000.0, 2900.0]
const BOSS_HEALTH_MULTIPLIER: float = 3.0
const SOLDIERS_PER_FLOOR: int = 100
const BOSS_LINES := [
	# Floor I — Stelae Sentinel (Stone)
	{
		"engage": "Halt, bearer of the Canticle Blade. The First Threshold was sealed from within—none may wake the patients above.",
		"phase2": "Stone remembers the chisel long after flesh forgets the wound!",
		"defeat": "The healer's crescent... it was Elder Orin's own hand that turned our lock..."
	},
	# Floor II — Vesper, Tidal Paladin (Water)
	{
		"engage": "Forty-three fevered souls crossed my dry ferry. I will not let you drown their peace in memory.",
		"phase2": "The undertow pulls every forgotten name back to the deep!",
		"defeat": "Read my ledger, knight... they came here to be healed, never to be caged..."
	},
	# Floor III — Pyre, the Ember Lord (Fire)
	{
		"engage": "Orin's parchment still smolders in my brazier! Every fever I burned away left an empty mind behind.",
		"phase2": "Cinders rise! Better ash than the agony of remembering!",
		"defeat": "Look upon the charred seal... 'O.' commanded the furnace never to cool..."
	},
	# Floor IV — Morvane, Soul Shepherd (Soul)
	{
		"engage": "Hush your iron step. These spirits are not dead—they are the living songs your village traded for painless skin.",
		"phase2": "Choir of Greywake, sing the names their bodies left behind!",
		"defeat": "They still breathe down in the valley... return their voices before the Moonwell drinks them dry..."
	},
	# Floor V — The Stormbound Knight (Thunder)
	{
		"engage": "One closed wound for a summer rain. One broken fever for a child's first word. The copper ledger always balances!",
		"phase2": "Lightning tallies the debt! Who will pay for Greywake's borrowed dawn?",
		"defeat": "The price was too high... even the bellkeeper forgot the man who rang the morning..."
	},
	# Floor VI — The Gale Headsman (Wind)
	{
		"engage": "A blue ribbon fluttered through my court—a girl trying to tie her own name to her wrist before the wind took it.",
		"phase2": "Tempest cleave! No thread holds when the Spire inhales!",
		"defeat": "Mara left her truth here: speak a soul's true name over unspent water, and the wind must give it back..."
	},
	# Floor VII — Pestilent Praetor (Blight)
	{
		"engage": "There is no herb in the Moonwell, knight. We distilled living memories into medicine because Orin begged us to save her.",
		"phase2": "Drink the bitter cure! Pain or oblivion—choose your poison!",
		"defeat": "My apothecary page is blank... I cured my own plague and forgot my mother's face..."
	},
	# Floor VIII — Frostblade, Oathbreaker (Frost)
	{
		"engage": "I broke my sword rather than harvest another child's memory. Look what the frost left of my honor.",
		"phase2": "Freeze the clockwork! Let the Moonwell starve in winter!",
		"defeat": "Nox was the kindest of us... he told the well to take his own memories first..."
	},
	# Floor IX — The Six-Winged Judge (Gravity)
	{
		"engage": "Eleven wardens on eleven scales. Break our counterweights, and the prisoner on the high throne awakens to his grief.",
		"phase2": "Kneel beneath the weight of every stolen yesterday!",
		"defeat": "The crown upon Nox's brow is no throne-ornament... it is a shackle forged by Elder Orin's decree..."
	},
	# Floor X — Azrael, Molten Sun (Lava)
	{
		"engage": "I guard the unburned contract! 'Continue the healing until no one suffers—for my daughter, Mara.' Orin wrote our doom!",
		"phase2": "The sun beneath the Spire erupts! No oath survives the crucible!",
		"defeat": "Take the contract to the summit... free the First Keeper from the promise that hollowed him..."
	},
	# Floor XI — Nox, the Last Reaper (Void)
	{
		"engage": "Who climbs to the Moonwell with the Canticle Blade? Have I... known your face before the water took my name?",
		"phase2": "The crown commands me to harvest! Run, before the Spire drinks your memories too!",
		"phase3": "No more! Strike the shackle from my brow—let the last bell ring!",
		"defeat": "I remember now... the sound of the village bell at dawn. Take the unspent elixir... tell Orin the First Keeper forgives him..."
	}
]


static func record(index: int) -> Dictionary:
	var i: int = clampi(index, 0, 10)
	return {"name": NAMES[i], "title": TITLES[i], "element": ELEMENTS[i], "color": COLORS[i], "description": DESCRIPTIONS[i], "animation": ANIMATION_CUES[i], "center": CENTERS[i], "boss_id": "subboss_%d" % (i + 1) if i < 9 else ("grand_boss" if i == 9 else "main_boss"), "soldier_id": "soldier_%d" % (i + 1) if i < 9 else "grand_soldier", "health": HEALTH[i] * BOSS_HEALTH_MULTIPLIER, "soldiers": SOLDIERS_PER_FLOOR}

static func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(11):
		result.append(record(i))
	return result

static func boss_lines(index: int) -> Dictionary:
	return BOSS_LINES[clampi(index, 0, BOSS_LINES.size() - 1)]

