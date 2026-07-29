# NOBS Product Decisions

**Status:** Approved product direction  
**Decision owner:** Alexander Burgess  
**Captured:** July 1, 2026  
**Purpose:** Durable product truth for design, engineering, research, hardware, and business decisions.

This document records the decisions made during the initial NOBS product discovery. It should guide implementation unless a later decision explicitly supersedes it.

## 1. Product Purpose

NOBS exists because mainstream technology companies too often optimize for advertising, data collection, lock-in, recurring purchases, and unnecessary hardware replacement.

NOBS takes the opposite position:

- Make the technology people already own work better.
- Keep everyday intelligence local and useful for free.
- Never sell personal data or attention.
- Recommend upgrades only when measurable workload limits make them genuinely helpful.
- Explain what an upgrade improves and offer cloud processing as an optional bridge when existing hardware needs temporary help.
- Do not intentionally degrade working features to manufacture an upgrade cycle.

The public-facing interpretation of the name is friendly and approachable. The underlying attitude is **“No BS.”**

### Brand promise

**Primary tagline:** “Your technology. Finally working for you.”

Supporting messages:

- Private intelligence for real life.
- Make what you own smarter.
- One assistant. Every device. Your rules.
- No tracking. No lock-in. No BS.

The brand should be plainspoken, warm, protective, technically credible, calm about privacy, and slightly irreverent. NOBS may openly criticize surveillance advertising and forced upgrade cycles, but its credibility must come from transparent policies and product behavior rather than empty provocation.

## 2. Primary User and Job to Be Done

NOBS should ultimately support:

- overwhelmed working adults;
- non-technical Apple users;
- neurodivergent users who benefit from structure;
- privacy-conscious users who avoid cloud-first AI.

The **primary launch persona** is an overwhelmed working adult.

The primary job is to reduce mental load. NOBS should organize planning, communication, commitments, household context, and useful research into a realistic daily plan instead of becoming another inbox.

### Launch-defining moment

The first signature experience is:

> NOBS turns a chaotic day into a realistic plan in seconds.

Later reinforcing moments include:

- resolving a forgotten commitment;
- answering consistently through Siri, Google, Alexa, or the app;
- presenting a sourced research brief prepared while the user was away;
- unifying disconnected smart-home systems;
- coordinating a stressful disruption across scheduling, communication, travel, and home context.

## 3. Product Shape and Personality

NOBS is one adaptive assistant identity. It is not a collection of modes or different personalities.

- It begins neutral, warm, concise, and trustworthy.
- It learns the user’s preferred tone over time.
- It may become warmer, wittier, more direct, or more accountability-focused based on explicit and observed preferences.
- It must not label, diagnose, or talk down to the user.
- Preferences and accessibility changes should primarily happen through conversation and recommendations rather than through a traditional settings maze.

### Interface model

Chat remains the home of NOBS. It is supported by focused contextual views rather than a permanent tab bar:

- **Today:** briefing, priorities, conflicts, and active situations;
- **Memory:** what NOBS knows, why it knows it, and how to correct or delete it;
- **Home:** rooms, devices, people, routines, and system health;
- **Activity:** suggestions, changes, automations, approvals, and reversals;
- **Privacy:** permissions, processing rules, storage, and privacy receipts.

Conversations should feel like one continuing relationship. NOBS may automatically organize content into temporary topics and persistent workspaces for projects, decisions, people, home events, research, files, tasks, and sources.

### Visual direction

The selected visual direction is the **Human Companion** concept:

- warm cream and sage identity;
- editorial assistant responses rather than conventional bubbles everywhere;
- compact user messages;
- generous spacing and calm hierarchy;
- Apple-native materials and controls;
- denser utility layouts for Home, Activity, and research;
- subtle contextual changes for morning, work, evening, device, room, and activity;
- a stable core layout so adaptation never feels unpredictable.

The approved visual reference is stored at [`design/nobs-option-3-reference.png`](../design/nobs-option-3-reference.png).

## 4. Daily Experience

The daily briefing is the product anchor. It combines planning, communication, organization, home context, and optional media.

### Morning briefing

The briefing should:

- trigger adaptively from wake patterns, calendar, Focus mode, and context;
- be available in written and spoken form;
- summarize schedule, messages, tasks, weather, commute, household status, and permitted wellbeing signals;
- prioritize the day instead of simply listing it;
- identify conflicts and unrealistic workload;
- ask one useful question when information is ambiguous;
- offer concrete, reversible fixes;
- optionally start or continue music or podcasts.

### Evening wrap-up

