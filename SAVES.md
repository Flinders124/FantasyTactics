# Campaign saves — Fantasy Tactics 0.12.0-rc1

Continue Campaign resumes one active slot. Campaign creation, accepted purchases/equipment/upgrades/recovery, complete mission consequences and return to headquarters autosave. Settings and tutorial completion remain separate. Save & Main Menu preserves the run; Abandon Campaign deletes the active slot after confirmation. Starting a replacement campaign requires confirmation.

## Interrupted missions
Deployment is saved before entering combat. Closing the application during combat preserves that committed mission: Continue restarts its initial deployment, with the same party, equipment, injuries, seed, resolved enemies and battlefield configuration. It does not resume tactical movement, damage, cooldowns or turns. No additional cost or reward is awarded by restarting. A deliberate confirmed mission abandonment instead applies failure consequences once.

A completed mission saves its full debrief and processed mission ID together. Reopening a debrief never awards rewards again. Completed campaigns reopen their final summary.

## Files and recovery
Windows default: `%APPDATA%\Godot\app_userdata\Fantasy Tactics\campaign\active.json`. The previous validated primary is retained as `active.json.bak`. Files use version 1 JSON with an integrity checksum; they are configuration records, not serialized nodes. They are not encrypted or tamper-proof.

Writes validate the complete candidate, write/read back a temporary file, retain the previous valid backup, then promote the new primary. Failed headquarters transactions roll back instead of spending supplies without saving. Failed result saves retain the in-memory result and show Retry Save; Finish Campaign and Save & Main Menu cannot silently discard it.

An unreadable primary is never silently replaced. When a valid backup exists the title offers explicit recovery, identifying older progress. Recovery or confirmed replacement preserves unreadable primary bytes in a timestamped archive. If neither copy is valid, the title explains the error; explicitly confirm replacement to start over. A backup can be one accepted transaction behind. Keep independent copies before changing game versions.

Only supported format, rules/content versions, stable IDs, ranges, equipment ownership and mission cross-references load. Changed or future definitions are rejected with an explanation; this first disk format has no speculative migrations. Load validation completes before replacing the current run. Restored runtime stats are calculated afresh, so equipment, injuries and difficulty never compound.

## Repeatable manual checks
1. Create a campaign, buy/equip an item, Save & Main Menu, close and relaunch. Continue and compare supplies, equipment and mission offers.
2. Deploy, note the seed/party, close during an enemy turn. Continue: the same mission starts fresh, without another charge.
3. Complete a mission, relaunch into its debrief twice: rewards and threat must remain unchanged.
4. With the game closed, back up the entire campaign directory. Truncate the primary in a disposable test profile. Relaunch, explicitly recover the backup and confirm recovery feedback. Never perform destructive tests on your only save.
5. Finish a campaign, relaunch and Continue: the final summary remains available.
