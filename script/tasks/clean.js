const {taskify} = require("../lib/task");

const cleanTask = taskify("Clean workspace", async function() {
  await this.subtask(require('./kill-running-atom-instances'));
  await this.subtask(require('./clean-dependencies'));
  await this.subtask(require('./clean-caches'));
  await this.subtask(require('./clean-output-directory'));
});

module.exports = cleanTask;