The wrap-up should:

- summarize accomplishments, unfinished commitments, and changes;
- prepare tomorrow without creating guilt;
- capture approved memories and lessons;
- surface what Tank learned while the user was away;
- help the household transition into evening routines.

### Overloaded-day behavior

When a day is overloaded, NOBS should escalate progressively:

1. Explain the conflict or capacity problem.
2. Propose a realistic revised schedule.
3. Offer one-tap, reversible changes.
4. Adjust trusted low-priority blocks or household routines.
5. Draft communication for affected people.
6. Send only messages that are covered by an explicitly trusted automation.

## 5. Proactivity and Automation

NOBS should be useful without becoming noisy.

- Users choose **quiet**, **balanced**, or **proactive** behavior.
- Morning briefing and evening wrap-up form the normal rhythm.
- Context-aware check-ins may cover urgent conflicts, forgotten commitments, active workflows, safety, or meaningful opportunities.
- Strict interruption limits apply.
- Standard updates arrive as notifications that open the relevant conversation.
- Live Activities track unfolding workflows.
- Widgets provide passive daily context.

### Trust progression

NOBS begins with confirmation-first behavior. It may learn which repeated actions the user trusts and offer automation.

Eventually trusted actions may include:

- creating reminders and tasks;
- rescheduling low-priority calendar blocks;
- drafting messages and emails;
- running approved Shortcuts and Focus routines;
- sending specifically approved routine messages;
- executing low-risk home routines.

Every automation must be visible, individually revocable, auditable, reversible where possible, and easy to stop through chat.

Purchases, subscriptions, sensitive-data sharing, permanent deletion, and high-risk security actions must not become silent automations.

## 6. Onboarding and Adaptation

Onboarding is a short conversation rather than a checklist of permissions.

It should learn:

- name, tone, and working hours;
- primary sources of mental load;
- morning and evening routines;
- important calendars and communication services;
- home platforms and devices;
- privacy comfort and processing restrictions;
- one immediate real problem NOBS can solve.

Permissions should be requested progressively at the moment their value is clear.

### Recommended changes

When NOBS recommends a preference or accessibility change, it should:

- explain what it noticed without making assumptions;
- show the exact proposed change and benefit;
- offer approve once, always approve, or decline;
- make the result reversible through chat;
- remember the preference without labeling the user;
- check later whether the change actually helped.

The interface may adapt spacing, typography, contrast, density, response length, reading level, speaking speed, modality, interruption frequency, suggestions, and context controls while preserving a predictable core structure.

## 7. Apple and Personal Context

NOBS should eventually integrate broadly across the Apple ecosystem, but permissions must be progressive.

Candidate data and services include:

- Calendar and Reminders;
- Focus modes and Shortcuts;
- Contacts, Notes, files, and location;
- permitted messages and email;
- Health information;
- media services;
- Home and device context.

Passwords and financial accounts are categorically off-limits.

Messages, photos, files, health information, and other sensitive categories require clear, contextual permission.

### Health data

NOBS may:

- display user-requested summaries;
- adapt plans using permitted sleep, activity, medication, or stress-related signals;
- suggest lighter schedules or breaks;
- identify concerning patterns and recommend appropriate human help.

NOBS must not make unsupported medical claims. Health data should not leave the device or Tank without explicit approval for the specific use.

## 8. Communication

NOBS should turn communication into an organized workflow:

- summarize unread and important messages;
- identify unanswered questions, promises, deadlines, and commitments;
- draft replies in the user’s learned tone;
- send only approved routine replies automatically;
- create tasks and calendar events from commitments;
- batch non-urgent communication during quiet time.

## 9. Memory and Personalization

Ordinary chat history may expire. Useful long-term facts require explicit approval.

- NOBS may observe temporary on-device patterns for short-lived suggestions.
- Lasting learning must be explainable, correctable, pausable, and approved.
- Users can say “Remember that…” conversationally.
- NOBS may propose a memory and explain why it would help.
- A visible Memory view shows what NOBS knows and why.
- Users can edit, delete, pause, or export memory.

“Learning” normally means updating retrieval, preferences, knowledge, and approved memory. It does not mean silently training an underlying model on private user data.

## 10. Processing and Availability

NOBS should choose among:

- on-device iPhone processing;
- Tank processing on the local network;
- optional NOBScloud processing.

The router should consider sensitivity, capability, latency, availability, cost, and user policy. Specialized models may serve planning, research, vision, home control, or other tasks. Advanced users may override model selection.

