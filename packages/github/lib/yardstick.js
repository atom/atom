// Measure elapsed durations from specific beginning points.

import fs from 'fs-extra';
import path from 'path';

// The maximum number of marks within a single DurationSet. A DurationSet will be automatically finished if this many
// marks are recorded.
const MAXIMUM_MARKS = 100;

// Flush all non-active DurationSets to disk each time that this many marks have been accumulated.
const PERSIST_INTERVAL = 1000;

// A sequence of durations measured from a fixed beginning point.
class DurationSet {
  constructor(name) {
    this.name = name;
    this.startTimestamp = performance.now();
    this.marks = [];
    this.markCount = 0;

    if (atom.config.get('github.performanceToConsole')) {
      // eslint-disable-next-line no-console
      console.log('%cbegin %c%s:begin',
        'font-weight: bold',
        'font-weight: normal; font-style: italic; color: blue', this.name);
    }

    if (atom.config.get('github.performanceToProfile')) {
      // eslint-disable-next-line no-console
      console.profile(this.name);
    }
  }

  mark(eventName) {
    const duration = performance.now() - this.startTimestamp;

    if (atom.config.get('github.performanceToConsole')) {
      // eslint-disable-next-line no-console
      console.log('%cmark %c%s:%s %c%dms',
        'font-weight: bold',
        'font-weight: normal; font-style: italic; color: blue', this.name, eventName,
        'font-style: normal; color: black', duration);
    }

    if (atom.config.get('github.performanceToDirectory') !== '') {
      this.marks.push({eventName, duration});
    }

    this.markCount++;
    if (this.markCount >= MAXIMUM_MARKS) {
      this.finish();
    }
  }

  finish() {
    this.mark('finish');

    if (atom.config.get('github.performanceToProfile')) {
      // eslint-disable-next-line no-console
      console.profileEnd(this.name);
    }
  }

  serialize() {
    return {
      name: this.name,
      markers: this.marks,
    };
  }

  getCount() {
    return this.marks.length;
  }
}

let durationSets = [];
let totalMarkCount = 0;
const activeSets = new Map();

function shouldCapture(seriesName, eventName) {
  const anyActive = ['Console', 'Directory', 'Profile'].some(kind => {
    const value = atom.config.get(`github.performanceTo${kind}`);
    return value !== '' && value !== false;
  });
  if (!anyActive) {
    return false;
  }

  const mask = new RegExp(atom.config.get('github.performanceMask'));
  if (!mask.test(`${seriesName}:${eventName}`)) {
    return false;
  }

  return true;
}

const yardstick = {
  async save() {
    const destDir = atom.config.get('github.performanceToDirectory');
    if (destDir === '' || destDir === undefined || destDir === null) {
      return;
    }
    const fileName = path.join(destDir, `performance-${Date.now()}.json`);

    await new Promise((resolve, reject) => {
      fs.ensureDir(destDir, err => (err ? reject(err) : resolve()));
    });

    const payload = JSON.stringify(durationSets.map(set => set.serialize()));
    await fs.writeFile(fileName, payload, {encoding: 'utf8'});

    if (atom.config.get('github.performanceToConsole')) {
      // eslint-disable-next-line no-console
      console.log('%csaved %c%d series to %s',
        'font-weight: bold',
        'font-weight: normal; color: black', durationSets.length, fileName);
    }

    durationSets = [];
  },

  begin(seriesName) {
    if (!shouldCapture(seriesName, 'begin')) {
      return;
    }

    const ds = new DurationSet(seriesName);
    activeSets.set(seriesName, ds);
  },

  mark(seriesName, eventName) {
    if (seriesName instanceof Array) {
      for (let i = 0; i < seriesName.length; i++) {
        this.mark(seriesName[i], eventName);
      }
      return;
    }

    if (!shouldCapture(seriesName, eventName)) {
      return;
    }

    const ds = activeSets.get(seriesName);
    if (ds === undefined) {
      return;
    }
    ds.mark(eventName);
  },

  finish(seriesName) {
    if (seriesName instanceof Array) {
      for (let i = 0; i < seriesName.length; i++) {
        this.finish(seriesName[i]);
      }
      return;
    }

    if (!shouldCapture(seriesName, 'finish')) {
      return;
    }

    const ds = activeSets.get(seriesName);
    if (ds === undefined) {
      return;
    }
    ds.finish();

    durationSets.push(ds);
    activeSets.delete(seriesName);

    totalMarkCount += ds.getCount();
    if (totalMarkCount >= PERSIST_INTERVAL) {
      totalMarkCount = 0;
      this.save();
    }
  },

  async flush() {
    durationSets.push(...activeSets.values());
    activeSets.clear();
    await this.save();
  },
};

export default yardstick;
