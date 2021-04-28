const git = (git, repositoryRootPath) => {
  const path = require('path');
  const packageJsonFilePath = path.join(repositoryRootPath, 'package.json');
  const packageLockFilePath = path.join(
    repositoryRootPath,
    'package-lock.json'
  );
  try {
    git.getRemotes((err, remotes) => {
      if (!err && !remotes.map(({ name }) => name).includes('ATOM')) {
        git.addRemote(
          'ATOM',
          `https://atom:${process.env.AUTH_TOKEN}@github.com/atom/atom.git/`
        );
      }
    });
  } catch (ex) {
    console.log(ex.message);
  }

  async function createOrCheckoutBranch(newBranch) {
    await git.fetch();
    const { branches } = await git.branch();
    const found = Object.keys(branches).find(
      branch => branch.indexOf(newBranch) > -1
    );
    found
      ? await git.checkout(found)
      : await git.checkoutLocalBranch(newBranch);

    return { found, newBranch };
  }

  return {
    switchToCleanBranch: async function() {
      const cleanBranch = 'clean-branch';
      const { current } = await git.branch();
      if (current !== cleanBranch) createOrCheckoutBranch(cleanBranch);
    },
    makeBranch: async function(dependency) {
      const newBranch = `${dependency.moduleName}-${dependency.latest}`;
      const { files } = await git.status();
      if (files.length > 0) {
        await git.reset('hard');
      }
      return createOrCheckoutBranch(newBranch);
    },
    createCommit: async function({ moduleName, latest }) {
      try {
        const commitMessage = `:arrow_up: ${moduleName}@${latest}`;
        await git.add([packageJsonFilePath, packageLockFilePath]);
        await git.commit(commitMessage);
      } catch (ex) {
        throw Error(ex.message);
      }
    },
    publishBranch: async function(branch) {
      try {
        await git.push('ATOM', branch);
      } catch (ex) {
        throw Error(ex.message);
      }
    },
    deleteBranch: async function(branch) {
      try {
        await git.deleteLocalBranch(branch, true);
      } catch (ex) {
        throw Error(ex.message);
      }
    }
  };
};
module.exports = git;