Every response should show a subtle **Local**, **Tank**, or **NOBScloud** status. Details should include a privacy receipt explaining what data was used and where it was processed.

Users may restrict categories to device-only or Tank-only processing.

### Tank unavailable

When Tank is unavailable, users may choose:

- reduced local capability;
- optional NOBScloud fallback;
- queueing heavy work until Tank returns.

NOBS should remember the preference.

### Offline operation

Without internet access, NOBS should preserve:

- local chat, planning, reminders, and permitted home control;
- local-network Tank operation;
- safe queueing of cloud work;
- clear distinctions between unavailable data and failed actions;
- an emergency mode with essential contacts, routines, and household controls.

## 11. Unified Smart Home

NOBS should make fragmented smart-home ecosystems feel like one system.

The user should be able to speak through Siri, a Google Hub, Alexa, the NOBS app, or another approved endpoint and experience:

- the same NOBS identity and personality;
- consistent device names, rooms, routines, and permissions;
- the same meaning for household intentions such as “good night”;
- shared context without leaking private personal information.

Tank acts as the central private intent router. Initial implementation should use Home Assistant-style bridging, Apple Home/HomeKit, Siri/App Intents, and conversational routine creation. Full Google Home and Amazon/Alexa unification is planned and must be labeled honestly as coming soon until it is reliable.

### Smart-home capabilities

NOBS should eventually support:

- conversational control;
- cross-platform natural-language routines;
- pattern-based automation suggestions;
- offline-device, door, temperature, security, and maintenance alerts;
- intent-based scenes such as quiet morning, movie night, focus time, leaving, or bedtime;
- consistent control across rooms and platforms.

### “Make my home one” setup

The guided setup should:

- discover network devices;
- connect Apple, Google, Amazon, and supported vendor accounts;
- reconcile duplicate devices, rooms, and conflicting names;
- test devices and build a visual home map;
- suggest useful routines;
- offer an advanced Home Assistant-oriented mode.

### Household identity

NOBS should support:

- private individual profiles and permissions;
- shared household memory separate from personal memory;
- presence-aware routines without exposing private context;
- guest, child, emergency, and trusted-administrator roles;
- a shared household conversation for plans and chores.

### Cross-device continuity

Conversations, timers, media, briefings, and workflows may follow the user between rooms and devices. NOBS should:

- select the best nearby speaker or display;
- ask before transferring private content;
- suppress or simplify sensitive details when other people are present;
- preserve context across handoffs.

Existing platform wake phrases should be used initially. “Hey NOBS,” custom assistant names, and custom wake phrases are longer-term personalization goals where hardware and platform rules permit them.

## 12. Music and Podcasts

NOBS should support Apple Music, Spotify, Apple Podcasts, and compatible third-party services.

- Learn audio preferences for working, commuting, relaxing, and household routines.
- Pause for important updates and resume seamlessly.
- Continue playback across phone, car, headphones, and home speakers.
- Offer optional radio-style briefings that mix NOBS updates with selected audio.

## 13. Tank Research Library

Tank should continue useful work while the user is away. It may research approved interests, upcoming decisions, meetings, projects, purchases, travel, goals, household maintenance, device updates, energy use, and security advisories.

Tank may discover relevant new angles, but expansion into a new sensitive topic requires permission. Research has a visible policy, activity log, resource budget, and pause switch.

### Research behavior

- Work opportunistically while Tank is idle.
- Respect user-set CPU, GPU, power, storage, and bandwidth budgets.
- Increase effort around important deadlines.
- Yield immediately to gaming or other foreground workloads.
- Compare evidence and preserve disagreements.
- Deduplicate and compact findings without destroying provenance.

### Library structure

The Research Library should provide:

- topic pages with summaries, sources, confidence, and update dates;
- timelines showing how understanding changed;
- decision briefs comparing options and recommending next steps;
- links among people, projects, goals, home systems, and evidence;
- a “What NOBS learned while you were away” digest;
- conversational search with precise citations.

### Source policy

NOBS should prioritize:

1. primary evidence such as official documentation, papers, filings, and direct data;
2. reputable journalism and expert analysis for context;
3. community discussions clearly labeled as anecdotal;
4. video and podcast transcripts with timestamps;
5. permitted user documents, email, notes, and project files.

Each source should carry quality metadata. Conflicting claims must remain visible rather than being blended into false certainty.

## 14. Custom Integrations and Skills

Tank may research unsupported devices, APIs, protocols, and open-source projects, then create a custom NOBS integration or skill.

The creation pipeline should:

