extends RefCounted
## Original narrative and validated, world-specific evidence for The Borrowed Dawn.
const LAYOUT = preload("res://scripts/tower_layout.gd")
const TITLE := "The Borrowed Dawn"
const ECHO_XP := 20
const ECHOES := [
	{
		"title": "The Unbroken Seal", "source": "Mara's rubbing of the entrance lock",
		"text": "Everyone remembers an army breaking into the Spire. But the stone around the Stelae Sentinel's threshold is unbroken. The bolt was withdrawn from inside.\n\nBelow the wardens' crest is a smaller mark: a healer's crescent. The Canticle Blade's clockwork fuller was forged to unlock such seals without harming the minds within.\n\nFather says grief changes what we remember. I have started keeping rubbings, so the stone can disagree with us.\n\n— Mara, bellkeeper of Greywake"
	},
	{
		"title": "The Dry Ferry", "source": "Vesper's passenger register",
		"text": "The Tidal Paladin's register lists no soldiers. Vesper recorded beds, blankets, fever draughts, and forty-three villagers carried up from Greywake.\n\nBeside every name is the same destination: MOONWELL HOSPICE.\n\nA note in Vesper's hand reads: 'No weapons aboard. The healer has asked us to shelter his people.'\n\nThe water stains are beneath the ink. This was written before the night everyone calls the siege."
	},
	{
		"title": "A Charred Admission", "source": "A notice saved from Pyre's furnace",
		"text": "The furnace of Pyre, the Ember Lord, has burned away the date, but three lines survive:\n\n'Open the eleven wards. Let our sick inside. No family is to be turned away. — O.'\n\nPyre wrote on the back: 'I was ordered to burn the admission notices. I kept this one. If we were invaded, why must we destroy the invitations?'\n\nA crescent is pressed into the wax: the same seal as the entrance lock."
	},
	{
		"title": "Voices Without Bodies", "source": "Mara's listening notes in the soul court",
		"text": "Morvane, the Soul Shepherd, calls the voices his flock. One of them is asking me to mend a blue sleeve.\n\nIt is my mother's voice. She asked me that yesterday. She is still alive in Greywake.\n\nThe voice cannot answer a new question. It repeats the same request, with the same tiny laugh, every time the well turns.\n\nThese are not dead spirits. The Moonwell has harvested moments from living bodies and left hollow shells behind."
	},
	{
		"title": "The Storm Ledger", "source": "The Stormbound Knight's copper meter",
		"text": "The Stormbound Knight's copper meter pairs every pulse of healing mana with a personal loss.\n\n'One closed wound: the smell of summer rain.'\n'One cleared fever: a child's first word.'\n\nThere is no entry for a death. The patients return home alive.\n\nThe knight has scratched a warning beneath the totals: 'The well does not count years. It counts what made those years worth living.'"
	},
	{
		"title": "The Bellkeeper's Thread", "source": "A ribbon tied inside the wind organ",
		"text": "My name is Mara. My father is Orin. I ring the bells in Greywake.\n\nI have tied this blue thread to my wrist inside the Gale Headsman's wind court, because yesterday I could not remember why Father was crying.\n\nThe tempest carries familiar voices up the Spire. When I speak a person's true name, their echo turns toward me. Names are addresses. Without them, a memory cannot find its way home.\n\nIf I forget this ribbon, speak my name over the unspent water."
	},
	{
		"title": "The Physician's Empty Page", "source": "Praetor's last medical report",
		"text": "Treatment succeeded. Wounds closed. Plague ended. Patient no longer recognises the physician.\n\nThe Pestilent Praetor tried herbs, venom and prayer before recording the truth: the Moonwell burns living memories into medicine. Its unspent water still holds what it harvested.\n\n'A name spoken over unspent water gives a memory a path home. The Canticle Blade can sever the Spire's seals, but only a living voice can tell a stolen life where it belongs.'\n\nThe patient line has been erased. A blue thread is caught in the binding."
	},
	{
		"title": "Nox Before the Mask", "source": "An oath preserved in the frost",
		"text": "The oldest frost-carving calls Nox the First Keeper, not the Last Reaper.\n\n'I will stand between the well and the village. If it hungers, take my memories before theirs.'\n\nBelow it, Frostblade's chisel grew shallow: 'I remember the promise. I broke my blade to protect him. Look what winter left of our honor.'\n\nFrostblade's broken sword points inward, toward the high throne. The wardens were guarding a king who gave himself to the machine."
	},
	{
		"title": "A Counterweight of Names", "source": "The Six-Winged Judge's balance",
		"text": "The Six-Winged Judge's balance has eleven locks and no treasure pan. Every counterweight faces the high throne.\n\nThe diagram calls the wardens COUNTERWEIGHTS and Nox a LIVING SEAL. The crown upon his brow is drawn as a shackle.\n\nOne rule survives in the margin: 'The keeper cannot revoke a healer's command. The Canticle Blade was forged to sever these eleven counterweights without shattering the minds within.'\n\nWho asked a machine to keep working until suffering itself was gone?"
	},
	{
		"title": "The Unburned Order", "source": "Azrael's sealed original contract",
		"text": "Azrael, the Molten Sun, preserved the original order inside his molten plate. It bears a full signature: ORIN OF GREYWAKE.\n\n'Continue the healing until no one suffers.'\n\nBelow the signature: 'For my daughter, Mara. Let her see another dawn.'\n\nAzrael's reply is still attached: 'No keeper can fulfil this. There will always be another wound. Give the Spire an ending, Orin, or it will borrow every dawn Greywake will ever have.'"
	},
	{
		"title": "The Last Bell", "source": "Nox's message behind the throne court",
		"text": "I tried to obey. I gave the well my childhood, my face, then the sound of my own name. Orin's command remained.\n\nWhen there was nothing of me left to burn, the crown reached down into the valley. The wardens forgot why they stood watch. We became the eclipse we were sworn to prevent.\n\nSever my shackle with the Canticle Blade. Carry the unspent elixir home. Speak the living names over it.\n\nIf the bells fall silent, do not mourn the reaper. There was never a monster here. Only the first prisoner who loved his people too well."
	}
]

