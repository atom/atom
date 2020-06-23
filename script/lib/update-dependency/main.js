/* eslint-disable camelcase */
const {
  makeBranch,
  createCommit,
  switchToMaster,
  publishBranch,
  deleteBranch
} = require('./git');
const {
  updatePackageJson,
  fetchOutdatedDependencies,
  sleep
} = require('./util');
const { createPR, findPR, addLabel } = require('./pull-request');
const runApmInstall = require('../run-apm-install');
const { repositoryRootPath } = require('../../config');
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
          const pr = { dependency, branch: newBranch, branchIsRemote: false };
          // confirm if branch found is a local branch
          if (found.indexOf('remotes') === -1) {
            await publishBranch(found);
          } else {
            pr.branchIsRemote = true;
          }
          pendingPRs.push(pr);
        }
      } else {
        await updatePackageJson(dependency);
        runApmInstall(repositoryRootPath, false);
        await createCommit(dependency);
        await publishBranch(newBranch);
        pendingPRs.push({
          dependency,
          branch: newBranch,
          branchIsRemote: false
        });
      }

      await switchToMaster();
    }
    // create PRs here
    for (const { dependency, branch, branchIsRemote } of pendingPRs) {
      const { status, data = {} } = await createPR(dependency, branch);
      if (status === 201) {
        successfullBumps.push(dependency);
        await addLabel(data.number);
      } else {
        failedBumps.push(dependency);
      }

      if (!branchIsRemote) {
        await deleteBranch(branch);
      }
      // https://developer.github.com/v3/guides/best-practices-for-integrators/#dealing-with-abuse-rate-limits
      await sleep(2000);
    }
    console.table([
      {
        totalDependencies,
        totalSuccessfullBumps: successfullBumps.length,
        totalFailedBumps: failedBumps.length
      }
    ]);
    console.log('Successfull bumps');
    console.table(successfullBumps);
    console.log('Failed bumps');
    console.table(failedBumps);
  } catch (ex) {
    console.log(ex.message);
  }
};