1. research the target and existing implementations;
2. generate code, tests, and documentation;
3. run in an isolated sandbox using fake or read-only access first;
4. explain required permissions and network destinations;
5. scan against the NOBS Skill Policy;
6. request approval based on risk;
7. install, monitor, and roll back failures;
8. optionally share a privacy-safe package with the community.

Trusted low-risk integrations may install automatically under explicit user policy.

### Risk classification

- **Low:** read-only local data and status checks; may auto-install.
- **Medium:** lights, media, climate, and routine control; first-time approval required.
- **High:** locks, doors, alarms, cameras, purchases, or external communication; approval always required.
- **Critical:** admin access, secrets, or internet exposure; technical review required.

Advanced users may tighten boundaries. Critical protections cannot be silently weakened.

### NOBS Skill Policy

Every public, private, paid, generated, or updated skill must be scanned.

The scanner should inspect:

- source code and dependencies;
- declared and actual permissions;
- network destinations;
- secret handling;
- data collection and retention;
- prompt-injection exposure;
- unexpected or unsafe behavior;
- build reproducibility and package signatures.

Failed or unverifiable skills remain quarantined. NOBS may explain violations, attempt a safe rewrite, rescan, or offer a permission-reduced sandbox. Experts may inspect the complete report and source, but critical violations cannot be overridden.

The policy combines hard NOBS rules, user preferences, household rules, future organization policies, and Tank-generated recommendations based on current security research. Hard NOBS safety rules take precedence.

### Updates

Tank should monitor upstream APIs, dependencies, and firmware; repair and retest breakage in a sandbox; provide plain-language changes and permission diffs; auto-deploy safe fixes; require approval for expanded permissions; and preserve known-good rollback versions.

### Community library

The optional community library may include:

- reviewed public skills;
- private household sharing;
- signed packages and reproducible builds;
- community ratings plus automated security analysis;
- paid skills with clear pricing and refunds;
- local adaptation without uploading private data.

## 15. Privacy, Feedback, and Data Use

NOBS does not collect personal data by default, sell personal data, sell attention, or use private data for advertising.

Feedback is optional:

- Users choose never, failures only, or occasional prompts.
- Tank may summarize recurring problems locally without sending anything.
- Users preview the complete feedback package before submission.
- Private context should be removed locally.
- Anonymous submission is supported.
- Conversations, diagnostics, and attachments are separate consent choices.

## 16. Security

Tank and future NOBSbox systems should use:

- encrypted local databases and encrypted backups;
- service isolation and least privilege;
- hardware-backed identity where available;
- mutual device authentication;
- private-tunnel remote access with no exposed home ports;
- signed or tamper-evident audit logs;
- an emergency lock switch that disables remote access and automations.

## 17. Storage, Backup, and Portability

iCloud is the friendly default for encrypted backup and Apple-device continuity. Users may instead choose local-only storage, Tank, or another cloud provider.

Storage policies may differ for chat, memory, research, files, home data, and backups. NOBS should offer simple presets, a visual data map, and per-topic or per-file overrides.

NOBS should use available approved storage intelligently while respecting privacy and performance.

### Storage stewardship

When space runs low, NOBS may:

- remove disposable caches;
- compact old conversations and research while preserving provenance;
- deduplicate data;
- move cold data to an approved location with more capacity;
- recommend large originals for user-approved removal;
- use a recoverable archive and retention period;
- operate under an advanced automatic-storage policy.

NOBS should not permanently delete user originals silently.

### Failure and migration

If Tank fails or is replaced, NOBS should:

- restore from an encrypted backup;
- retain essential preferences and permissions on iPhone;
- rebuild indexes from original sources without losing citations;
- fail over to iPhone or optional NOBScloud;
- guide migration to replacement hardware.

### Data portability

“Take my NOBS with me” should export:

- conversations and memories;
- the Research Library with citations and metadata;
- automations and home mappings;
- preferences and permissions;
- a complete encrypted Tank restore package.

Use open formats such as Markdown, JSON, and standard calendar/task formats where practical.

## 18. Identity

Sign in with Apple is the default for purchases and encrypted sync. NOBS should also support:

- local guest mode without an account;
- separate household profiles tied to individual identities;
- carefully limited recovery contacts or household administrators;
- advanced self-hosted identity for local-only users.

## 19. Honest Capability Boundaries

NOBS must never pretend an unfinished or unsupported feature works.

When a requested capability is not available, NOBS should:

- say that it is coming soon or currently unsupported;
- explain whether the cause is implementation status, device support, permissions, or plan;
- offer the closest safe alternative available now;
- capture the intended use as optional product feedback;
- offer a feature-specific notification;
- let Tank research or draft a custom skill when appropriate;
- avoid promising a date unless one is genuinely scheduled.