const MYSTERIES := [
	{
		"title": "A Siege Without an Army", "clues": [0, 1, 2], "xp": 90,
		"question": "The village remembers an invasion. What actually brought people into the Spire?",
		"options": ["Raiders forced their way inside", "The Spire opened as a refuge", "The wardens stole the village key"], "answer": 1,
		"wrong": "Compare the intact lock, the passenger list and the signed invitation. None describes an attacking army.",
		"resolution": "There was no siege. A healer opened the Spire as a refuge for Greywake's sick, and the wardens admitted them willingly.\n\nThe disaster began as a rescue. The remembered invasion conceals what happened after the doors closed.\n\nOrin's crescent appears on the invitation. Ask him about it when you return."
	},
	{
		"title": "The Choir With No Graves", "clues": [3, 4, 5, 6], "xp": 120,
		"question": "The voices belong to living villagers. What is the Moonwell consuming to make its medicine?",
		"options": ["The souls of fallen soldiers", "Time stolen from tomorrow", "The villagers' living memories"], "answer": 2,
		"wrong": "Mara's mother is alive. The ledger measures lost moments, and the physician describes the price of healing.",
		"resolution": "The choir is made of stolen memories, not the dead. The Moonwell heals bodies by burning the moments that make a person themselves.\n\nIts unspent water still carries recoverable memories. Mara discovered that speaking someone's name can guide an echo back to its owner.\n\nThe elixir can save their bodies. To give their lives back, someone must remember their names."
	},
	{
		"title": "The Prisoner on the Throne", "clues": [7, 8, 9, 10], "xp": 180,
		"question": "An inward-facing prison, an impossible order and a keeper with no name: why does Nox remain on the throne?",
		"options": ["He is bound to Orin's endless command", "He wants to rule an empty village", "He waits for Mara to inherit the crown"], "answer": 0,
		"wrong": "Read the keeper's oath beside the contract. The crown is a restraint, and Nox is forbidden to end the order.",
		"resolution": "Nox is a prisoner of Orin's command: heal until no one suffers. He spent his own memories first, then lost the self that could resist. The wardens became corrupted with him.\n\nOrin signed to save Mara, his daughter. Ending Nox's corrupted vigil stops the command; the elixir preserves what remains.\n\nBring it home with the truth. Orin must speak the names he tried to save."
	}
]

