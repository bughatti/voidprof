# VoidProf Changelog

## 1.3.1 — 2026-11-12

- **The VoidProf window and the vendor recipes window can be dragged** and stay where you put them, even after a restart.
- **Void hub button:** left-click opens one panel with all your Void addons by name, grouped, each with its own on/off switches (it replaces the ring of icons), with a background slider. The hub's info window now stays where you put it.

## 1.3.0

### WoW Forever
- **Leveling plans with Forever's own recipes** (from its game data) for Alchemy, Blacksmithing, Cooking, Enchanting, Engineering, First Aid, Leatherworking and Tailoring, replacing Midnight's recipes there.
- **Stops at your rank cap** (75 / 150 / 225) and says what raises it; at the cap it says so instead of "nothing left to level".
- **Recipe books vs trainers:** recipes taught by a book (Manual: Strong Anti-Venom) say so; trainer recipes count as easy to get when picking the cheapest path.
- **Selling what you make counts:** what your crafts bring back (vendor, or the Auction House after its cut for up to 20 of each) lowers the cost, and the summary says what it costs all told.
- **Vendor-sold materials** are priced at the nearest vendor that sells them (with VoidGPS).
- **Numbered steps, in order,** at the top of each profession's plan.

## 1.2.6

- **WoW Forever: zone tips.** Entering a zone, one chat line tells you whether it's your territory or contested (on a PvP realm), whether fish get away there at your Fishing skill, which herbs and ore there still give you skill, and what the beasts there are worth for Skinning. Once per zone per session; switch it off in the Void hub's quick box (Prof: Zone tips).
- **Fish where it's safe:** the Fishing plan now lists, for your skill, the zones where nothing gets away in your own territory first, then the contested ones. Every catch gives skill at the same rate wherever nothing gets away, so your own territory levels you just as fast. Zone names are colored: white your territory, orange contested, red enemy.
- **What is this item for? (WoW Forever)** Hover a fish, meat, herb, ore, cloth or any other reagent: the tooltip names YOUR recipes that use it while they still give you skill (colored orange, yellow, green), and a recipe you can buy now or within 25 skill ("learn at 225: Spotted Yellowtail, Gikkix (Tanaris)"). Only your professions, at most 3 lines, and nothing at all when nothing fits. Every Forever recipe and reagent comes from Blizzard's own game data.
- **Herb and ore tooltips** say whether they still give you skill (always, usually, sometimes) or what skill you need first. Nodes that no longer give you skill get no line.

## 1.2.5

- **Fixed: Cast Cooking Fire did nothing on WoW Forever.** Forever's campfire is an item, the Campfire Kit, not a spell. The button now uses your best kit (Expert, Journeyman or Basic), and you click the ground to place it, the same as right-clicking the kit in your bags. With no kit in your bags it says so. On retail it still casts Basic Campfire.
- **Fixed: box borders missing a side** at some screen positions; borders are now exactly one screen pixel.

## 1.2.4 — 2026-11-08

- **A recipe you already have is no longer one to go buy.** If it's in your bags or bank, the zone popup leaves it out, and the vendor list marks it "in your bags".
- **Recipes with a level requirement** (WoW Forever: Recipe: Sagefish Delight needs level 30) show "level 30" in the list and don't pop up until you can learn them.
- The popup updates as soon as you buy one.

## 1.2.3 — 2026-11-08

- **Fixed: recipes you already know showing up as ones to buy.** Some recipe items are named differently from the recipe they teach ("Recipe: Mithril Head Trout" teaches Mithril Headed Trout), so the zone popup and the vendor list kept sending you to buy them. VoidProf now also asks the game, the same "Already known" check that turns a recipe red at a vendor.

## 1.2.2 — 2026-11-07

- **Merchant's Favor recipes get their own section** under the vendor recipes in each crafting tab, with what they cost (Favor and reputation) next to your own Favor and Azeroth Commerce Authority standing, in red when you're short. The main list and the zone popup are recipes you buy with gold. (Needs VoidGPS 0.3.2.)
- **A recipe you learn drops off right away**, from the zone popup and the open list, without opening the profession window first.

## 1.2.1 — 2026-11-07

- Remembers which item each of your recipes makes (when you open the profession window), so VoidAH's Crafting deals can tell you what's worth making and selling.

## 1.2.0 — 2026-11-07

