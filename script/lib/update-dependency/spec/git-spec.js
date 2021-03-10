const path = require('path');
const simpleGit = require('simple-git');
const repositoryRootPath = path.resolve('.', 'fixtures', 'dummy');
const git = simpleGit(repositoryRootPath);

const {
  switchToCleanBranch,
  makeBranch,
  publishBranch,
  createCommit,
  deleteBranch
} = require('../git')(git, repositoryRootPath);

describe('GIT', () => {
  async function findBranch(branch) {
    const { branches } = await git.branch();
    return Object.keys(branches).find(_branch => _branch.indexOf(branch) > -1);
  }
  const dependency = {
    moduleName: 'atom',
    latest: '2.0.0'
  };
  const branch = `${dependency.moduleName}-${dependency.latest}`;

  beforeEach(async () => {
    await git.checkout('clean-branch');
  });

  it('remotes should include ATOM', async () => {
    const remotes = await git.getRemotes();
    expect(remotes.map(({ name }) => name).includes('ATOM')).toBeTruthy();
  });

  it('current branch should be clean-branch', async () => {
    const testBranchExists = await findBranch('test');
    testBranchExists
      ? await git.checkout('test')
      : await git.checkoutLocalBranch('test');
    expect((await git.branch()).current).toBe('test');
    await switchToCleanBranch();
    expect((await git.branch()).current).toBe('clean-branch');
    await git.deleteLocalBranch('test', true);
  });

  it('should make new branch and checkout to the new branch', async () => {
    const { found, newBranch } = await makeBranch(dependency);
    expect(found).toBe(undefined);
    expect(newBranch).toBe(branch);
    expect((await git.branch()).current).toBe(branch);
    await git.checkout('clean-branch');
    await git.deleteLocalBranch(branch, true);
  });

  it('should find an existing branch and checkout to the branch', async () => {
    await git.checkoutLocalBranch(branch);
    const { found } = await makeBranch(dependency);
    expect(found).not.toBe(undefined);
    expect((await git.branch()).current).toBe(found);
    await git.checkout('clean-branch');
    await git.deleteLocalBranch(branch, true);
  });

  it('should create a commit', async () => {
    const packageJsonFilePath = path.join(repositoryRootPath, 'package.json');
    const packageLockFilePath = path.join(
      repositoryRootPath,
      'package-lock.json'
    );
    spyOn(git, 'commit');
    spyOn(git, 'add');
    await createCommit(dependency);
    expect(git.add).toHaveBeenCalledWith([
      packageJsonFilePath,
      packageLockFilePath
    ]);
    expect(git.commit).toHaveBeenCalledWith(
      `${`:arrow_up: ${dependency.moduleName}@${dependency.latest}`}`
    );
  });

  it('should publish branch', async () => {
    spyOn(git, 'push');
    await publishBranch(branch);
    expect(git.push).toHaveBeenCalledWith('ATOM', branch);
  });

  it('should delete an existing branch', async () => {
    await git.checkoutLocalBranch(branch);
    await git.checkout('clean-branch');
    expect(await findBranch(branch)).not.toBe(undefined);
    await deleteBranch(branch);
    expect(await findBranch(branch)).toBe(undefined);
  });
});
