# Campaign balance and recovery — 29 October 2026

Approved scope: tune the existing campaign, not add combat mechanics. Evidence: Standard17 loses a companion in the introductory victory and collapses on the next two missions; failed missions add up to4 threat while awarding4 Supplies, recruitment costs12, and ordinary generation immediately restores3–4 opponents.

Implementation plan:
1. Capture current Standard17 using legal training/rest decisions, its content fingerprint, and an isolated v2 save. Preserve all previous failed evidence.
2. Add RED tests for recovery after one failed/casualty mission, gradual roster sizes, duplicate-result protection, injuries/recovery, save migration and frozen offers.
3. Editable CampaignDefinition rules v2: modern campaign unit caps2/2/3/3/3 by prior victories (elite included but retain leader+support); ignored threat capped at1 per board; failure Supplies4→12. Keep recruitment12, training8, injury timing and penalties, XP, hero/enemy stats, difficulty multipliers, actions and objectives unchanged. Keep legacy specialist generation unchanged. Existing frozen mission codes are unchanged.
4. Explicitly accept the captured actual old v2 content hash plus existing shipped v1 migration; upgrade rules version transactionally. Unknown content and future formats remain rejected. No player files overwritten.
5. Show the threat cap in HQ/debrief; clarify training cost/readiness and rest recovery in existing help text. No screen redesign.
6. Run focused rules/save/objective/AI checks and fixed-seed Standard/Easy/Hard campaign simulations, including a deliberately failed first mission. Report actual endings, deaths, funds and threat. Simulation success is not human balance proof. Stop before roadmap Milestone2.
