const {taskify} = require("../lib/task");

const bootstrapTask = taskify("Bootstrap", async function () {
  await this.subtask(require("./verify-machine-requirements"));
  if (process.argv.includes("--clean")) {
    await this.subtask(require("./clean"));
  }
  await this.subtask(require("./install-script-dependencies"));
});

module.exports = bootstrapTask;
