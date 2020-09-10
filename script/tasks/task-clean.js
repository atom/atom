#!/usr/bin/env node

'use strict';

const cleanCaches = require('./task-clean-caches');
const cleanDependencies = require('./task-clean-dependencies');
const cleanOutputDirectory = require('./task-clean-output-directory');
const killRunningAtomInstances = require('./task-kill-running-atom-instances');

module.exports = function(task) {
  task.start('Clean');

  killRunningAtomInstances(task.subtask());
  cleanDependencies(task.subtask());
  cleanCaches(task.subtask());
  cleanOutputDirectory(task.subtask());

  task.done();
};
