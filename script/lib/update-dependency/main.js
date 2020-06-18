/* eslint-disable camelcase */
const {
  makeBranch,
  createCommit,
  switchToMaster,
  publishBranch
} = require('./git');
const {
  updatePackageJson,
  fetchOutdatedDependencies,
  runApmInstall,
  sleep
} = require('./util');
const { createPR, findPR } = require('./pull-request');
module.exports = async function() {
  try {
    // ensure we are on master
    await switchToMaster();
    const failedBumps = [];
    const successfullBumps = [];
    const outdateDependencies = await fetchOutdatedDependencies();
    const totalDependencies = outdateDependencies.length;
    const pendingPRs = [];
    for (const dependency of outdateDependencies) {
      const { found, newBranch } = await makeBranch(dependency);
      if (found) {
        console.log(`Branch was found ${found}`);
        console.log('checking if a PR already exists');
        const {
          data: { total_count }
        } = await findPR(dependency, newBranch);
        if (total_count > 0) {
          console.log(`pull request found!`);
        } else {
          console.log(`pull request not found!`);
          pendingPRs.push({ dependency, branch: newBranch });
        }
      } else {
        await updatePackageJson(dependency);
        await runApmInstall();
        await createCommit(dependency);
        await publishBranch(newBranch);
        pendingPRs.push({ dependency, branch: newBranch });
      }

      await switchToMaster();
    }
    // create PRs here
    for (const { dependency, branch } of pendingPRs) {
      const { status } = await createPR(dependency, branch);
      status === 201
        ? successfullBumps.push(dependency)
        : failedBumps.push({
            module: dependency.moduleName,
            reason: `couldn't create pull request`
          });
      // https://developer.github.com/v3/guides/best-practices-for-integrators/#dealing-with-abuse-rate-limits
      await sleep(2000);
    }
    console.log(
      `Total dependencies: ${totalDependencies} Sucessfull: ${
        successfullBumps.length
      } Failed: ${failedBumps.length}`
    );
    // TODO: log other useful information
  } catch (ex) {
    // TODO: handle errors
  }
};