const GUARDIAN_LINES := [
	'"I opened the door for the sick. The Canticle Blade must know: this was a refuge, not a fortress."',
	'"I carried them here across the dry ferry. The passenger register holds their names—none bore weapons."',
	'"The orders burned in my brazier. But the healer\'s crescent in the wax survived."',
	'"They call me shepherd. The choir sings with living voices the Moonwell borrowed."',
	'"Every spark the Canticle Blade strikes costs something someone once loved."',
	'"Listen. A blue ribbon in the wind organ still carries Mara\'s name."',
	'"The wounds close. The Moonwell\'s medicine erases the person behind the patient."',
	'"I broke my oath to preserve his. Nox offered his own memories before taking ours."',
	'"Eleven locks. One shackled keeper. The Canticle Blade was forged to cut his crown."',
	'"I kept Orin\'s signed contract inside my armour. Someone must answer for the borrowed dawn."',
	'"If you still know your name, the Canticle Blade can carry it to the Moonwell and bring it home."'
]

static func echo_room(index: int) -> int:
	return (clampi(index, 0, ECHOES.size() - 1) + 2) % LAYOUT.ROOM_SIZES.size()

static func echo_position(index: int) -> Vector3:
	return LAYOUT.room_centers(index)[echo_room(index)] + Vector3(0, 0, -12)

static func location(index: int) -> String:
	return "FLOOR %02d  /  CHAMBER %s" % [index + 1, ["I", "II", "III", "IV", "V"][echo_room(index)]]

static func sanitize(raw: Variant) -> Dictionary:
	var result := {"clues": [], "solved": []}
	if not raw is Dictionary: return result
	if raw.get("clues") is Array:
		for entry in raw.clues:
			if entry is int and entry >= 0 and entry < ECHOES.size() and entry not in result.clues:
				result.clues.append(entry)
	result.clues.sort()
	if raw.get("solved") is Array:
		for entry in raw.solved:
			if entry is int and entry >= 0 and entry < MYSTERIES.size() and entry not in result.solved and can_solve(result, entry):
				result.solved.append(entry)
	result.solved.sort()
	return result

static func evidence_count(chronicle: Dictionary, index: int) -> int:
	if index < 0 or index >= MYSTERIES.size(): return 0
	var count := 0
	for clue in MYSTERIES[index].clues:
		if clue in chronicle.get("clues", []): count += 1
	return count

static func can_solve(chronicle: Dictionary, index: int) -> bool:
	return index >= 0 and index < MYSTERIES.size() and evidence_count(chronicle, index) == MYSTERIES[index].clues.size()

static func truth_known(chronicle: Dictionary) -> bool:
	return sanitize(chronicle).solved.size() == MYSTERIES.size()