- **WoW Forever: recipes from vendors you don't know yet.** Every crafting tab (Cooking, First Aid, Tailoring, Alchemy...) lists the vendor recipes for that profession you can learn now, then the ones within 25 skill ("at 60"), with the nearest vendor, limited stock and price. Click one for the way there.
- **A popup when you're near one:** enter a zone where a vendor sells a recipe you can learn and don't know, and a small window says who and what, with **Show the way**. Once per zone per session, never in combat; "Don't show these" or the **Popups** button in a crafting tab turns it off and on.
- Needs VoidGPS for the vendor lists. Open each profession window once so VoidProf knows which recipes you already have.

## 1.1.0 — 2026-11-07

- **WoW Forever: a leveling plan for Herbalism, Mining and Fishing.** Under "Next skill cap" each of these tabs now lists every step from 1 to 300: the skill range, what to pick or mine in it (colored for your skill: orange always gives skill, yellow usually, green sometimes, grey never, and "at 85" for what you can't gather yet), the bars to smelt for Mining, and **where**: the zones with the most spots, your continent first. Your step is highlighted.
- **Nearest spot:** one click starts a route to the closest place a herb or ore that gives you skill can spawn (needs VoidGPS, which holds the spots).
- **Fishing:** every catch can give skill wherever you fish, so each step lists the zones where no fish get away at that skill.
- **Your crafts, colored for skill**, so you can see whether Forever's crafts (Incense Candle, Lodestone, Fish Bowl...) still give skill.

## 1.0.3 — 2026-11-07

- **Works on WoW Forever.** It showed as incompatible there.
- **WoW Forever: past the skill cap.** Each profession tab says what lifts its cap. For Cooking, Fishing and First Aid that's a book at 150 (Expert Cookbook from Wulan in Shadowprey Village, Desolace, or Shandrina in Ashenvale; Expert Fishing from Old Man Heming in Booty Bay; Expert First Aid in Dustwallow Marsh or Arathi Highlands) and a quest at 225. It says whether you can do it yet, notices the book in your bags, and **Show the way** sets a waypoint. You also get one chat line when a profession hits its cap.

## 1.0.2 — 2026-11-05

- **Tabs fit the window.** With five professions plus Cache, the last tab ran past the window's right edge; the tabs now share the width.
- **Long lines no longer overlap.** A long knowledge line (like "need Renown 0/6 with the faction...") wraps to a second line instead of running over the line below it.
- The list stops above the version note at the bottom instead of running under it.

## 1.0.1 — 2026-11-04

- **Knowledge for every profession.** Alchemy, Blacksmithing, Enchanting, Engineering, Inscription, Jewelcrafting, Leatherworking, Tailoring and Skinning now get a **Next:** line that says where to put your knowledge points, following your ranks, plus their 8 knowledge treasures (click one for a waypoint) and the monthly Darkmoon Faire quest. Before, only Herbalism and Mining had this.
- **The leveling plan follows your crafting.** With VoidProf open, the plan is worked out again a second after you craft, use materials or gain skill, instead of when you next open it.
- **Treasures you've looted are learned as you play.** Where VoidProf doesn't know a treasure's hidden tracking yet it shows "?"; the first time any of your characters loots it, VoidProf remembers it for all of them.

## 1.0.0 — 2026-11-03

First public release.

- **Leveling from what you have.** Each crafting profession's tab shows what you can craft for skill right now from what your characters hold, the cheapest path to 100, what to mill and craft first, what to take from which character, and what's still to buy. This planner used to live in VoidAH; VoidAH's Professions tab now shows VoidProf's plan as a shopping list with Buy buttons.
- **Inks from your herbs.** For Inscription the plan mills herbs into pigments and crafts inks when that's cheaper than buying, in whole mills of 10 herbs. Milling yields are learned from your own milling.
- **Your other characters' materials** count with VoidGather installed.
- **Your spare gear counts too.** With VoidGear, the dust, shards and crystals that disenchanting your spare gear should give (what its Spares tab marks "disenchant") count as yours, so the Enchanting plan stops buying what your old gear holds. "Craft now" leaves them out until you've disenchanted.
- **Each character keeps its own recipes and skill.** Two characters with the same profession no longer overwrite each other's; open each profession window once per character.
- **Knowledge paths show the same numbers as the game** (the unlock point no longer counts: 0/30, not 0/31), so "what to spend next" moves on at the right time.
- **Vendor book requirements** check this expansion's skill, not another expansion's.
- **In combat** the panel waits (the Cooking tab's fire button is a protected button), and "Cancel" stops the fillet queue without trying to stop your current cast, which addons can't do.

## 0.2.0

- Knowledge advisor: what to spend points on next, the weekly / monthly / one-time knowledge checklist with waypoints, recipe sync, Cooking helpers.
