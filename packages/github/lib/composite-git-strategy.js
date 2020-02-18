import os from 'os';

import {firstImplementer} from './helpers';
import AsyncQueue from './async-queue';
import GitShellOutStrategy from './git-shell-out-strategy';

export default {
  create(workingDir, options = {}) {
    return this.withStrategies([GitShellOutStrategy])(workingDir, options);
  },

  withStrategies(strategies) {
    return function createForStrategies(workingDir, options = {}) {
      const parallelism = options.parallelism || Math.max(3, os.cpus().length);
      const commandQueue = new AsyncQueue({parallelism});
      const strategyOptions = {...options, queue: commandQueue};

      const strategyInstances = strategies.map(Strategy => new Strategy(workingDir, strategyOptions));
      return firstImplementer(...strategyInstances);
    };
  },
};
