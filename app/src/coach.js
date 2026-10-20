// Brian Tracy's ideas, as WilList applies them. Session numbers refer to the
// Phoenix Seminar transcript in briantracy.md ("S17" = session 17).

export const LETTER_HELP = {
  A: { name: 'Must do', hint: 'Serious consequences if it is not done.' },
  B: { name: 'Should do', hint: 'Mild consequences. Never start a B while an A is undone.' },
  C: { name: 'Nice to do', hint: 'No real consequences either way.' },
  D: { name: 'Delegate', hint: 'Someone or something else can do it: a teammate, the TA, a tool.' },
  E: { name: 'Eliminate', hint: 'It does not need doing at all. Let it go.' },
};

export const TIPS = {
  consequences: 'If you skip it, what happens?',
  a1: 'What is the most valuable use of my time right now?',
  bBeforeA: 'A’s first: never a B while an A is undone.',
  tooManyA: (n) => `${n} A’s. If everything is an A, nothing is.`,
  exam: 'Cramming loses most of what you learn within weeks. WilList spreads your prep into spaced sessions instead.',
  planTonight: 'Make tomorrow’s list tonight. Your subconscious works on it while you sleep.',
  planMorning: 'No plan from last night? Take two minutes now. Every minute spent planning saves 5–15 minutes doing.',
  try: '“Try” → decide: I will.',
  wish: '“Wish” → give it a date.',
  haveTo: '“Have to” → “choose to”.',
  problem: '“Problem” → “challenge”.',
  missed: 'No blame. Re-plan from today.',
  focus: 'One thing. Stay with it until it’s done.',
  start: 'You can act your way into feeling. Start moving and the motivation follows.',
  breakTime: 'Take a 5–10 minute break.',
  delegate: 'Delegation is not abdication. Inspect what you expect.',
  eliminate: 'Do first things first, and second things not at all.',
  short: 'Not enough time left at your daily budget. Start now or ask for help early.',
  sleep: 'Keep the last session before an exam light, and sleep early.',
  goalsBalance: 'Keep a few goals in every area. Personal goals are your “why”; school and career goals are the “what”.',
  goalsMany: 'Your mind can work on 10–15 goals at a time. Beyond that, pick the vital few.',
  goal5050: 'Make it believable: a goal with roughly a 50/50 chance, the next logical step from where you are.',
  confidential: 'Share goals only with people who are working toward goals of their own.',
  worry: 'About 40% of worries never happen, 30% are about the past, 12% are needless health worries and 10% are petty. Only about 4% are real problems you can act on.',
  mindstorm: 'Write 20 answers. The first few are easy; the last ones are often the breakthrough. Then act on one immediately.',
  release: 'Then let it go. In mental work, the harder you force it the worse it goes (the law of relaxation).',
};

export const DONE_LINES = [
  'Done. Next one.',
  'Done. Momentum builds.',
  'Done. Small wins add up.',
  'Done. Keep the tempo.',
  'Done. That’s discipline.',
];

export function doneLine(n) {
  return DONE_LINES[n % DONE_LINES.length];
}

export function hintFor(hints) {
  for (const h of hints || []) if (TIPS[h]) return TIPS[h];
  return null;
}