Example:

> “That’s coming soon. I can help with this part today…”

## 20. Accessibility

Accessibility is part of the adaptive NOBS identity, not a separate product mode.

NOBS should support:

- VoiceOver, Dynamic Type, contrast, reduced motion, and motor accessibility;
- plain language and reduced cognitive load;
- adjustable response length, reading level, and speaking speed;
- voice-first operation;
- non-color state indicators;
- preferences synchronized across the user’s devices.

Changes should be offered conversationally and respectfully.

## 21. Business Model

NOBS makes money from optional capability, hardware, and services—not personal data.

Potential revenue includes:

- NOBScloud subscription;
- one-time advanced local/Tank features;
- hosted Tank service for users without suitable hardware;
- revenue share from paid community skills;
- family plans;
- future business plans;
- NOBSbox hardware.

### Always free

The following should remain free:

- local private chat;
- basic daily briefing;
- calendar, reminders, and Focus integration;
- memory review, correction, deletion, and export;
- privacy controls;
- basic local smart-home control;
- use of user-owned Tank hardware;
- safety updates and skill scanning.

### NOBScloud

Paid NOBScloud may provide:

- stronger or faster models;
- secure processing when Tank is unavailable;
- research and document workflows;
- higher automation limits;
- cross-device continuity;
- optional cloud bursting for workloads beyond local hardware.

### Go-to-market sequencing

Operational sequencing for taking money and distributing the app—without weakening the free core—is recorded in [`MONETIZATION_AND_GROWTH.md`](MONETIZATION_AND_GROWTH.md). When that plan and this section disagree on principles, this section wins; when they disagree only on order of execution, follow the growth plan until the decision owner supersedes it.

## 22. NOBSbox Hardware Direction

NOBSbox is a future plug-in home appliance for local NOBS.

It should prioritize:

- plug-in simplicity;
- quiet, efficient, always-on operation;
- local AI acceleration;
- upgradeable storage where practical;
- Thread, Matter, Zigbee, Bluetooth, Wi-Fi, and relevant home radios;
- encrypted local backup;
- household media support;
- multiple performance tiers.

### Hardware philosophy

NOBSbox should use its hardware to the best of its ability for as long as the workload remains feasible.

Upgrade recommendations must:

- show measurable constraints such as latency, memory, storage, and unsupported capabilities;
- suggest software optimization or storage expansion first;
- compare replacement cost with occasional cloud-processing cost;
- recommend the smallest tier that solves the actual workload;
- never degrade working features to push an upgrade;
- continue security support after major feature support ends where feasible.

If the user does not upgrade, NOBS may optionally route unusually heavy work online while keeping core local NOBS free and functional.

## 23. First Usable Release

The first usable release should include:

- conversational onboarding;
- adaptive morning briefing and evening wrap-up;
- calendar, reminders, Focus mode, and basic location context;
- day-conflict detection and suggested fixes;
- local/Tank/cloud routing indicators;
- privacy rules and receipts;
- functional chat;
- memory approval and review;
- activity history;
- initial Home Assistant/Tank bridge;
- Apple Home/HomeKit and Siri/App Intents;
- conversational home-routine creation;
- initial overnight Tank research and Research Library;
- honest coming-soon responses for unsupported Google/Amazon unification and other planned features.

### Explicit near-term sequencing

1. Build the iPhone conversational core and daily-planning loop.
2. Establish secure iPhone-to-Tank communication and processing visibility.
3. Ship TestFlight / App Store distribution and open support payments (tips, early NOBScloud) per [`MONETIZATION_AND_GROWTH.md`](MONETIZATION_AND_GROWTH.md).
4. Implement memory approval, activity history, and privacy receipts.
5. Add initial Tank research with cited library entries.
6. Deliver the first real paid wedge (NOBScloud burst and/or hosted Tank) before broadening SKUs.
7. Add Home Assistant and Apple Home/Siri integration.
8. Expand cross-platform household endpoints only after reliable testing.

## 24. Decision Rules for Future Work

When future product choices are unclear, prefer the option that:

1. reduces the user’s mental load;
2. preserves local operation and privacy;
3. makes existing hardware more useful;
4. is honest about limitations and cost;
5. keeps the user in control without forcing configuration work;
6. is reversible, explainable, and auditable;
7. works for regular people before optimizing for enthusiasts;
8. avoids unnecessary replacement, cloud dependence, or lock-in.

