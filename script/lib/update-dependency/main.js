/* eslint-disable camelcase */
const simpleGit = require('simple-git');
const path = require('path');

const { repositoryRootPath } = require('../../config');
const packageJSON = require(path.join(repositoryRootPath, 'package.json'));
const git = simpleGit(repositoryRootPath);
const {
  createPR,
  findPR,
  addLabel,
  findOpenPRs,
  checkCIstatus,
  mergePR
} = require('./pull-request');
const runApmInstall = require('../run-apm-install');
const {
  makeBranch,
  createCommit,
  switchToCleanBranch,
  publishBranch,
  deleteBranch
} = require('./git')(git, repositoryRootPath);
const { updatePackageJson, sleep } = require('./util')(repositoryRootPath);
const fetchOutdatedDependencies = require('./fetch-outdated-dependencies');

module.exports = async function() {
  try {
    // ensure we are on master
    await switchToCleanBranch();
    const failedBumps = [];
    const successfullBumps = [];
    const outdateDependencies = [
      ...(await fetchOutdatedDependencies.npm(repositoryRootPath)),
      ...(await fetchOutdatedDependencies.apm(packageJSON))
    ];
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

      await switchToCleanBranch();
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

  // merge previous bumps that passed CI requirements
  try {
    const {
      data: { items }
    } = await findOpenPRs();
    for (const { title } of items) {
      const ref = title.replace('⬆️ ', '').replace('@', '-');
      const {
        data: { state }
      } = await checkCIstatus({ ref });
      if (state === 'success') {
        await mergePR({ ref });
      }
    }
  } catch (ex) {
    console.log(ex);
  }
};