// The library under More → Principles. Grouped so it reads in a minute, not an hour.
export const PRINCIPLES = [
  {
    group: 'Take control',
    items: [
      ['The law of control', 'You feel good about yourself to the degree you feel in control of your life. Time management is control over the sequence of events.', 'Everything lives in one place: Today lays out your day, Ahead shows the next two weeks.', 'S2, S17'],
      ['Failing to plan is planning to fail', 'Most people drift by the law of accident: no plan, no goals, just reacting.', 'Today → Tomorrow: two minutes each night, then lock it in.', 'S2'],
      ['Think on paper', 'Get everything out of your head and onto a list. Don’t try to carry it in your mind.', 'Quick-add understands plain language, so capturing takes seconds.', 'S17, S20'],
      ['Make tomorrow’s list tonight', 'The best time to plan a day is the night before; your subconscious works on it while you sleep.', 'A “Plan tomorrow” prompt appears each evening.', 'S17'],
      ['Everything counts', 'Nothing is neutral. Everything either moves you toward your goals or away from them.', 'E for Eliminate: drop what doesn’t matter instead of carrying it.', 'S9, S11'],
    ],
  },
  {
    group: 'Prioritize',
    items: [
      ['ABCDE', 'A = must do, B = should do, C = nice to do, D = delegate, E = eliminate. Number your A’s (A1, A2, A3) and never work on an A2 or a B until A1 is done.', 'Every item gets a letter. B’s stay dimmed while any A is open.', 'S17'],
      ['Consider consequences', 'An A is anything with serious consequences if you don’t do it. The more serious the consequence, the higher the priority.', 'Sort asks one question: “If you don’t do it, what happens?”', 'Eat That Frog!'],
      ['Urgent vs. important', 'Urgent things are seldom important; important things are seldom urgent.', 'Your list is ordered by letter, not by due date, and start dates bring important work into Today before it turns urgent.', 'Tracy’s time-management teaching'],
      ['The 80/20 rule', 'Two items out of ten are worth more than the other eight together: the vital few versus the trivial many.', 'Your A’s are the peaks on Ahead, plus a nudge when too many things are marked A.', 'S17'],
      ['Most valuable use of time', 'Keep asking: what is the most valuable use of my time right now?', 'That question sits above your A1 every day.', 'S17'],
    ],
  },
  {
    group: 'Get it done',
    items: [
      ['Concentration of power', 'Do first things first, one at a time, and stay with each until it is complete. Single-handle: once you pick it up, don’t put it down.', 'Focus mode shows one task, a session timer and nothing else.', 'S17, S20'],
      ['Do it now', 'Procrastination is the thief of life. Repeat “do it now” and build a sense of urgency and a fast tempo.', 'Your A1 has a Start button right on it.', 'S17'],
      ['Sub-deadlines and rewards', 'Set a deadline, then many smaller deadlines, and give yourself small rewards along the way.', 'Big items are split into dated sessions, and you can name a treat for finishing today’s A’s.', 'S16'],
      ['Inspect what you expect', 'Delegation is not abdication. Follow up on what you handed off.', 'D items stay visible with who you delegated to.', 'S20'],
      ['Act your way into feeling', 'You rarely start motivated. Act as if, and the feeling follows the action.', 'Starting is one tap; the timer does the rest.', 'S10'],
    ],
  },
  {
    group: 'Study smarter',
    items: [
      ['Spaced repetition, not cramming', 'Cram-and-dump learning is lost within weeks. Spread study out, review repeatedly and define why you’re learning it.', 'Exam prep is spread over expanding gaps before the exam, ending with a light review.', 'S13'],
      ['Short sessions, real breaks', 'You remember most from the beginning and the end of a study period, so break long sessions up.', 'Sessions default to about 50 minutes, and focus mode prompts a break.', 'S13'],
      ['Teach what you learn', 'You become what you teach. Explaining material is the fastest way to own it.', 'Recall sessions say “test yourself, no notes”.', 'S11'],
      ['Read an hour a day', 'One hour a day on a subject makes you an authority in a few years.', 'Reading items get their own steady sessions and a start date.', 'S11'],
      ['Early to bed, early to rise', 'Success habits include protecting your sleep and your mornings (the “golden hour”).', 'The last exam session says to sleep early.', 'S9, S11'],
    ],
  },
  {
    group: 'Goals',
    items: [
      ['Success is goals', 'Only about 3% of people have clear written goals with plans, and they outperform everyone else.', 'The Goals tab: written goals, a deadline, your reasons why and a next step.', 'S15'],
      ['Major definite purpose', 'One goal bigger than the rest that you can name if someone wakes you at 3am. It must be measurable.', 'At the top of Goals.', 'S15'],
      ['The 12 steps', 'Desire, belief, write it down, list your reasons why, know your starting point, set a deadline, identify the obstacles (and the “rock”), the knowledge you need and the people you need, make a plan, visualize, persist.', 'Each goal has fields for the steps that matter most.', 'S16'],
      ['Balance', 'Keep personal, career and self-improvement goals in balance. Personal goals are why you do the rest.', 'Goals are grouped into those three areas.', 'S15, S17'],
      ['Fail forward', 'Failure is part of success. Edison found thousands of ways that didn’t work. Ask what you can learn.', 'Missed sessions are flagged without blame, with a one-tap re-plan.', 'S15'],
    ],
  },
  {
    group: 'Mindset',
    items: [
      ['The worry buster', 'Define the worry in writing, determine the worst possible outcome, resolve to accept it, then start improving on it. The antidote to worry is purposeful action.', 'More → Worry Buster, which turns your actions into tasks.', 'S8'],
      ['Mental rehearsal', 'Before an important one-off event: visualize the perfect outcome, affirm it, feel it, release it. Recall your past successes, not your failures.', 'More → Pre-game, for exams and presentations.', 'S12'],
      ['Mind storming', 'Write a goal as a question and force 20 answers. Act on one immediately.', 'More → 20 Ideas.', 'S20'],
      ['I am responsible', 'No blame, no excuses. Ask “what can I do from here?”, not “who did it?”.', 'Re-plan from today instead of looking back.', 'S5, S6'],
      ['Watch your words', '“I can’t”, “I have to”, “I’ll try” and “I wish” program failure. “Problem” stresses; “situation” or “challenge” invites solutions.', 'Quick-add gently flags these words.', 'S7, S20'],
    ],
  },
];