static func dialogue(stage: String, chronicle: Dictionary, skin: int) -> Array[String]:
	var is_omega: bool = skin == 1
	var address := "Omega, Astral Reliquary" if is_omega else "Seraphina, Ember Vow"
	var short_name := "Storm-bearer" if is_omega else "Ember-bearer"
	var element_phrase := "Your arc-lightning can jumpstart the dormant copper echoes" if is_omega else "Your flame can burn away the cold ash of forgotten names"
	var pages: Array[String] = []
	match stage:
		"unmet":
			pages.append("%s... the bells rang this morning, but no one in Greywake remembered how to answer them.\n\nOur wounds close, yet we forget the faces we love. My daughter Mara no longer knows me.\n\nThe curse flows from the Hollow Spire. Its master, Nox, holds the Moonwell Elixir above eleven guarded floors. %s. Bring the elixir home before we forget why we are waiting." % [address, element_phrase])
			pages.append("Find each floor's key in its five rooms, then defeat its guardian to open the eastern stairs. The elixir waits on the open terrace above Nox.\n\nMara was our bellkeeper. Before her memory failed, she left blue-copper echoes inside the tower. Read them with T; keep them in your journal with J.\n\nThe Canticle Blade you carry was forged to sever the Moonwell's binding seals. If Mara's records tell a different story from mine... bring them home too.")
		"active":
			if 2 in chronicle.get("solved", []):
				pages.append("That is my signature. 'Until no one suffers.' I thought I was asking for mercy.\n\nNox warned me that a promise without an ending would become a prison. I heard only that Mara might live.\n\nThe well took my memory of signing it. That does not make it someone else's fault. End his vigil, %s. Bring home whatever the water has not yet burned." % short_name)
			elif 1 in chronicle.get("solved", []):
				pages.append("Living memories... so that is why she stopped calling me Father.\n\nI remember asking the well to heal Mara. After that, only missing days. If names can guide those memories home, I will speak every name in Greywake.\n\nFind the elixir above Nox. Please, %s, let there still be something of her in it." % short_name)
			elif 0 in chronicle.get("solved", []):
				pages.append("The crescent is mine. I remember opening those doors now: carrying beds, calling for blankets. No army.\n\nHow did a refuge become the siege we all remember? Keep following Mara's echoes. Someone has taken more from us than I understood.\n\nThe elixir is still our hope. Search each floor's rooms, take its key, and defeat its guardian to climb.")
			else:
				pages.append("Mara always said a bell is a promise that someone will answer. I still answer, even when she does not know my voice.\n\nSearch the blue-copper echoes in the tower's chambers, %s. Your journal records their locations and the questions they raise.\n\nA floor's key and defeated guardian open its stairs. Above all eleven, collect the elixir and bring it home." % short_name)
		"elixir":
			pages.append("The bottle is warm. For the first time in years, the bells are quiet.\n\nYou ended Nox's vigil. This water can heal our people.\n\n" + ("And you brought back the truth. I signed that order to save Mara. I will not hide behind the memories it took from me.\n\nGive me the bottle, %s. We will speak their names together." % short_name if truth_known(chronicle) else "Give me the elixir, and I will tend to every wounded villager. Whatever answers remain in the tower, no one here needs to wait for medicine."))
		"healed":
			if truth_known(chronicle):
				pages.append("Orin speaks each villager's name over the water. An old song returns to a mason. A mother remembers a blue sleeve.\n\nAt last, Mara looks up. 'Father?'\n\nOrin kneels beside her. 'I asked for a dawn without pain. I should have asked how we would face it together.'\n\nFor the first time, the silence between the bells belongs to the living.")
				pages.append("THE NAMES WE CARRY\n\nThe people are healed, and their unspent memories have found their way home. Orin has told Greywake what he did—and what the Canticle Blade freed Nox from. Mara writes the truth where no furnace can erase it.\n\nNox is remembered as the First Keeper who offered himself before any other.\n\nBeneath the Spire, a bell no one built answers once. That mystery belongs to another journey. This dawn is yours, %s." % short_name)
			else:
				pages.append("DAWN RESTORED\n\nThe mana wounds fade. Greywake will live to see another morning. Orin carries the elixir from bed to bed until every villager has been treated.\n\nMara smiles at him as kindly as she would at a stranger. Some of what the tower took is still missing.\n\nYour recovered echoes remain in the journal. The tower stays open, and the rest of the truth can still be found.")
				pages.append("The unspent water has been kept safe. Nothing you have done closes the path to the fuller ending.\n\nFind Mara's eleven echoes, resolve the journal's three mysteries, then speak to Orin again.\n\nFor now, Greywake is alive. The next road beyond the terrace has yet to open.")
	return pages
