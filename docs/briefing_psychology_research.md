# Briefing Psychology — Research Report

Research base used to upgrade Arcane's daily / morning / weekly briefing prompts and to design the
new monthly briefing. Compiled 2026-07-11 from web research. Each finding lists the design decision
it drives.

## 1. Gratitude: quality, causes, and people beat raw quantity

- The seminal "counting blessings" studies (Emmons & McCullough, 2003) used **3–5 items**, not 10.
  Later meta-analyses (Davis et al. 2016; PNAS 2025 cross-cultural meta-analysis) confirm gratitude
  lists work, with modest effect sizes; long undifferentiated lists invite hedonic adaptation and
  "gratitude fatigue".
- Seligman's classic *Three Good Things* protocol adds a causal step: for each good thing, write
  **why it happened**. The attribution step (noticing one's own or others' agency) is considered a
  key active ingredient.
- Gratitude directed **at specific people**, and especially gratitude that gets **expressed** to
  them (Regan, Walsh & Lyubomirsky 2023; Affective Science 2022), outperforms private generic
  gratitude on well-being and relationship outcomes.

**Design →** Daily briefing: `grateful_today` drops from "exactly 10" to **5–8 items, each with a
one-clause cause** ("because…"), varied across life domains. `grateful_people` gets an `express`
field: a concrete one-line way to tell that person, and is explicitly **uncapped (list everyone who
earned it, typically 1–8)** — no 3-person ceiling.

## 2. Savoring & capitalization

- Savoring (Bryant & Veroff): deliberately re-living a positive moment in sensory detail amplifies
  and extends its affective benefit; anticipatory savoring (looking forward) works in the morning.
- Capitalization (Gable et al. 2004; Peters et al. 2018 review): **sharing good news** with a
  responsive person increases positive affect *beyond the event itself* and strengthens the
  relationship.

**Design →** Daily briefing adds `savor_moment` (the day's single best moment, re-lived in 2–3
sensory sentences). Morning briefing adds `anticipate` (one concrete thing to look forward to
today). Weekly report adds `share_win` (one win + one named person to tell).

## 3. Self-distancing

