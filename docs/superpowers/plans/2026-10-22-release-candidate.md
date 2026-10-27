# Milestones 11–12 release implementation plan

Goal: durable campaign continuation, reliable complete flows and a measured, standalone Windows RC.
Architecture: CampaignSaveCodec validates plain versioned records and rebuilds CampaignState. CampaignSaveStore owns one user:// slot, verified temporary writes and previous-valid backup. Existing coordinator commits saves at stable transaction boundaries and before deployment, with transactional load and frozen encounter codes. Tactical controller remains authoritative and unchanged. Packaging/performance audits are independent tasks.
Stack: installed Godot4.7.2 Compatibility, typed GDScript, built-in JSON/filesystem, no runtime downloads.
Source spec: user milestones11–12 in this conversation. Safe boundaries, mission restart policy and one slot explicitly specified; no unresolved product choices.

- [ ] Audit complete existing flow and record missing prerequisites separately from defects.
- [ ] RED/GREEN persistence codec tests: complete roundtrip, allIDs/ownership/ranges/crossrefs, content/version mismatch, frozen active configuration, isolated independent runtime state and duplicate result rejection.
- [ ] RED/GREEN save-store tests: checksum/truncation/backup/unsupportedversion, invalidcurrentneveroverwritten, injectedwrite/renamefailures leave validoldstate, recovery requires explicitconsent, no settings effects.
- [ ] Coordinator integration: Continue+summary, overwriteconfirmation, autosavescreation/HQmutations/debrief, deployment-savegate, frozenmissionrestart; user-facing savefailure feedback; completedcampaignsummary and clean transitioncancellation. Isolate all harnessuserdata.
- [ ] Audit/tune numeric balance from concrete evidence, document exactbeforeafter, provisionalhumanbalance.
- [ ] Measure GPU frames/load/nav/AI/objectcounts beforetargetedoptimization; tenlifecyclecycles; separatecosmeticsfromrules.
- [ ] Full regression + releaseflow/persistence harnesses, allsixpairs/135preset-objective-difficultyseeds and alternateoutcomes/tutorial/settings.
- [ ] Release Windows preset/version/icon/exclusions/licences, matchingofficialtemplate, exportRC, externaldirectory smoke including actual processclose/relaunchContinue/interruptedmission and encountercompletion.
- [ ] Final report: results, exactbuildcommands, playersavepolicy, measuredperformance, rankedremainingissues and humanplaytestlimits.

Ruling: implement in current workspace (no Git repository), no branch operations. Existing settings remain a separate user config. Current session-only snapshot is not an old shipped save format; first disk schema is v1, with no speculative migrations. One Windowsstandard template for GDScript-only release avoids requiring .NET on player machines. Work is authorized by the explicit phased implementation request; no additional product choices introduced.
