// A believable student week, dated relative to today, for trying WilList out.

import { addDays, weekday } from './dates.js';
import { makeItem, uid } from './store.js';

export function sampleData(today, settings) {
  const d = (n) => addDays(today, n);
  const goalGpa = { id: uid(), title: 'I earn an A in Calculus', area: 'academic', horizon: '90d', deadline: d(55), why: 'It keeps my scholarship.\nI want the engineering track.', rock: 'I fall behind on problem sets and cram.', knowledge: 'Related rates and optimization', people: 'Prof. Lee, TA office hours, study group', reward: 'Weekend trip', createdAt: today };
  const goalFamily = { id: uid(), title: 'I call my family every Sunday', area: 'personal', horizon: '90d', deadline: d(60), why: 'They are the reason I’m here.', rock: 'Sunday evenings fill up with homework.', knowledge: '', people: '', reward: '', createdAt: today };
  const goalSleep = { id: uid(), title: 'I’m in bed by 11:30 on school nights', area: 'self', horizon: '90d', deadline: d(30), why: 'I think and remember better when I sleep.', rock: 'Phone in bed.', knowledge: '', people: '', reward: '', createdAt: today };
  const wd = weekday(today);
  const mk = (f) => makeItem(f, settings, today);
  const items = [
    mk({ title: 'Calculus lecture', type: 'event', course: 'MATH201', date: today, time: '10:00', durationMin: 50, recur: { freq: 'weekly', days: [1, 3, 5] } }),
    mk({ title: 'Chemistry lab', type: 'event', course: 'CHEM110', date: today, time: '14:00', durationMin: 180, recur: { freq: 'weekly', days: [wd === 0 || wd === 6 ? 3 : wd] } }),
    mk({ title: 'Research group meeting', type: 'event', date: today, time: '16:30', durationMin: 60, recur: { freq: 'weekly', days: [2] } }),
    mk({ title: 'Office hours with Prof. Lee', type: 'event', course: 'MATH201', date: d(3), time: '15:00', durationMin: 30 }),
    mk({ title: 'Calculus midterm', type: 'exam', course: 'MATH201', date: d(12), time: '09:00', priority: 'A', effortMin: 360, weightPct: 25, goalId: goalGpa.id }),
    mk({ title: 'Chem quiz 4', type: 'exam', course: 'CHEM110', date: d(3), priority: 'A', effortMin: 120, weightPct: 5 }),
    mk({ title: 'History presentation: the printing press', type: 'presentation', course: 'HIST150', date: d(9), time: '13:00', priority: 'A', effortMin: 180, weightPct: 15 }),
    mk({ title: 'Problem set 5', type: 'deadline', course: 'MATH201', date: d(2), time: '23:59', priority: 'A', effortMin: 100, goalId: goalGpa.id }),
    mk({ title: 'Lab report: titration', type: 'deadline', course: 'CHEM110', date: d(6), priority: 'B', effortMin: 150, weightPct: 8 }),
    mk({ title: 'Read 2 papers for research group', type: 'reading', date: d(7), priority: 'B', effortMin: 120 }),
    mk({ title: 'Email TA about quiz regrade', type: 'task', course: 'CHEM110', priority: 'A' }),
    mk({ title: 'Call home', type: 'task', date: d((7 - wd) % 7), recur: { freq: 'weekly', days: [0] }, priority: 'B', goalId: goalFamily.id }),
    mk({ title: 'Renew library books', type: 'task', date: d(4), priority: 'C' }),
    mk({ title: 'Poster template for group project', type: 'task', priority: 'D' }),
    mk({ title: 'Reorganize desktop folders', type: 'task', priority: 'E' }),
    mk({ title: 'Apply for summer research program', type: 'deadline', date: d(24), effortMin: 120 }),
    mk({ title: 'Buy printer ink', type: 'task' }),
  ];
  items.find((it) => it.priority === 'D').delegateTo = 'Sam (teammate)';
  // A few study sessions already behind you, so progress has something to show.
  const studied = (title, ...days) => {
    const it = items.find((x) => x.title === title);
    for (const n of days) it.sessions.unshift({ id: uid(), date: d(n), minutes: 50, label: 'Study', done: true, doneAt: d(n) });
  };
  studied('Calculus midterm', -5, -3, -1);
  studied('History presentation: the printing press', -2);
  // What the first finished thing was on recent days (A, another letter, or nothing).
  const firstDone = {};
  'AAABAA-AABA-AA'.split('').forEach((L, k) => { if (L !== '-') firstDone[d(-1 - k)] = L; });
  return { items, goals: [goalGpa, goalFamily, goalSleep], mdp: 'I finish this semester with a 3.7 GPA', firstDone };
}