- Kross & Ayduk: analysing hard events from a **third-person / observer perspective** ("what would
  you tell a friend?") yields insight without re-triggering rumination — a complement to the CBT
  reframe already in the prompts.

**Design →** Daily briefing framework list adds self-distancing; when the day contains a hard
event, the summary's reframe should be phrased from the distanced perspective.

## 4. Progress principle & small wins

- Amabile & Kramer (*The Progress Principle*): the single strongest driver of "inner work life" is
  **visible progress in meaningful work**, even tiny. Reviews that surface small wins boost
  motivation the next day.

**Design →** Daily briefing adds `small_win` (the most meaningful concrete progress today, however
small, and what it unlocks).

## 5. Implementation intentions & WOOP (already partially used — extended)

- Gollwitzer: "When [cue], I will [action]" roughly doubles follow-through (meta-analytic d ≈ .65).
- Oettingen's mental contrasting + if-then plans (MCII/WOOP): g ≈ 0.34 over controls across 24
  trials; positive fantasy alone *reduces* follow-through.

**Design →** Daily briefing adds `tomorrow_intention` (one if-then bridging today's insight into
tomorrow). Morning briefing upgrades the loose obstacle mention into a structured `obstacle_plan`
{obstacle, if_then}. Monthly briefing plans next month as explicit WOOP entries.

## 6. The "Highlight" / MIT

- Attention research popularised as the *Highlight* (Knapp & Zeratsky, "Make Time") and MIT ("most
  important task") practice: naming **one** priority for the day reliably improves completion and
  reduces choice overload.

**Design →** Morning briefing adds `highlight`: the single most leveraged task today and why, in
one sentence.

## 7. After-action reviews (AAR)

- Keiser & Payne 2022 meta-analysis (61 studies): AARs/debriefs improve performance **d ≈ 0.79**;
  Tannenbaum & Cerasoli 2013: ≈ 25% improvement (d ≈ 0.67). Structure: what was intended → what
  happened → why the gap → what to adjust.

**Design →** Weekly report adds a light `after_action` block (intended / actual / lesson). The
monthly briefing makes AAR a core section with gap analysis per major intention.

## 8. Fresh start effect & temporal landmarks

- Dai, Milkman & Riis (2014): aspirational behaviour spikes after temporal landmarks (new week
  +33% gym attendance, new semester +47%; new month is a documented landmark). Landmarks "close the
  books" on the past period and widen the big-picture view.

**Design →** The monthly briefing is *timed to exploit this*: it closes the month's account
honestly (AAR, emotional climate), then channels the fresh-start motivation into 1–3 WOOP goals.

## 9. Best Possible Self

- Meta-analysis (Carrillo et al. 2019, PLoS ONE): BPS imagery improves well-being (d ≈ .33) and
  optimism (d ≈ .33), one of the most replicated positive-psychology interventions.

**Design →** Monthly briefing adds `best_possible_self`: a short, vivid, plausible portrait of the
user one month out **if the top 2–3 changes stick** — grounded in this month's actual evidence, not
fantasy (per §5, always paired with obstacles via the WOOP block).

## 10. Narrative identity & expressive writing

- Pennebaker: organising experience into a **coherent narrative** drives the benefits of expressive
  writing (meaning-making, reduced rumination). McAdams: people understand their lives as evolving
  stories; "redemption sequences" correlate with well-being — but forced positivity backfires, so
  narratives must stay honest.

**Design →** Monthly briefing opens with `narrative`: the month told as an honest story with a
beginning, turning points, and an arc — not a list.

## 11. Energy audit / burnout signal

- Weekly-review practice literature (and JD-R burnout research) supports periodically naming
  **energizers vs drainers** to catch chronic depletion early and redesign the environment
  (connects to the Atomic Habits friction section already present).

**Design →** Weekly report adds `energy_map` {energizers[], drainers[]} drawn from logged evidence.

## 12. Emotional granularity across time (zoom-out)

- Barrett's emotional granularity work (already used daily) extends to trends: naming *patterns* of
  emotion across weeks ("resentment clusters around Sunday planning") converts mood noise into
  actionable signal. Monthly cadence is where trends become visible that daily views miss.

**Design →** Monthly briefing adds `emotional_climate` (dominant emotions, trajectory, 2–3
recurring patterns with evidence) and `wellbeing_deltas` computed against the previous month.

## Sources

- [Positive expressive writing interventions — systematic review (PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC12094736/)
- [Chasing elusive expressive writing effects (PMC)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10300201/)
- [Meta-analysis: gratitude interventions across cultures (PNAS)](https://www.pnas.org/doi/10.1073/pnas.2425193122)
- [Davis et al., "Thankful for the Little Things: A Meta-Analysis of Gratitude Interventions" (PDF)](https://scottbarrykaufman.com/wp-content/uploads/2021/05/davis2016.pdf)
- [Regan, Walsh & Lyubomirsky 2023 — Are some ways of expressing gratitude more beneficial? (PDF)](https://sonjalyubomirsky.com/wp-content/uploads/2024/03/Regan-Walsh-Lyubomirsky-2023.pdf)
- [Optimal way to give thanks (Affective Science / PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC9551243/)
- [Seven gratitude interventions compared (J. Positive Psychology)](https://www.tandfonline.com/doi/full/10.1080/17439760.2025.2502483)
- [Gable et al. 2004 — What do you do when things go right? (PDF)](https://scottbarrykaufman.com/wp-content/uploads/2015/02/Gable-Reis-Impett-and-Asher-2004.pdf)
- [Peters et al. 2018 — Interpersonal capitalization review](https://compass.onlinelibrary.wiley.com/doi/10.1111/spc3.12407)
- [Crafting Well-Being: savoring, reflecting, capitalizing (Annual Reviews)](https://www.annualreviews.org/content/journals/10.1146/annurev-orgpsych-110721-045931)
- [Kross & Ayduk — reflection without rumination (overview)](http://psych-your-mind.blogspot.com/2011/07/reflection-without-rumination.html)
- [Keiser & Payne — Meta-analysis of after-action review effectiveness](https://www.ovid.com/journals/japsy/pdf/10.1037/apl0000821~a-meta-analysis-of-the-effectiveness-of-the-after-action)
- [Tannenbaum & Cerasoli 2013 — Do debriefs enhance performance? Meta-analysis](https://pubmed.ncbi.nlm.nih.gov/23516804/)
- [Dai, Milkman & Riis 2014 — The Fresh Start Effect (Management Science)](https://pubsonline.informs.org/doi/10.1287/mnsc.2014.1901)
- [Fresh start effect (PDF, Wharton)](https://faculty.wharton.upenn.edu/wp-content/uploads/2014/06/Dai_Fresh_Start_2014_Mgmt_Sci.pdf)
- [Carrillo et al. 2019 — Best Possible Self meta-analysis (PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC6756746/)
- [Meevissen et al. — BPS two-week intervention](https://www.sciencedirect.com/science/article/abs/pii/S0005791611000358)
- [WOOP / mental contrasting overview (HPRC)](https://www.hprc-online.org/mental-fitness/performance-psychology/woop-4-simple-steps-help-you-achieve-your-goals)
