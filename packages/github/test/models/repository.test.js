import fs from 'fs-extra';
import path from 'path';
import dedent from 'dedent-js';
import temp from 'temp';
import compareSets from 'compare-sets';
import isEqualWith from 'lodash.isequalwith';

import Repository from '../../lib/models/repository';
import CompositeGitStrategy from '../../lib/composite-git-strategy';
import {LargeRepoError} from '../../lib/git-shell-out-strategy';
import {nullCommit} from '../../lib/models/commit';
import {nullOperationStates} from '../../lib/models/operation-states';
import Author from '../../lib/models/author';
import {FOCUS} from '../../lib/models/workspace-change-observer';
import * as reporterProxy from '../../lib/reporter-proxy';

import {
  cloneRepository, setUpLocalAndRemoteRepositories, getHeadCommitOnRemote,
  assertDeepPropertyVals, assertEqualSortedArraysByKey, FAKE_USER, wireUpObserver, expectEvents,
} from '../helpers';
import {getPackageRoot, getTempDir} from '../../lib/helpers';

describe('Repository', function() {
  describe('initial states', function() {
    let repository;

    afterEach(async function() {
      repository && await repository.destroy();
    });

    it('begins in the Loading state with a working directory', async function() {
      const workdir = await cloneRepository('three-files');
      repository = new Repository(workdir);
      assert.isTrue(repository.isInState('Loading'));
    });

    it('begins in the Absent state with .absent()', function() {
      repository = Repository.absent();
      assert.isTrue(repository.isInState('Absent'));
    });

    it('begins in an AbsentGuess state with .absentGuess()', function() {
      repository = Repository.absentGuess();
      assert.isTrue(repository.isInState('AbsentGuess'));
      assert.isFalse(repository.showGitTabLoading());
      assert.isTrue(repository.showGitTabInit());
    });

    it('begins in a LoadingGuess state with .guess()', function() {
      repository = Repository.loadingGuess();
      assert.isTrue(repository.isInState('LoadingGuess'));
      assert.isTrue(repository.showGitTabLoading());
      assert.isFalse(repository.showGitTabInit());
    });
  });

  describe('inherited State methods', function() {
    let repository;

    beforeEach(function() {
      repository = Repository.absent();
      repository.destroy();
    });

    it('returns a null object', async function() {
      // Methods that default to "false"
      for (const method of [
        'isLoadingGuess', 'isAbsentGuess', 'isAbsent', 'isLoading', 'isEmpty', 'isPresent', 'isTooLarge',
        'isUndetermined', 'showGitTabInit', 'showGitTabInitInProgress', 'showGitTabLoading', 'showStatusBarTiles',
        'hasDiscardHistory', 'isMerging', 'isRebasing', 'isCommitPushed',
      ]) {
        assert.isFalse(await repository[method]());
      }

      // Methods that resolve to null
      for (const method of [
        'getAheadCount', 'getBehindCount', 'getConfig', 'getLastHistorySnapshots', 'getCache',
      ]) {
        assert.isNull(await repository[method]());
      }

      // Methods that resolve to an empty array
      for (const method of [
        'getRecentCommits', 'getAuthors', 'getDiscardHistory',
      ]) {
        assert.lengthOf(await repository[method](), 0);
      }

      assert.deepEqual(await repository.getStatusBundle(), {
        stagedFiles: {},
        unstagedFiles: {},
        mergeConflictFiles: {},
        branch: {
          oid: null,
          head: null,
          upstream: null,
          aheadBehind: {
            ahead: null,
            behind: null,
          },
        },
      });

      assert.deepEqual(await repository.getStatusesForChangedFiles(), {
        stagedFiles: [],
        unstagedFiles: [],
        mergeConflictFiles: [],
      });

      assert.strictEqual(await repository.getLastCommit(), nullCommit);
      assert.lengthOf((await repository.getBranches()).getNames(), 0);
      assert.isTrue((await repository.getRemotes()).isEmpty());
      assert.strictEqual(await repository.getHeadDescription(), '(no repository)');
      assert.strictEqual(await repository.getOperationStates(), nullOperationStates);
      assert.strictEqual(await repository.getCommitMessage(), '');
      assert.isFalse((await repository.getFilePatchForPath('anything.txt')).anyPresent());
    });

    it('returns a rejecting promise', async function() {
      for (const method of [
        'init', 'clone', 'stageFiles', 'unstageFiles', 'stageFilesFromParentCommit', 'applyPatchToIndex',
        'applyPatchToWorkdir', 'commit', 'merge', 'abortMerge', 'checkoutSide', 'mergeFile',
        'writeMergeConflictToIndex', 'checkout', 'checkoutPathsAtRevision', 'undoLastCommit', 'fetch', 'pull',
        'push', 'setConfig', 'unsetConfig', 'createBlob', 'expandBlobToFile', 'createDiscardHistoryBlob',
        'updateDiscardHistory', 'storeBeforeAndAfterBlobs', 'restoreLastDiscardInTempFiles', 'popDiscardHistory',
        'clearDiscardHistory', 'discardWorkDirChangesForPaths', 'addRemote', 'setCommitMessage',
        'fetchCommitMessageTemplate',
      ]) {
        await assert.isRejected(repository[method](), new RegExp(`${method} is not available in Destroyed state`));
      }

      await assert.isRejected(
        repository.readFileFromIndex('file'),
        /fatal: Path file does not exist \(neither on disk nor in the index\)\./,
      );
      await assert.isRejected(
        repository.getBlobContents('abcd'),
        /fatal: Not a valid object name abcd/,
      );
    });
  });

  it('accesses an OperationStates model', async function() {
    const repository = new Repository(await cloneRepository());
    await repository.getLoadPromise();

    const os = repository.getOperationStates();
    assert.isFalse(os.isPushInProgress());
    assert.isFalse(os.isPullInProgress());
    assert.isFalse(os.isFetchInProgress());
    assert.isFalse(os.isCommitInProgress());
    assert.isFalse(os.isCheckoutInProgress());
  });

  it('shows status bar tiles once present', async function() {
    const repository = new Repository(await cloneRepository());
    assert.isFalse(repository.showStatusBarTiles());
    await repository.getLoadPromise();
    assert.isTrue(repository.showStatusBarTiles());
  });

  describe('getCurrentGitHubRemote', function() {
    let workdir, repository;
    beforeEach(async function() {
      workdir = await cloneRepository('three-files');
      repository = new Repository(workdir);
      await repository.getLoadPromise();
    });
    it('gets current GitHub remote if remote is configured', async function() {
      await repository.addRemote('yes0', 'git@github.com:atom/github.git');

      const remote = await repository.getCurrentGitHubRemote();
      assert.strictEqual(remote.url, 'git@github.com:atom/github.git');
      assert.strictEqual(remote.name, 'yes0');
    });

    it('returns null remote no remotes exist', async function() {
      const remote = await repository.getCurrentGitHubRemote();
      assert.isFalse(remote.isPresent());
    });

    it('returns null remote if only non-GitHub remotes exist', async function() {
      await repository.addRemote('no0', 'https://sourceforge.net/some/repo.git');
      const remote = await repository.getCurrentGitHubRemote();
      assert.isFalse(remote.isPresent());
    });

    it('returns null remote if no remotes are configured and multiple GitHub remotes exist', async function() {
      await repository.addRemote('yes0', 'git@github.com:atom/github.git');
      await repository.addRemote('yes1', 'git@github.com:smashwilson/github.git');
      const remote = await repository.getCurrentGitHubRemote();
      assert.isFalse(remote.isPresent());
    });

    it('returns null remote before repository has loaded', async function() {
      const loadingRepository = new Repository(workdir);
      const remote = await loadingRepository.getCurrentGitHubRemote();
      assert.isFalse(remote.isPresent());
    });
  });

  describe('getGitDirectoryPath', function() {
    it('returns the correct git directory path', async function() {
      const workingDirPath = await cloneRepository('three-files');
      const workingDirPathWithGitFile = await getTempDir();
      await fs.writeFile(
        path.join(workingDirPathWithGitFile, '.git'),
        `gitdir: ${path.join(workingDirPath, '.git')}`,
        {encoding: 'utf8'},
      );

      const repository = new Repository(workingDirPath);
      assert.equal(repository.getGitDirectoryPath(), path.join(workingDirPath, '.git'));

      const repositoryWithGitFile = new Repository(workingDirPathWithGitFile);
      await assert.async.equal(repositoryWithGitFile.getGitDirectoryPath(), path.join(workingDirPath, '.git'));
    });

    it('returns null for absent/loading repositories', function() {
      const repo = Repository.absent();
      repo.getGitDirectoryPath();
    });
  });

  describe('init', function() {
    it('creates a repository in the given dir and returns the repository', async function() {
      const soonToBeRepositoryPath = await fs.realpath(temp.mkdirSync());
      const repo = new Repository(soonToBeRepositoryPath);
      assert.isTrue(repo.isLoading());

      await repo.getLoadPromise();
      assert.isTrue(repo.isEmpty());

      await repo.init();

      assert.isTrue(repo.isPresent());
      assert.equal(repo.getWorkingDirectoryPath(), soonToBeRepositoryPath);
    });

    it('fails with an error when a repository is already present', async function() {
      const workdir = await cloneRepository();
      const repository = new Repository(workdir);
      await repository.getLoadPromise();

      await assert.isRejected(repository.init());
    });
  });

  describe('clone', function() {
    it('clones a repository from a URL to a directory and returns the repository', async function() {
      const upstreamPath = await cloneRepository('three-files');
      const destDir = await fs.realpath(temp.mkdirSync());

      const repo = new Repository(destDir);
      const clonePromise = repo.clone(upstreamPath);
      assert.isTrue(repo.isLoading());
      await clonePromise;
      assert.isTrue(repo.isPresent());
      assert.equal(repo.getWorkingDirectoryPath(), destDir);
    });

    it('clones a repository when the directory does not exist yet', async function() {
      const upstreamPath = await cloneRepository('three-files');
      const parentDir = await fs.realpath(temp.mkdirSync());
      const destDir = path.join(parentDir, 'subdir');

      const repo = new Repository(destDir);
      await repo.clone(upstreamPath, destDir);
      assert.isTrue(repo.isPresent());
      assert.equal(repo.getWorkingDirectoryPath(), destDir);
    });

    it('fails with an error when a repository is already present', async function() {
      const upstream = await cloneRepository();

      const workdir = await cloneRepository();
      const repository = new Repository(workdir);
      await repository.getLoadPromise();

      await assert.isRejected(repository.clone(upstream));
    });
  });

  describe('staging and unstaging files', function() {
    it('can stage and unstage modified files', async function() {
      const workingDirPath = await cloneRepository('three-files');
      const repo = new Repository(workingDirPath);
      await repo.getLoadPromise();

      fs.writeFileSync(path.join(workingDirPath, 'subdir-1', 'a.txt'), 'qux\nfoo\nbar\n', 'utf8');
      const [patch] = await repo.getUnstagedChanges();
      const filePath = patch.filePath;

      await repo.stageFiles([filePath]);
      repo.refresh();
      assert.deepEqual(await repo.getUnstagedChanges(), []);
      assert.deepEqual(await repo.getStagedChanges(), [patch]);

      await repo.unstageFiles([filePath]);
      repo.refresh();
      assert.deepEqual(await repo.getUnstagedChanges(), [patch]);
      assert.deepEqual(await repo.getStagedChanges(), []);
    });

    it('can stage and unstage removed files', async function() {
      const workingDirPath = await cloneRepository('three-files');
      const repo = new Repository(workingDirPath);
      await repo.getLoadPromise();

      fs.unlinkSync(path.join(workingDirPath, 'subdir-1', 'b.txt'));
      const [patch] = await repo.getUnstagedChanges();
      const filePath = patch.filePath;

      await repo.stageFiles([filePath]);
      repo.refresh();
      assert.deepEqual(await repo.getUnstagedChanges(), []);
      assert.deepEqual(await repo.getStagedChanges(), [patch]);

      await repo.unstageFiles([filePath]);
      repo.refresh();
      assert.deepEqual(await repo.getUnstagedChanges(), [patch]);
      assert.deepEqual(await repo.getStagedChanges(), []);
    });

    it('can stage and unstage renamed files', async function() {
      const workingDirPath = await cloneRepository('three-files');
      const repo = new Repository(workingDirPath);
      await repo.getLoadPromise();

      fs.renameSync(path.join(workingDirPath, 'c.txt'), path.join(workingDirPath, 'subdir-1', 'd.txt'));
      const patches = await repo.getUnstagedChanges();
      const filePath1 = patches[0].filePath;
      const filePath2 = patches[1].filePath;

      await repo.stageFiles([filePath1, filePath2]);
      repo.refresh();
      assertEqualSortedArraysByKey(await repo.getStagedChanges(), patches, 'filePath');
      assert.deepEqual(await repo.getUnstagedChanges(), []);

      await repo.unstageFiles([filePath1, filePath2]);
      repo.refresh();
      assertEqualSortedArraysByKey(await repo.getUnstagedChanges(), patches, 'filePath');
      assert.deepEqual(await repo.getStagedChanges(), []);
    });

    it('can stage and unstage added files, including those in added directories', async function() {
      const workingDirPath = await cloneRepository('three-files');
      fs.writeFileSync(path.join(workingDirPath, 'subdir-1', 'e.txt'), 'qux', 'utf8');
      fs.mkdirSync(path.join(workingDirPath, 'new-folder'));
      fs.writeFileSync(path.join(workingDirPath, 'new-folder', 'b.txt'), 'bar\n', 'utf8');
      fs.writeFileSync(path.join(workingDirPath, 'new-folder', 'c.txt'), 'baz\n', 'utf8');

      const repo = new Repository(workingDirPath);
      await repo.getLoadPromise();

      const unstagedChanges = await repo.getUnstagedChanges();
      assert.equal(unstagedChanges.length, 3);

      await repo.stageFiles([unstagedChanges[0].filePath, unstagedChanges[2].filePath]);
      repo.refresh();
      assert.deepEqual(await repo.getUnstagedChanges(), [unstagedChanges[1]]);
      assert.deepEqual(await repo.getStagedChanges(), [unstagedChanges[0], unstagedChanges[2]]);

      await repo.unstageFiles([unstagedChanges[0].filePath]);
      repo.refresh();
      assert.deepEqual(await repo.getUnstagedChanges(), [unstagedChanges[0], unstagedChanges[1]]);
      assert.deepEqual(await repo.getStagedChanges(), [unstagedChanges[2]]);
    });

    it('can stage and unstage file modes without staging file contents', async function() {
      const workingDirPath = await cloneRepository('three-files');
      const repo = new Repository(workingDirPath);
      await repo.getLoadPromise();
      const filePath = 'a.txt';

      async function indexModeAndOid(filename) {
        const output = await repo.git.exec(['ls-files', '-s', '--', filename]);
        const parts = output.split(' ');
        return {mode: parts[0], oid: parts[1]};
      }

      const {mode, oid} = await indexModeAndOid(path.join(workingDirPath, filePath));
      assert.equal(mode, '100644');
      fs.chmodSync(path.join(workingDirPath, filePath), 0o755);
      fs.writeFileSync(path.join(workingDirPath, filePath), 'qux\nfoo\nbar\n', 'utf8');

      await repo.stageFileModeChange(filePath, '100755');
      assert.deepEqual(await indexModeAndOid(filePath), {mode: '100755', oid});

      await repo.stageFileModeChange(filePath, '100644');
      assert.deepEqual(await indexModeAndOid(filePath), {mode: '100644', oid});
    });

    it('can stage and unstage symlink changes without staging file contents', async function() {
      if (process.env.ATOM_GITHUB_SKIP_SYMLINKS) {
        this.skip();
        return;
      }

      const workingDirPath = await cloneRepository('symlinks');
      const repo = new Repository(workingDirPath);
      await repo.getLoadPromise();

      async function indexModeAndOid(filename) {
        const output = await repo.git.exec(['ls-files', '-s', '--', filename]);
        if (output) {
          const parts = output.split(' ');
          return {mode: parts[0], oid: parts[1]};
        } else {
          return null;
        }
      }

      const deletedSymlinkAddedFilePath = 'symlink.txt';
      fs.unlinkSync(path.join(workingDirPath, deletedSymlinkAddedFilePath));
      fs.writeFileSync(path.join(workingDirPath, deletedSymlinkAddedFilePath), 'qux\nfoo\nbar\n', 'utf8');

      const deletedFileAddedSymlinkPath = 'a.txt';
      fs.unlinkSync(path.join(workingDirPath, deletedFileAddedSymlinkPath));
      fs.symlinkSync(path.join(workingDirPath, 'regular-file.txt'), path.join(workingDirPath, deletedFileAddedSymlinkPath));

      // Stage symlink change, leaving added file unstaged
      assert.equal((await indexModeAndOid(deletedSymlinkAddedFilePath)).mode, '120000');
      await repo.stageFileSymlinkChange(deletedSymlinkAddedFilePath);
      assert.isNull(await indexModeAndOid(deletedSymlinkAddedFilePath));
      const unstagedFilePatch = await repo.getFilePatchForPath(deletedSymlinkAddedFilePath, {staged: false});
      assert.lengthOf(unstagedFilePatch.getFilePatches(), 1);
      const [uFilePatch] = unstagedFilePatch.getFilePatches();
      assert.equal(uFilePatch.getStatus(), 'added');
      assert.equal(unstagedFilePatch.toString(), dedent`
        diff --git a/symlink.txt b/symlink.txt
        new file mode 100644
        --- /dev/null
        +++ b/symlink.txt
        @@ -0,0 +1,3 @@
        +qux
        +foo
        +bar\n
      `);

      // Unstage symlink change, leaving deleted file staged
      await repo.stageFiles([deletedFileAddedSymlinkPath]);
      assert.equal((await indexModeAndOid(deletedFileAddedSymlinkPath)).mode, '120000');
      await repo.stageFileSymlinkChange(deletedFileAddedSymlinkPath);
      assert.isNull(await indexModeAndOid(deletedFileAddedSymlinkPath));
      const stagedFilePatch = await repo.getFilePatchForPath(deletedFileAddedSymlinkPath, {staged: true});
      assert.lengthOf(stagedFilePatch.getFilePatches(), 1);
      const [sFilePatch] = stagedFilePatch.getFilePatches();
      assert.equal(sFilePatch.getStatus(), 'deleted');
      assert.equal(stagedFilePatch.toString(), dedent`
        diff --git a/a.txt b/a.txt
        deleted file mode 100644
        --- a/a.txt
        +++ /dev/null
        @@ -1,4 +0,0 @@
        -foo
        -bar
        -baz
        -\n
      `);
    });

    it('sorts staged and unstaged files', async function() {
      const workingDirPath = await cloneRepository('three-files');
      const repo = new Repository(workingDirPath);
      await repo.getLoadPromise();

      const zShortPath = path.join('z-dir', 'a.txt');
      const zFilePath = path.join(workingDirPath, zShortPath);
      const wFilePath = path.join(workingDirPath, 'w.txt');
      fs.mkdirSync(path.join(workingDirPath, 'z-dir'));
      fs.renameSync(path.join(workingDirPath, 'a.txt'), zFilePath);
      fs.renameSync(path.join(workingDirPath, 'b.txt'), wFilePath);
      const unstagedChanges = await repo.getUnstagedChanges();
      const unstagedPaths = unstagedChanges.map(change => change.filePath);

      assert.deepStrictEqual(unstagedPaths, ['a.txt', 'b.txt', 'w.txt', zShortPath]);

      await repo.stageFiles([zFilePath]);
      await repo.stageFiles([wFilePath]);
      const stagedChanges = await repo.getStagedChanges();
      const stagedPaths = stagedChanges.map(change => change.filePath);

      assert.deepStrictEqual(stagedPaths, ['w.txt', zShortPath]);
    });
  });

  describe('getStatusBundle', function() {
    it('transitions to the TooLarge state and returns empty status when too large', async function() {
      const workdir = await cloneRepository();
      const repository = new Repository(workdir);
      await repository.getLoadPromise();

      sinon.stub(repository.git, 'getStatusBundle').rejects(new LargeRepoError());

      const result = await repository.getStatusBundle();

      assert.isTrue(repository.isInState('TooLarge'));
      assert.deepEqual(result.branch, {});
      assert.deepEqual(result.stagedFiles, {});
      assert.deepEqual(result.unstagedFiles, {});
      assert.deepEqual(result.mergeConflictFiles, {});
    });

    it('propagates unrecognized git errors', async function() {
      const workdir = await cloneRepository();
      const repository = new Repository(workdir);
      await repository.getLoadPromise();

      sinon.stub(repository.git, 'getStatusBundle').rejects(new Error('oh no'));

      await assert.isRejected(repository.getStatusBundle(), /oh no/);
    });

    it('post-processes renamed files to an addition and a deletion', async function() {
      const workdir = await cloneRepository();
      const repository = new Repository(workdir);
      await repository.getLoadPromise();

      sinon.stub(repository.git, 'getStatusBundle').resolves({
        changedEntries: [],
        untrackedEntries: [],
        renamedEntries: [
          {stagedStatus: 'R', origFilePath: 'from0.txt', filePath: 'to0.txt'},
          {unstagedStatus: 'R', origFilePath: 'from1.txt', filePath: 'to1.txt'},
          {stagedStatus: 'C', filePath: 'c2.txt'},
          {unstagedStatus: 'C', filePath: 'c3.txt'},
        ],
        unmergedEntries: [],
      });

      const result = await repository.getStatusBundle();
      assert.strictEqual(result.stagedFiles['from0.txt'], 'deleted');
      assert.strictEqual(result.stagedFiles['to0.txt'], 'added');
      assert.strictEqual(result.unstagedFiles['from1.txt'], 'deleted');
      assert.strictEqual(result.unstagedFiles['to1.txt'], 'added');
      assert.strictEqual(result.stagedFiles['c2.txt'], 'added');
      assert.strictEqual(result.unstagedFiles['c3.txt'], 'added');
    });
  });

  describe('getFilePatchForPath', function() {
    it('returns cached MultiFilePatch objects if they exist', async function() {
      const workingDirPath = await cloneRepository('multiple-commits');
      const repo = new Repository(workingDirPath);
      await repo.getLoadPromise();

      fs.writeFileSync(path.join(workingDirPath, 'new-file.txt'), 'foooooo', 'utf8');
      fs.writeFileSync(path.join(workingDirPath, 'file.txt'), 'qux\nfoo\nbar\n', 'utf8');
      await repo.stageFiles(['file.txt']);

      const unstagedFilePatch = await repo.getFilePatchForPath('new-file.txt');
      const stagedFilePatch = await repo.getFilePatchForPath('file.txt', {staged: true});
      assert.equal(await repo.getFilePatchForPath('new-file.txt'), unstagedFilePatch);
      assert.equal(await repo.getFilePatchForPath('file.txt', {staged: true}), stagedFilePatch);
    });

    it('returns new MultiFilePatch object after repository refresh', async function() {
      const workingDirPath = await cloneRepository('three-files');
      const repo = new Repository(workingDirPath);
      await repo.getLoadPromise();

      fs.writeFileSync(path.join(workingDirPath, 'a.txt'), 'qux\nfoo\nbar\n', 'utf8');

      const filePatchA = await repo.getFilePatchForPath('a.txt');
      assert.equal(await repo.getFilePatchForPath('a.txt'), filePatchA);

      repo.refresh();
      assert.notEqual(await repo.getFilePatchForPath('a.txt'), filePatchA);
      assert.isTrue((await repo.getFilePatchForPath('a.txt')).isEqual(filePatchA));
    });

    it('returns an empty MultiFilePatch for unknown paths', async function() {
      const workingDirPath = await cloneRepository('multiple-commits');
      const repo = new Repository(workingDirPath);
      await repo.getLoadPromise();

      const patch = await repo.getFilePatchForPath('no.txt');
      assert.isFalse(patch.anyPresent());
    });
  });

  describe('getStagedChangesPatch', function() {
    it('computes a multi-file patch of the staged changes', async function() {
      const workdir = await cloneRepository('each-staging-group');
      const repo = new Repository(workdir);
      await repo.getLoadPromise();

      await fs.writeFile(path.join(workdir, 'unstaged-1.txt'), 'Unstaged file');

      await fs.writeFile(path.join(workdir, 'staged-1.txt'), 'Staged file');
      await fs.writeFile(path.join(workdir, 'staged-2.txt'), 'Staged file');
      await repo.stageFiles(['staged-1.txt', 'staged-2.txt']);

      const mp = await repo.getStagedChangesPatch();

      assert.lengthOf(mp.getFilePatches(), 2);
      assert.deepEqual(mp.getFilePatches().map(fp => fp.getPath()), ['staged-1.txt', 'staged-2.txt']);
    });
  });

  describe('isPartiallyStaged(filePath)', function() {
    it('returns true if specified file path is partially staged', async function() {
      const workingDirPath = await cloneRepository('three-files');
      const repo = new Repository(workingDirPath);
      await repo.getLoadPromise();

      fs.writeFileSync(path.join(workingDirPath, 'a.txt'), 'modified file', 'utf8');
      fs.writeFileSync(path.join(workingDirPath, 'new-file.txt'), 'foo\nbar\nbaz\n', 'utf8');
      fs.writeFileSync(path.join(workingDirPath, 'b.txt'), 'blah blah blah', 'utf8');
      fs.unlinkSync(path.join(workingDirPath, 'c.txt'));

      assert.isFalse(await repo.isPartiallyStaged('a.txt'));
      assert.isFalse(await repo.isPartiallyStaged('b.txt'));
      assert.isFalse(await repo.isPartiallyStaged('c.txt'));
      assert.isFalse(await repo.isPartiallyStaged('new-file.txt'));

      await repo.stageFiles(['a.txt', 'b.txt', 'c.txt', 'new-file.txt']);
      repo.refresh();

      assert.isFalse(await repo.isPartiallyStaged('a.txt'));
      assert.isFalse(await repo.isPartiallyStaged('b.txt'));
      assert.isFalse(await repo.isPartiallyStaged('c.txt'));
      assert.isFalse(await repo.isPartiallyStaged('new-file.txt'));

      // modified on both
      fs.writeFileSync(path.join(workingDirPath, 'a.txt'), 'more mods', 'utf8');
      // modified in working directory, added on index
      fs.writeFileSync(path.join(workingDirPath, 'new-file.txt'), 'foo\nbar\nbaz\nqux\n', 'utf8');
      // deleted in working directory, modified on index
      fs.unlinkSync(path.join(workingDirPath, 'b.txt'));
      // untracked in working directory, deleted on index
      fs.writeFileSync(path.join(workingDirPath, 'c.txt'), 'back baby', 'utf8');
      repo.refresh();

      assert.isTrue(await repo.isPartiallyStaged('a.txt'));
      assert.isTrue(await repo.isPartiallyStaged('b.txt'));
      assert.isTrue(await repo.isPartiallyStaged('c.txt'));
      assert.isTrue(await repo.isPartiallyStaged('new-file.txt'));
    });
  });

  describe('applyPatchToIndex', function() {
    it('can stage and unstage modified files', async function() {
      const workingDirPath = await cloneRepository('three-files');
      const repo = new Repository(workingDirPath);
      await repo.getLoadPromise();

      fs.writeFileSync(path.join(workingDirPath, 'subdir-1', 'a.txt'), 'qux\nfoo\nbar\n', 'utf8');
      const unstagedPatch1 = await repo.getFilePatchForPath(path.join('subdir-1', 'a.txt'));

      fs.writeFileSync(path.join(workingDirPath, 'subdir-1', 'a.txt'), 'qux\nfoo\nbar\nbaz\n', 'utf8');
      repo.refresh();
      const unstagedPatch2 = await repo.getFilePatchForPath(path.join('subdir-1', 'a.txt'));

      await repo.applyPatchToIndex(unstagedPatch1);
      repo.refresh();
      const stagedPatch1 = await repo.getFilePatchForPath(path.join('subdir-1', 'a.txt'), {staged: true});
      assert.isTrue(stagedPatch1.isEqual(unstagedPatch1));

      let unstagedChanges = (await repo.getUnstagedChanges()).map(c => c.filePath);
      let stagedChanges = (await repo.getStagedChanges()).map(c => c.filePath);
      assert.deepEqual(unstagedChanges, [path.join('subdir-1', 'a.txt')]);
      assert.deepEqual(stagedChanges, [path.join('subdir-1', 'a.txt')]);

      await repo.applyPatchToIndex(unstagedPatch1.getUnstagePatchForLines(new Set([0, 1, 2])));
      repo.refresh();
      const unstagedPatch3 = await repo.getFilePatchForPath(path.join('subdir-1', 'a.txt'));
      assert.isTrue(unstagedPatch3.isEqual(unstagedPatch2));
      unstagedChanges = (await repo.getUnstagedChanges()).map(c => c.filePath);
      stagedChanges = (await repo.getStagedChanges()).map(c => c.filePath);
      assert.deepEqual(unstagedChanges, [path.join('subdir-1', 'a.txt')]);
      assert.deepEqual(stagedChanges, []);
    });
  });

  describe('commit', function() {
    let rp = '';

    beforeEach(function() {
      rp = process.env.PATH;
    });

    afterEach(function() {
      process.env.PATH = rp;
    });

    it('creates a commit that contains the staged changes', async function() {
      const workingDirPath = await cloneRepository('three-files');
      const repo = new Repository(workingDirPath);
      await repo.getLoadPromise();

      assert.equal((await repo.getLastCommit()).getMessageSubject(), 'Initial commit');

      fs.writeFileSync(path.join(workingDirPath, 'subdir-1', 'a.txt'), 'qux\nfoo\nbar\n', 'utf8');
      const unstagedPatch1 = await repo.getFilePatchForPath(path.join('subdir-1', 'a.txt'));
      fs.writeFileSync(path.join(workingDirPath, 'subdir-1', 'a.txt'), 'qux\nfoo\nbar\nbaz\n', 'utf8');
      repo.refresh();
      await repo.applyPatchToIndex(unstagedPatch1);
      await repo.commit('Commit 1');
      assert.equal((await repo.getLastCommit()).getMessageSubject(), 'Commit 1');
      repo.refresh();
      assert.deepEqual(await repo.getStagedChanges(), []);
      const unstagedChanges = await repo.getUnstagedChanges();
      assert.equal(unstagedChanges.length, 1);

      const unstagedPatch2 = await repo.getFilePatchForPath(path.join('subdir-1', 'a.txt'));
      await repo.applyPatchToIndex(unstagedPatch2);
      await repo.commit('Commit 2');
      assert.equal((await repo.getLastCommit()).getMessageSubject(), 'Commit 2');
      repo.refresh();
      assert.deepEqual(await repo.getStagedChanges(), []);
      assert.deepEqual(await repo.getUnstagedChanges(), []);
    });

    it('amends the last commit when the amend option is set to true', async function() {
      const workingDirPath = await cloneRepository('multiple-commits');
      const repo = new Repository(workingDirPath);
      await repo.getLoadPromise();

      const lastCommit = await repo.git.getHeadCommit();
      const lastCommitParent = await repo.git.getCommit('HEAD~');
      await repo.commit('amend last commit', {allowEmpty: true, amend: true});
      const amendedCommit = await repo.git.getHeadCommit();
      const amendedCommitParent = await repo.git.getCommit('HEAD~');
      assert.notDeepEqual(lastCommit, amendedCommit);
      assert.deepEqual(lastCommitParent, amendedCommitParent);
    });

    it('throws an error when there are unmerged files', async function() {
      const workingDirPath = await cloneRepository('merge-conflict');
      const repository = new Repository(workingDirPath);
      await repository.getLoadPromise();

      await assert.isRejected(repository.git.merge('origin/branch'));

      assert.equal(await repository.isMerging(), true);
      const mergeBase = await repository.getLastCommit();

      try {
        await repository.commit('Merge Commit');
      } catch (e) {
        assert.isAbove(e.code, 0);
        assert.match(e.command, /commit/);
      }

      assert.equal(await repository.isMerging(), true);
      assert.equal((await repository.getLastCommit()).getSha(), mergeBase.getSha());
    });

    it('clears the stored resolution progress');

    it('executes hook scripts with a sane environment', async function() {
      const workingDirPath = await cloneRepository('three-files');
      const scriptDirPath = path.join(getPackageRoot(), 'test', 'scripts');
      await fs.copy(
        path.join(scriptDirPath, 'hook.sh'),
        path.join(workingDirPath, '.git', 'hooks', 'pre-commit'),
      );
      const repo = new Repository(workingDirPath);
      await repo.getLoadPromise();

      process.env.PATH = `${scriptDirPath}:${process.env.PATH}`;

      await assert.isRejected(repo.commit('hmm'), /didirun\.sh did run/);
    });

    describe('recording commit event with metadata', function() {
      it('reports partial commits', async function() {
        const workingDirPath = await cloneRepository('three-files');
        const repo = new Repository(workingDirPath);
        await repo.getLoadPromise();

        sinon.stub(reporterProxy, 'addEvent');

        // stage only subset of total changes
        fs.writeFileSync(path.join(workingDirPath, 'a.txt'), 'qux\nfoo\nbar\n', 'utf8');
        fs.writeFileSync(path.join(workingDirPath, 'b.txt'), 'qux\nfoo\nbar\nbaz\n', 'utf8');
        await repo.stageFiles(['a.txt']);
        repo.refresh();

        // unstaged changes remain
        let unstagedChanges = await repo.getUnstagedChanges();
        assert.equal(unstagedChanges.length, 1);

        // do partial commit
        await repo.commit('Partial commit');
        assert.isTrue(reporterProxy.addEvent.called);
        let args = reporterProxy.addEvent.lastCall.args;
        assert.strictEqual(args[0], 'commit');
        assert.isTrue(args[1].partial);

        // stage all remaining changes
        await repo.stageFiles(['b.txt']);
        repo.refresh();
        unstagedChanges = await repo.getUnstagedChanges();
        assert.equal(unstagedChanges.length, 0);

        reporterProxy.addEvent.reset();
        // do whole commit
        await repo.commit('Commit everything');
        assert.isTrue(reporterProxy.addEvent.called);
        args = reporterProxy.addEvent.lastCall.args;
        assert.strictEqual(args[0], 'commit');
        assert.isFalse(args[1].partial);
      });

      it('reports if the commit was an amend', async function() {
        const workingDirPath = await cloneRepository('three-files');
        const repo = new Repository(workingDirPath);
        await repo.getLoadPromise();

        sinon.stub(reporterProxy, 'addEvent');

        await repo.commit('Regular commit', {allowEmpty: true});
        assert.isTrue(reporterProxy.addEvent.called);
        let args = reporterProxy.addEvent.lastCall.args;
        assert.strictEqual(args[0], 'commit');
        assert.isFalse(args[1].amend);

        reporterProxy.addEvent.reset();
        await repo.commit('Amended commit', {allowEmpty: true, amend: true});
        assert.isTrue(reporterProxy.addEvent.called);
        args = reporterProxy.addEvent.lastCall.args;
        assert.deepEqual(args[0], 'commit');
        assert.isTrue(args[1].amend);
      });

      it('reports number of coAuthors for commit', async function() {
        const workingDirPath = await cloneRepository('three-files');
        const repo = new Repository(workingDirPath);
        await repo.getLoadPromise();

        sinon.stub(reporterProxy, 'addEvent');

        await repo.commit('Commit with no co-authors', {allowEmpty: true});
        assert.isTrue(reporterProxy.addEvent.called);
        let args = reporterProxy.addEvent.lastCall.args;
        assert.deepEqual(args[0], 'commit');
        assert.deepEqual(args[1].coAuthorCount, 0);

        reporterProxy.addEvent.reset();
        await repo.commit('Commit with fabulous co-authors', {
          allowEmpty: true,
          coAuthors: [new Author('mona@lisa.com', 'Mona Lisa'), new Author('hubot@github.com', 'Mr. Hubot')],
        });
        assert.isTrue(reporterProxy.addEvent.called);
        args = reporterProxy.addEvent.lastCall.args;
        assert.deepEqual(args[0], 'commit');
        assert.deepEqual(args[1].coAuthorCount, 2);
      });

      it('does not record an event if operation fails', async function() {
        const workingDirPath = await cloneRepository('multiple-commits');
        const repo = new Repository(workingDirPath);
        await repo.getLoadPromise();

        sinon.stub(reporterProxy, 'addEvent');
        sinon.stub(repo.git, 'commit').throws();

        await assert.isRejected(repo.commit('Commit yo!'));
        assert.isFalse(reporterProxy.addEvent.called);
      });
    });
  });

  describe('getCommit(sha)', function() {
    it('returns the commit information for the provided sha', async function() {
      const workingDirPath = await cloneRepository('multiple-commits');
      const repo = new Repository(workingDirPath);
      await repo.getLoadPromise();

      const commit = await repo.getCommit('18920c900bfa6e4844853e7e246607a31c3e2e8c');

      assert.isTrue(commit.isPresent());
      assert.strictEqual(commit.getSha(), '18920c900bfa6e4844853e7e246607a31c3e2e8c');
      assert.strictEqual(commit.getAuthorEmail(), 'kuychaco@github.com');
      assert.strictEqual(commit.getAuthorDate(), 1471113642);
      assert.lengthOf(commit.getCoAuthors(), 0);
      assert.strictEqual(commit.getMessageSubject(), 'second commit');
      assert.strictEqual(commit.getMessageBody(), '');
    });
  });

  describe('isCommitPushed(sha)', function() {
    it('returns true if SHA is reachable from the upstream ref', async function() {
      const {localRepoPath} = await setUpLocalAndRemoteRepositories('multiple-commits');
      const repository = new Repository(localRepoPath);
      await repository.getLoadPromise();

      const sha = (await repository.getLastCommit()).getSha();
      assert.isTrue(await repository.isCommitPushed(sha));
    });

    it('returns false if SHA is not reachable from upstream', async function() {
      const {localRepoPath} = await setUpLocalAndRemoteRepositories('multiple-commits');
      const repository = new Repository(localRepoPath);
      await repository.getLoadPromise();

      await repository.git.commit('unpushed', {allowEmpty: true});
      repository.refresh();

      const sha = (await repository.getLastCommit()).getSha();
      assert.isFalse(await repository.isCommitPushed(sha));
    });

    it('returns false on a detached HEAD', async function() {
      const workdir = await cloneRepository('multiple-commits');
      const repository = new Repository(workdir);
      await repository.getLoadPromise();

      await repository.checkout('HEAD~2');

      const sha = (await repository.getLastCommit()).getSha();
      assert.isFalse(await repository.isCommitPushed(sha));
    });
  });

  describe('undoLastCommit()', function() {
    it('performs a soft reset', async function() {
      const workingDirPath = await cloneRepository('multiple-commits');
      const repo = new Repository(workingDirPath);
      await repo.getLoadPromise();

      fs.appendFileSync(path.join(workingDirPath, 'file.txt'), 'qqq\n', 'utf8');
      await repo.git.exec(['add', '.']);
      await repo.git.commit('add stuff');

      const parentCommit = await repo.git.getCommit('HEAD~');

      await repo.undoLastCommit();

      const commitAfterReset = await repo.git.getCommit('HEAD');
      assert.strictEqual(commitAfterReset.sha, parentCommit.sha);

      const fp = await repo.getFilePatchForPath('file.txt', {staged: true});
      assert.strictEqual(
        fp.toString(),
        dedent`
          diff --git a/file.txt b/file.txt
          --- a/file.txt
          +++ b/file.txt
          @@ -1,1 +1,2 @@
           three
          +qqq\n
        `,
      );
    });

    it('deletes the HEAD ref when only a single commit is present', async function() {
      const workingDirPath = await cloneRepository('three-files');
      const repo = new Repository(workingDirPath);
      await repo.getLoadPromise();

      fs.appendFileSync(path.join(workingDirPath, 'b.txt'), 'qqq\n', 'utf8');
      await repo.git.exec(['add', '.']);

      await repo.undoLastCommit();

      const fp = await repo.getFilePatchForPath('b.txt', {staged: true});
      assert.strictEqual(
        fp.toString(),
        dedent`
          diff --git a/b.txt b/b.txt
          new file mode 100644
          --- /dev/null
          +++ b/b.txt
          @@ -0,0 +1,2 @@
          +bar
          +qqq\n
        `,
      );
    });

    it('records an event', async function() {
      const workingDirPath = await cloneRepository('multiple-commits');
      const repo = new Repository(workingDirPath);
      await repo.getLoadPromise();

      sinon.stub(reporterProxy, 'addEvent');

      await repo.undoLastCommit();
      assert.isTrue(reporterProxy.addEvent.called);

      const args = reporterProxy.addEvent.lastCall.args;
      assert.deepEqual(args[0], 'undo-last-commit');
      assert.deepEqual(args[1], {package: 'github'});
    });

    it('does not record an event if operation fails', async function() {
      const workingDirPath = await cloneRepository('multiple-commits');
      const repo = new Repository(workingDirPath);
      await repo.getLoadPromise();

      sinon.stub(reporterProxy, 'addEvent');
      sinon.stub(repo.git, 'reset').throws();

      await assert.isRejected(repo.undoLastCommit());
      assert.isFalse(reporterProxy.addEvent.called);
    });
  });

  describe('fetch(branchName, {remoteName})', function() {
    it('brings commits from the remote and updates remote branch, and does not update branch', async function() {
      const {localRepoPath} = await setUpLocalAndRemoteRepositories({remoteAhead: true});
      const localRepo = new Repository(localRepoPath);
      await localRepo.getLoadPromise();

      let remoteHead, localHead;
      remoteHead = await localRepo.git.getCommit('origin/master');
      localHead = await localRepo.git.getCommit('master');
      assert.equal(remoteHead.messageSubject, 'second commit');
      assert.equal(localHead.messageSubject, 'second commit');

      await localRepo.fetch('master');
      remoteHead = await localRepo.git.getCommit('origin/master');
      localHead = await localRepo.git.getCommit('master');
      assert.equal(remoteHead.messageSubject, 'third commit');
      assert.equal(localHead.messageSubject, 'second commit');
    });

    it('accepts a manually specified refspec and remote', async function() {
      const {localRepoPath} = await setUpLocalAndRemoteRepositories({remoteAhead: true});
      const localRepo = new Repository(localRepoPath);
      await localRepo.getLoadPromise();

      let remoteHead, localHead;
      remoteHead = await localRepo.git.getCommit('origin/master');
      localHead = await localRepo.git.getCommit('master');
      assert.strictEqual(remoteHead.messageSubject, 'second commit');
      assert.strictEqual(localHead.messageSubject, 'second commit');

      await localRepo.fetch('+refs/heads/master:refs/somewhere/master', {remoteName: 'origin'});
      remoteHead = await localRepo.git.getCommit('origin/master');
      localHead = await localRepo.git.getCommit('master');
      const fetchHead = await localRepo.git.getCommit('somewhere/master');
      assert.strictEqual(remoteHead.messageSubject, 'third commit');
      assert.strictEqual(localHead.messageSubject, 'second commit');
      assert.strictEqual(fetchHead.messageSubject, 'third commit');
    });

    it('is a noop with neither a manually specified source branch or a tracking branch', async function() {
      const {localRepoPath} = await setUpLocalAndRemoteRepositories({remoteAhead: true});
      const localRepo = new Repository(localRepoPath);
      await localRepo.getLoadPromise();
      await localRepo.checkout('branch', {createNew: true});

      let remoteHead, localHead;
      remoteHead = await localRepo.git.getCommit('origin/master');
      localHead = await localRepo.git.getCommit('branch');
      assert.strictEqual(remoteHead.messageSubject, 'second commit');
      assert.strictEqual(localHead.messageSubject, 'second commit');

      assert.isNull(await localRepo.fetch('branch'));

      remoteHead = await localRepo.git.getCommit('origin/master');
      localHead = await localRepo.git.getCommit('branch');
      assert.strictEqual(remoteHead.messageSubject, 'second commit');
      assert.strictEqual(localHead.messageSubject, 'second commit');
    });
  });

  describe('unsetConfig', function() {
    it('unsets a git config option', async function() {
      const workingDirPath = await cloneRepository('three-files');
      const repository = new Repository(workingDirPath);
      await repository.getLoadPromise();

      await repository.setConfig('some.key', 'value');
      assert.strictEqual(await repository.getConfig('some.key'), 'value');

      await repository.unsetConfig('some.key');
      assert.isNull(await repository.getConfig('some.key'));
    });
  });

  describe('getCommitter', function() {
    it('returns user name and email if they exist', async function() {
      const workingDirPath = await cloneRepository('three-files');
      const repository = new Repository(workingDirPath);
      await repository.getLoadPromise();

      const committer = await repository.getCommitter();
      assert.isTrue(committer.isPresent());
      assert.strictEqual(committer.getFullName(), FAKE_USER.name);
      assert.strictEqual(committer.getEmail(), FAKE_USER.email);
    });

    it('returns a null object if user name or email do not exist', async function() {
      const workingDirPath = await cloneRepository('three-files');
      const repository = new Repository(workingDirPath);
      await repository.getLoadPromise();
      await repository.git.unsetConfig('user.name');
      await repository.git.unsetConfig('user.email');

      // getting the local config for testing purposes only because we don't
      // want to blow away global config when running tests.
      const committer = await repository.getCommitter({local: true});
      assert.isFalse(committer.isPresent());
    });
  });

  describe('getAuthors', function() {
    it('returns user names and emails', async function() {
      const workingDirPath = await cloneRepository('multiple-commits');
      const repository = new Repository(workingDirPath);
      await repository.getLoadPromise();

      await repository.git.exec(['config', 'user.name', 'Mona Lisa']);
      await repository.git.exec(['config', 'user.email', 'mona@lisa.com']);
      await repository.git.commit('Commit from Mona', {allowEmpty: true});

      await repository.git.exec(['config', 'user.name', 'Hubot']);
      await repository.git.exec(['config', 'user.email', 'hubot@github.com']);
      await repository.git.commit('Commit from Hubot', {allowEmpty: true});

      await repository.git.exec(['config', 'user.name', 'Me']);
      await repository.git.exec(['config', 'user.email', 'me@github.com']);
      await repository.git.commit('Commit from me', {allowEmpty: true});

      const authors = await repository.getAuthors({max: 3});
      assert.lengthOf(authors, 3);

      const expected = [
        ['mona@lisa.com', 'Mona Lisa'],
        ['hubot@github.com', 'Hubot'],
        ['me@github.com', 'Me'],
      ];
      for (const [email, fullName] of expected) {
        assert.isTrue(
          authors.some(author => author.getEmail() === email && author.getFullName() === fullName),
          `getAuthors() output includes ${fullName} <${email}>`,
        );
      }
    });
  });

  describe('getRemotes()', function() {
    it('returns an empty RemoteSet before the repository has loaded', async function() {
      const workdir = await cloneRepository('three-files');
      const repository = new Repository(workdir);
      assert.isTrue(repository.isLoading());

      const remotes = await repository.getRemotes();
      assert.isTrue(remotes.isEmpty());
    });

    it('returns a RemoteSet that indexes remotes by name', async function() {
      const workdir = await cloneRepository('three-files');
      const repository = new Repository(workdir);
      await repository.getLoadPromise();

      await repository.setConfig('remote.origin.url', 'git@github.com:smashwilson/atom.git');
      await repository.setConfig('remote.origin.fetch', '+refs/heads/*:refs/remotes/origin/*');

      await repository.setConfig('remote.upstream.url', 'git@github.com:atom/atom.git');
      await repository.setConfig('remote.upstream.fetch', '+refs/heads/*:refs/remotes/upstream/*');

      const remotes = await repository.getRemotes();
      assert.isFalse(remotes.isEmpty());

      const origin = remotes.withName('origin');
      assert.strictEqual(origin.getName(), 'origin');
      assert.strictEqual(origin.getUrl(), 'git@github.com:smashwilson/atom.git');
    });
  });

  describe('addRemote()', function() {
    it('adds a remote to the repository', async function() {
      const workdir = await cloneRepository('three-files');
      const repository = new Repository(workdir);
      await repository.getLoadPromise();

      assert.isFalse((await repository.getRemotes()).withName('ccc').isPresent());

      const remote = await repository.addRemote('ccc', 'git@github.com:aaa/bbb');
      assert.strictEqual(remote.getName(), 'ccc');
      assert.strictEqual(remote.getSlug(), 'aaa/bbb');

      assert.isTrue((await repository.getRemotes()).withName('ccc').isPresent());
    });
  });

  describe('pull()', function() {
    it('updates the remote branch and merges into local branch', async function() {
      const {localRepoPath} = await setUpLocalAndRemoteRepositories({remoteAhead: true});
      const localRepo = new Repository(localRepoPath);
      await localRepo.getLoadPromise();

      let remoteHead, localHead;
      remoteHead = await localRepo.git.getCommit('origin/master');
      localHead = await localRepo.git.getCommit('master');
      assert.equal(remoteHead.messageSubject, 'second commit');
      assert.equal(localHead.messageSubject, 'second commit');

      await localRepo.pull('master');
      remoteHead = await localRepo.git.getCommit('origin/master');
      localHead = await localRepo.git.getCommit('master');
      assert.equal(remoteHead.messageSubject, 'third commit');
      assert.equal(localHead.messageSubject, 'third commit');
    });

    it('only performs a fast-forward merge with ffOnly', async function() {
      const {localRepoPath} = await setUpLocalAndRemoteRepositories({remoteAhead: true});
      const localRepo = new Repository(localRepoPath);
      await localRepo.getLoadPromise();

      await localRepo.commit('fourth commit', {allowEmpty: true});

      let remoteHead, localHead;
      remoteHead = await localRepo.git.getCommit('origin/master');
      localHead = await localRepo.git.getCommit('master');
      assert.equal(remoteHead.messageSubject, 'second commit');
      assert.equal(localHead.messageSubject, 'fourth commit');

      await assert.isRejected(localRepo.pull('master', {ffOnly: true}), /Not possible to fast-forward/);

      remoteHead = await localRepo.git.getCommit('origin/master');
      localHead = await localRepo.git.getCommit('master');
      assert.equal(remoteHead.messageSubject, 'third commit');
      assert.equal(localHead.messageSubject, 'fourth commit');
    });
  });

  describe('push()', function() {
    it('sends commits to the remote and updates', async function() {
      const {localRepoPath, remoteRepoPath} = await setUpLocalAndRemoteRepositories();
      const localRepo = new Repository(localRepoPath);
      await localRepo.getLoadPromise();

      let localHead, localRemoteHead, remoteHead;
      localHead = await localRepo.git.getCommit('master');
      localRemoteHead = await localRepo.git.getCommit('origin/master');
      assert.deepEqual(localHead, localRemoteHead);

      await localRepo.commit('fourth commit', {allowEmpty: true});
      await localRepo.commit('fifth commit', {allowEmpty: true});
      localHead = await localRepo.git.getCommit('master');
      localRemoteHead = await localRepo.git.getCommit('origin/master');
      remoteHead = await getHeadCommitOnRemote(remoteRepoPath);
      assert.notDeepEqual(localHead, remoteHead);
      assert.equal(remoteHead.messageSubject, 'third commit');
      assert.deepEqual(remoteHead, localRemoteHead);

      await localRepo.push('master');
      localHead = await localRepo.git.getCommit('master');
      localRemoteHead = await localRepo.git.getCommit('origin/master');
      remoteHead = await getHeadCommitOnRemote(remoteRepoPath);
      assert.deepEqual(localHead, remoteHead);
      assert.equal(remoteHead.messageSubject, 'fifth commit');
      assert.deepEqual(remoteHead, localRemoteHead);
    });
  });

  describe('getAheadCount(branchName) and getBehindCount(branchName)', function() {
    it('returns the number of commits ahead and behind the remote', async function() {
      const {localRepoPath} = await setUpLocalAndRemoteRepositories({remoteAhead: true});
      const localRepo = new Repository(localRepoPath);
      await localRepo.getLoadPromise();

      assert.equal(await localRepo.getBehindCount('master'), 0);
      assert.equal(await localRepo.getAheadCount('master'), 0);
      await localRepo.fetch('master');
      assert.equal(await localRepo.getBehindCount('master'), 1);
      assert.equal(await localRepo.getAheadCount('master'), 0);
      await localRepo.commit('new commit', {allowEmpty: true});
      await localRepo.commit('another commit', {allowEmpty: true});
      assert.equal(await localRepo.getBehindCount('master'), 1);
      assert.equal(await localRepo.getAheadCount('master'), 2);
    });
  });

  describe('getRemoteForBranch(branchName)', function() {
    it('returns the remote associated to the supplied branch name', async function() {
      const {localRepoPath} = await setUpLocalAndRemoteRepositories({remoteAhead: true});
      const localRepo = new Repository(localRepoPath);
      await localRepo.getLoadPromise();

      const remote0 = await localRepo.getRemoteForBranch('master');
      assert.isTrue(remote0.isPresent());
      assert.equal(remote0.getName(), 'origin');

      await localRepo.git.exec(['remote', 'rename', 'origin', 'foo']);
      localRepo.refresh();

      const remote1 = await localRepo.getRemoteForBranch('master');
      assert.isTrue(remote1.isPresent());
      assert.equal(remote1.getName(), 'foo');

      await localRepo.git.exec(['remote', 'rm', 'foo']);
      localRepo.refresh();

      const remote2 = await localRepo.getRemoteForBranch('master');
      assert.isFalse(remote2.isPresent());
    });
  });

  describe('hasGitHubRemote(host, name, owner)', function() {
    it('returns true if the repo has at least one matching remote', async function() {
      const workdir = await cloneRepository('three-files');
      const repository = new Repository(workdir);
      await repository.getLoadPromise();

      await repository.addRemote('yes0', 'git@github.com:atom/github.git');
      await repository.addRemote('yes1', 'git@github.com:smashwilson/github.git');
      await repository.addRemote('no0', 'https://sourceforge.net/some/repo.git');

      assert.isTrue(await repository.hasGitHubRemote('github.com', 'smashwilson', 'github'));
      assert.isFalse(await repository.hasGitHubRemote('github.com', 'nope', 'no'));
      assert.isFalse(await repository.hasGitHubRemote('github.com', 'some', 'repo'));
    });
  });

  describe('saveDiscardHistory()', function() {
    let repository;

    beforeEach(async function() {
      const workdir = await cloneRepository('three-files');
      repository = new Repository(workdir);
      await repository.getLoadPromise();
    });

    it('does nothing on a destroyed repository', async function() {
      repository.destroy();

      await repository.saveDiscardHistory();

      assert.isNull(await repository.getConfig('atomGithub.historySha'));
    });

    it('does nothing if the repository is destroyed after the blob is created', async function() {
      let resolveCreateHistoryBlob = () => {};
      sinon.stub(repository, 'createDiscardHistoryBlob').callsFake(() => new Promise(resolve => {
        resolveCreateHistoryBlob = resolve;
      }));

      const promise = repository.saveDiscardHistory();
      repository.destroy();
      resolveCreateHistoryBlob('nope');
      await promise;

      assert.isNull(await repository.getConfig('atomGithub.historySha'));
    });

    it('creates a blob and saves it in the git config', async function() {
      assert.isNull(await repository.getConfig('atomGithub.historySha'));
      await repository.saveDiscardHistory();
      assert.match(await repository.getConfig('atomGithub.historySha'), /^[a-z0-9]{40}$/);
    });
  });

  describe('merge conflicts', function() {
    describe('getMergeConflicts()', function() {
      it('returns a promise resolving to an array of MergeConflict objects', async function() {
        const workingDirPath = await cloneRepository('merge-conflict');
        const repo = new Repository(workingDirPath);
        await repo.getLoadPromise();
        await assert.isRejected(repo.git.merge('origin/branch'), /CONFLICT/);

        repo.refresh();
        let mergeConflicts = await repo.getMergeConflicts();
        const expected = [
          {
            filePath: 'added-to-both.txt',
            status: {
              file: 'modified',
              ours: 'added',
              theirs: 'added',
            },
          },
          {
            filePath: 'modified-on-both-ours.txt',
            status: {
              file: 'modified',
              ours: 'modified',
              theirs: 'modified',
            },
          },
          {
            filePath: 'modified-on-both-theirs.txt',
            status: {
              file: 'modified',
              ours: 'modified',
              theirs: 'modified',
            },
          },
          {
            filePath: 'removed-on-branch.txt',
            status: {
              file: 'equivalent',
              ours: 'modified',
              theirs: 'deleted',
            },
          },
          {
            filePath: 'removed-on-master.txt',
            status: {
              file: 'added',
              ours: 'deleted',
              theirs: 'modified',
            },
          },
        ];

        assertDeepPropertyVals(mergeConflicts, expected);

        fs.unlinkSync(path.join(workingDirPath, 'removed-on-branch.txt'));
        repo.refresh();
        mergeConflicts = await repo.getMergeConflicts();
        expected[3].status.file = 'deleted';
        assertDeepPropertyVals(mergeConflicts, expected);
      });

      it('returns an empty array if the repo has no merge conflicts', async function() {
        const workingDirPath = await cloneRepository('three-files');
        const repo = new Repository(workingDirPath);
        await repo.getLoadPromise();

        const mergeConflicts = await repo.getMergeConflicts();
        assert.deepEqual(mergeConflicts, []);
      });
    });

    describe('stageFiles([path])', function() {
      it('updates the staged changes accordingly', async function() {
        const workingDirPath = await cloneRepository('merge-conflict');
        const repo = new Repository(workingDirPath);
        await repo.getLoadPromise();
        await assert.isRejected(repo.git.merge('origin/branch'));

        repo.refresh();
        const mergeConflictPaths = (await repo.getMergeConflicts()).map(c => c.filePath);
        assert.deepEqual(mergeConflictPaths, ['added-to-both.txt', 'modified-on-both-ours.txt', 'modified-on-both-theirs.txt', 'removed-on-branch.txt', 'removed-on-master.txt']);

        let stagedFilePatches = await repo.getStagedChanges();
        assert.deepEqual(stagedFilePatches.map(patch => patch.filePath), []);

        await repo.stageFiles(['added-to-both.txt']);
        repo.refresh();
        stagedFilePatches = await repo.getStagedChanges();
        assert.deepEqual(stagedFilePatches.map(patch => patch.filePath), ['added-to-both.txt']);

        // choose version of the file on head
        fs.writeFileSync(path.join(workingDirPath, 'modified-on-both-ours.txt'), 'master modification\n', 'utf8');
        await repo.stageFiles(['modified-on-both-ours.txt']);
        repo.refresh();
        stagedFilePatches = await repo.getStagedChanges();
        // nothing additional to stage
        assert.deepEqual(stagedFilePatches.map(patch => patch.filePath), ['added-to-both.txt']);

        // choose version of the file on branch
        fs.writeFileSync(path.join(workingDirPath, 'modified-on-both-ours.txt'), 'branch modification\n', 'utf8');
        await repo.stageFiles(['modified-on-both-ours.txt']);
        repo.refresh();
        stagedFilePatches = await repo.getStagedChanges();
        assert.deepEqual(stagedFilePatches.map(patch => patch.filePath), ['added-to-both.txt', 'modified-on-both-ours.txt']);

        // remove file that was deleted on branch
        fs.unlinkSync(path.join(workingDirPath, 'removed-on-branch.txt'));
        await repo.stageFiles(['removed-on-branch.txt']);
        repo.refresh();
        stagedFilePatches = await repo.getStagedChanges();
        assert.deepEqual(stagedFilePatches.map(patch => patch.filePath), ['added-to-both.txt', 'modified-on-both-ours.txt', 'removed-on-branch.txt']);

        // remove file that was deleted on master
        fs.unlinkSync(path.join(workingDirPath, 'removed-on-master.txt'));
        await repo.stageFiles(['removed-on-master.txt']);
        repo.refresh();
        stagedFilePatches = await repo.getStagedChanges();
        // nothing additional to stage
        assert.deepEqual(stagedFilePatches.map(patch => patch.filePath), ['added-to-both.txt', 'modified-on-both-ours.txt', 'removed-on-branch.txt']);
      });
    });

    describe('pathHasMergeMarkers()', function() {
      it('returns true if and only if the file has merge markers', async function() {
        const workingDirPath = await cloneRepository('merge-conflict');
        const repo = new Repository(workingDirPath);
        await repo.getLoadPromise();
        await assert.isRejected(repo.git.merge('origin/branch'));

        assert.isTrue(await repo.pathHasMergeMarkers('added-to-both.txt'));
        assert.isFalse(await repo.pathHasMergeMarkers('removed-on-master.txt'));

        fs.writeFileSync(path.join(workingDirPath, 'file-with-chevrons.txt'), dedent`
          no branch name:
          >>>>>>>
          <<<<<<<

          not enough chevrons:
          >>> HEAD
          <<< branch

          too many chevrons:
          >>>>>>>>> HEAD
          <<<<<<<<< branch

          too many words after chevrons:
          >>>>>>> blah blah blah
          <<<<<<< blah blah blah

          not at line beginning:
          foo >>>>>>> bar
          baz <<<<<<< qux
        `);
        assert.isFalse(await repo.pathHasMergeMarkers('file-with-chevrons.txt'));

        assert.isFalse(await repo.pathHasMergeMarkers('nonexistent-file.txt'));
      });
    });

    it('checks out one side or another', async function() {
      const workingDirPath = await cloneRepository('merge-conflict');
      const repo = new Repository(workingDirPath);
      await repo.getLoadPromise();
      await assert.isRejected(repo.git.merge('origin/branch'));

      repo.refresh();
      assert.isTrue(await repo.pathHasMergeMarkers('modified-on-both-ours.txt'));

      await repo.checkoutSide('ours', ['modified-on-both-ours.txt']);

      assert.isFalse(await repo.pathHasMergeMarkers('modified-on-both-ours.txt'));
    });

    describe('abortMerge()', function() {
      describe('when the working directory is clean', function() {
        it('resets the index and the working directory to match HEAD', async function() {
          const workingDirPath = await cloneRepository('merge-conflict-abort');
          const repo = new Repository(workingDirPath);
          await repo.getLoadPromise();

          await assert.isRejected(repo.git.merge('origin/spanish'));

          assert.equal(await repo.isMerging(), true);
          await repo.abortMerge();
          assert.equal(await repo.isMerging(), false);
        });
      });

      describe('when a dirty file in the working directory is NOT under conflict', function() {
        it('successfully aborts the merge and does not affect the dirty file', async function() {
          const workingDirPath = await cloneRepository('merge-conflict-abort');
          const repo = new Repository(workingDirPath);
          await repo.getLoadPromise();
          await assert.isRejected(repo.git.merge('origin/spanish'));

          fs.writeFileSync(path.join(workingDirPath, 'fruit.txt'), 'a change\n');
          assert.equal(await repo.isMerging(), true);

          await repo.abortMerge();
          assert.equal(await repo.isMerging(), false);
          assert.equal((await repo.getStagedChanges()).length, 0);
          assert.equal((await repo.getUnstagedChanges()).length, 1);
          assert.equal(fs.readFileSync(path.join(workingDirPath, 'fruit.txt')), 'a change\n');
        });
      });

      describe('when a dirty file in the working directory is under conflict', function() {
        it('throws an error indicating that the abort could not be completed', async function() {
          const workingDirPath = await cloneRepository('merge-conflict-abort');
          const repo = new Repository(workingDirPath);
          await repo.getLoadPromise();
          await assert.isRejected(repo.git.merge('origin/spanish'));

          fs.writeFileSync(path.join(workingDirPath, 'animal.txt'), 'a change\n');
          const stagedChanges = await repo.getStagedChanges();
          const unstagedChanges = await repo.getUnstagedChanges();

          assert.equal(await repo.isMerging(), true);
          await assert.isRejected(repo.abortMerge(), /^git merge --abort/);

          assert.equal(await repo.isMerging(), true);
          assert.deepEqual(await repo.getStagedChanges(), stagedChanges);
          assert.deepEqual(await repo.getUnstagedChanges(), unstagedChanges);
        });
      });
    });
  });

  describe('getBlobContents(sha)', function() {
    it('returns blob contents for sha', async function() {
      const workingDirPath = await cloneRepository('three-files');
      const repository = new Repository(workingDirPath);
      await repository.getLoadPromise();

      const sha = await repository.createBlob({stdin: 'aa\nbb\ncc\n'});
      const contents = await repository.getBlobContents(sha);
      assert.strictEqual(contents, 'aa\nbb\ncc\n');
    });
  });

  describe('discardWorkDirChangesForPaths()', function() {
    it('can discard working directory changes in modified files', async function() {
      const workingDirPath = await cloneRepository('three-files');
      const repo = new Repository(workingDirPath);
      await repo.getLoadPromise();

      fs.writeFileSync(path.join(workingDirPath, 'subdir-1', 'a.txt'), 'qux\nfoo\nbar\n', 'utf8');
      fs.writeFileSync(path.join(workingDirPath, 'subdir-1', 'b.txt'), 'qux\nfoo\nbar\n', 'utf8');
      fs.writeFileSync(path.join(workingDirPath, 'new-file.txt'), 'hello there', 'utf8');
      const unstagedChanges = await repo.getUnstagedChanges();

      assert.equal(unstagedChanges.length, 3);
      await repo.discardWorkDirChangesForPaths(unstagedChanges.map(c => c.filePath));
      repo.refresh();
      assert.deepEqual(await repo.getUnstagedChanges(), []);
    });

    it('can discard working directory changes in removed files', async function() {
      const workingDirPath = await cloneRepository('three-files');
      const repo = new Repository(workingDirPath);
      await repo.getLoadPromise();

      fs.unlinkSync(path.join(workingDirPath, 'subdir-1', 'a.txt'));
      fs.unlinkSync(path.join(workingDirPath, 'subdir-1', 'b.txt'));
      const unstagedChanges = await repo.getUnstagedChanges();

      assert.equal(unstagedChanges.length, 2);
      await repo.discardWorkDirChangesForPaths(unstagedChanges.map(c => c.filePath));
      repo.refresh();
      assert.deepEqual(await repo.getUnstagedChanges(), []);
    });

    it('can discard working directory changes added files', async function() {
      const workingDirPath = await cloneRepository('three-files');
      const repo = new Repository(workingDirPath);
      await repo.getLoadPromise();

      fs.writeFileSync(path.join(workingDirPath, 'subdir-1', 'e.txt'), 'qux', 'utf8');
      fs.writeFileSync(path.join(workingDirPath, 'subdir-1', 'f.txt'), 'qux', 'utf8');
      const unstagedChanges = await repo.getUnstagedChanges();

      assert.equal(unstagedChanges.length, 2);
      await repo.discardWorkDirChangesForPaths(unstagedChanges.map(c => c.filePath));
      repo.refresh();
      assert.deepEqual(await repo.getUnstagedChanges(), []);
    });
  });

  describe('maintaining discard history across repository instances', function() {
    it('restores the history', async function() {
      const workingDirPath = await cloneRepository('three-files');
      const repo1 = new Repository(workingDirPath);
      await repo1.getLoadPromise();

      fs.writeFileSync(path.join(workingDirPath, 'a.txt'), 'qux\nfoo\nbar\n', 'utf8');
      fs.writeFileSync(path.join(workingDirPath, 'b.txt'), 'woohoo', 'utf8');
      fs.writeFileSync(path.join(workingDirPath, 'c.txt'), 'yayeah', 'utf8');

      const isSafe = () => true;
      await repo1.storeBeforeAndAfterBlobs(['a.txt'], isSafe, () => {
        fs.writeFileSync(path.join(workingDirPath, 'a.txt'), 'foo\nbar\n', 'utf8');
      }, 'a.txt');
      await repo1.storeBeforeAndAfterBlobs(['b.txt', 'c.txt'], isSafe, () => {
        fs.writeFileSync(path.join(workingDirPath, 'b.txt'), 'woot', 'utf8');
        fs.writeFileSync(path.join(workingDirPath, 'c.txt'), 'yup', 'utf8');
      });
      const repo1HistorySha = await repo1.createDiscardHistoryBlob();

      const repo2 = new Repository(workingDirPath);
      await repo2.getLoadPromise();
      const repo2HistorySha = await repo2.createDiscardHistoryBlob();

      assert.strictEqual(repo2HistorySha, repo1HistorySha);
    });

    it('is resilient to missing history blobs', async function() {
      const workingDirPath = await cloneRepository('three-files');
      const repo1 = new Repository(workingDirPath);
      await repo1.getLoadPromise();
      await repo1.setConfig('atomGithub.historySha', '1111111111111111111111111111111111111111');

      // Should not throw
      await repo1.updateDiscardHistory();

      // Also should not throw
      const repo2 = new Repository(workingDirPath);
      await repo2.getLoadPromise();
    });

    it('passes unexpected git errors to the caller', async function() {
      const workingDirPath = await cloneRepository('three-files');
      const repo = new Repository(workingDirPath);
      await repo.getLoadPromise();
      await repo.setConfig('atomGithub.historySha', '1111111111111111111111111111111111111111');

      repo.refresh();
      sinon.stub(repo.git, 'getBlobContents').rejects(new Error('oh no'));

      await assert.isRejected(repo.updateDiscardHistory(), /oh no/);
    });

    it('is resilient to malformed history blobs', async function() {
      const workingDirPath = await cloneRepository('three-files');
      const repo = new Repository(workingDirPath);
      await repo.getLoadPromise();
      await repo.setConfig('atomGithub.historySha', '1111111111111111111111111111111111111111');

      repo.refresh();
      sinon.stub(repo.git, 'getBlobContents').resolves('lol not JSON');

      // Should not throw
      await repo.updateDiscardHistory();
    });
  });

  describe('cache invalidation', function() {
    // These tests do a *lot* of git operations
    this.timeout(Math.max(20000, this.timeout() * 2));

    const preventDefault = event => event.preventDefault();

    beforeEach(function() {
      window.addEventListener('unhandledrejection', preventDefault);
    });

    afterEach(function() {
      window.removeEventListener('unhandedrejection', preventDefault);
    });

    function filesWithinRepository(repository) {
      const relativePaths = [];

      const descend = async (currentDirectory, relativeBase) => {
        const files = await new Promise((readdirResolve, readdirReject) => {
          return fs.readdir(currentDirectory, (err, result) => {
            if (err) {
              readdirReject(err);
            } else {
              readdirResolve(result);
            }
          });
        });

        const stats = await Promise.all(
          files.map(async file => {
            const stat = await fs.stat(path.join(currentDirectory, file));
            return {file, stat};
          }),
        );

        const subdirs = [];
        for (const {file, stat} of stats) {
          if (stat.isFile()) {
            relativePaths.push(path.join(relativeBase, file));
          }

          if (stat.isDirectory() && file !== '.git') {
            subdirs.push(file);
          }
        }

        return Promise.all(
          subdirs.map(subdir => descend(path.join(currentDirectory, subdir), path.join(relativeBase, subdir))),
        );
      };

      return descend(repository.getWorkingDirectoryPath(), '').then(() => relativePaths);
    }

    async function getCacheReaderMethods(options) {
      const repository = options.repository;
      const calls = new Map();

      calls.set(
        'getStatusBundle',
        () => repository.getStatusBundle(),
      );
      calls.set(
        'getHeadDescription',
        () => repository.getHeadDescription(),
      );
      calls.set(
        'getLastCommit',
        () => repository.getLastCommit(),
      );
      calls.set(
        'getRecentCommits',
        () => repository.getRecentCommits(),
      );
      calls.set(
        'getBranches',
        () => repository.getBranches(),
      );
      calls.set(
        'getRemotes',
        () => repository.getRemotes(),
      );
      calls.set(
        'getStagedChangesPatch',
        () => repository.getStagedChangesPatch(),
      );

      const withFile = fileName => {
        calls.set(
          `getFilePatchForPath {unstaged} ${fileName}`,
          () => repository.getFilePatchForPath(fileName, {staged: false}),
        );
        calls.set(
          `getFilePatchForPath {staged} ${fileName}`,
          () => repository.getFilePatchForPath(fileName, {staged: true}),
        );
        calls.set(
          `getDiffsForFilePath ${fileName}`,
          () => repository.getDiffsForFilePath(fileName, 'HEAD^'),
        );
        calls.set(
          `readFileFromIndex ${fileName}`,
          () => repository.readFileFromIndex(fileName),
        );
      };

      for (const fileName of await filesWithinRepository(options.repository)) {
        withFile(fileName);
      }

      for (const optionName of (options.optionNames || [])) {
        calls.set(
          `getConfig ${optionName}`,
          () => repository.getConfig(optionName),
        );
        calls.set(
          `getConfig {local} ${optionName}`,
          () => repository.getConfig(optionName, {local: true}),
        );
      }

      return calls;
    }

    /**
     * Ensure that the correct cache keys are invalidated by a Repository operation.
     */
    async function assertCorrectInvalidation(options, operation) {
      const methods = await getCacheReaderMethods(options);
      for (const opName of (options.skip || [])) {
        methods.delete(opName);
      }

      const record = async () => {
        const results = new Map();

        for (const [name, call] of methods) {
          const promise = call();
          results.set(name, promise);
          if (process.platform === 'win32') {
            await promise.catch(() => {});
          }
        }

        return results;
      };

      const invalidatedKeys = (mapA, mapB) => {
        const allKeys = Array.from(mapA.keys());
        assert.sameMembers(allKeys, Array.from(mapB.keys()));

        return new Set(
          allKeys.filter(key => mapA.get(key) !== mapB.get(key)),
        );
      };

      const changedKeys = async (mapA, mapB) => {
        const allKeys = Array.from(mapA.keys());
        assert.sameMembers(allKeys, Array.from(mapB.keys()));

        const syncResults = await Promise.all(
          allKeys.map(async key => {
            return {
              key,
              aSync: await mapA.get(key).catch(e => e),
              bSync: await mapB.get(key).catch(e => e),
            };
          }),
        );

        return new Set(
          syncResults
            .filter(({aSync, bSync}) => {
              // Recursively compare synchronous results. If an "isEqual" method is defined on any model, defer to
              // its definition of equality.
              return !isEqualWith(aSync, bSync, (a, b) => {
                if (a && a.isEqual) {
                  return a.isEqual(b);
                }

                return undefined;
              });
            })
            .map(({key}) => key),
        );
      };

      const before = await record();
      await operation();
      const cached = await record();

      options.repository.state.cache.clear();
      const after = await record();

      const expected = await changedKeys(before, after);
      const actual = invalidatedKeys(before, cached);
      const {added, removed} = compareSets(expected, actual);

      if (options.expected) {
        for (const opName of options.expected) {
          added.delete(opName);
        }
      }

      /* eslint-disable no-console */
      if (added.size > 0 && (options.strict || options.verbose)) {
        console.log('These cached method results were invalidated, but should not have been:');

        for (const key of added) {
          console.log(` ${key}:`);
          console.log('  before:', before.get(key));
          console.log('  cached:', cached.get(key));
          console.log('   after:', after.get(key));
        }
      }

      if (removed.size > 0) {
        console.log('These cached method results should have been invalidated, but were not:');
        for (const key of removed) {
          console.log(` ${key}:`);
          console.log('  before:', before.get(key));
          console.log('  cached:', cached.get(key));
          console.log('   after:', after.get(key));
        }
      }
      /* eslint-enable no-console */

      if (options.strict) {
        assert.isTrue(added.size === 0 && removed.size === 0, 'invalidated different method results');
      } else {
        assert.isTrue(removed.size === 0, 'bzzzt, inadequate cache busting detected');
      }
    }

    describe('from method calls', function() {
      it('when staging files', async function() {
        const workdir = await cloneRepository('multi-commits-files');
        const repository = new Repository(workdir);
        await repository.getLoadPromise();

        await fs.writeFile(path.join(workdir, 'a.txt'), 'bar\nbar-1\n', {encoding: 'utf8'});

        await assertCorrectInvalidation({repository}, async () => {
          await repository.stageFiles(['a.txt']);
        });
      });

      it('when unstaging files', async function() {
        const workdir = await cloneRepository('multi-commits-files');
        const repository = new Repository(workdir);
        await repository.getLoadPromise();

        await fs.writeFile(path.join(workdir, 'a.txt'), 'bar\nbaz\n', {encoding: 'utf8'});
        await repository.stageFiles(['a.txt']);

        await assertCorrectInvalidation({repository}, async () => {
          await repository.unstageFiles(['a.txt']);
        });
      });

      it('when staging files from a parent commit', async function() {
        const workdir = await cloneRepository('multi-commits-files');
        const repository = new Repository(workdir);
        await repository.getLoadPromise();

        await fs.writeFile(path.join(workdir, 'a.txt'), 'bar\nbaz\n', {encoding: 'utf8'});
        await repository.stageFiles(['a.txt']);

        await assertCorrectInvalidation({repository}, async () => {
          await repository.stageFilesFromParentCommit(['a.txt']);
        });
      });

      it('when applying a patch to the index', async function() {
        const workdir = await cloneRepository('multi-commits-files');
        const repository = new Repository(workdir);
        await repository.getLoadPromise();

        await fs.writeFile(path.join(workdir, 'a.txt'), 'foo\nfoo-1\n', {encoding: 'utf8'});
        const patch = await repository.getFilePatchForPath('a.txt');
        await fs.writeFile(path.join(workdir, 'a.txt'), 'foo\nfoo-1\nfoo-2\n', {encoding: 'utf8'});

        await assertCorrectInvalidation({repository}, async () => {
          await repository.applyPatchToIndex(patch);
        });
      });

      it('when applying a patch to the working directory', async function() {
        const workdir = await cloneRepository('multi-commits-files');
        const repository = new Repository(workdir);
        await repository.getLoadPromise();

        await fs.writeFile(path.join(workdir, 'a.txt'), 'foo\nfoo-1\n', {encoding: 'utf8'});
        const patch = (await repository.getFilePatchForPath('a.txt')).getUnstagePatchForLines(new Set([0, 1]));

        await assertCorrectInvalidation({repository}, async () => {
          await repository.applyPatchToWorkdir(patch);
        });
      });

      it('when committing', async function() {
        const workdir = await cloneRepository('multi-commits-files');
        const repository = new Repository(workdir);
        await repository.getLoadPromise();

        await fs.writeFile(path.join(workdir, 'b.txt'), 'foo\nfoo-1\nfoo-2\n', {encoding: 'utf8'});
        await repository.stageFiles(['b.txt']);

        await assertCorrectInvalidation({repository}, async () => {
          await repository.commit('message');
        });
      });

      it('when merging', async function() {
        const workdir = await cloneRepository('merge-conflict');
        const repository = new Repository(workdir);
        await repository.getLoadPromise();

        await assertCorrectInvalidation({repository}, async () => {
          await assert.isRejected(repository.merge('origin/branch'));
        });
      });

      it('when aborting a merge', async function() {
        const workdir = await cloneRepository('merge-conflict');
        const repository = new Repository(workdir);
        await repository.getLoadPromise();
        await assert.isRejected(repository.merge('origin/branch'));

        await repository.stageFiles(['modified-on-both-ours.txt']);

        await assertCorrectInvalidation({repository}, async () => {
          await repository.abortMerge();
        });
      });

      it('when writing a merge conflict to the index', async function() {
        const workdir = await cloneRepository('multi-commits-files');
        const repository = new Repository(workdir);
        await repository.getLoadPromise();

        const fullPath = path.join(workdir, 'a.txt');
        await fs.writeFile(fullPath, 'qux\nfoo\nbar\n', {encoding: 'utf8'});
        await repository.git.exec(['update-index', '--chmod=+x', 'a.txt']);

        const commonBaseSha = '7f95a814cbd9b366c5dedb6d812536dfef2fffb7';
        const oursSha = '95d4c5b7b96b3eb0853f586576dc8b5ac54837e0';
        const theirsSha = '5da808cc8998a762ec2761f8be2338617f8f12d9';

        await assertCorrectInvalidation({repository}, async () => {
          await repository.writeMergeConflictToIndex('a.txt', commonBaseSha, oursSha, theirsSha);
        });
      });

      it('when checking out a revision', async function() {
        const workdir = await cloneRepository('multi-commits-files');
        const repository = new Repository(workdir);
        await repository.getLoadPromise();

        await assertCorrectInvalidation({repository}, async () => {
          await repository.checkout('HEAD^');
        });
      });

      it('when checking out paths', async function() {
        const workdir = await cloneRepository('multi-commits-files');
        const repository = new Repository(workdir);
        await repository.getLoadPromise();

        await assertCorrectInvalidation({repository}, async () => {
          await repository.checkoutPathsAtRevision(['b.txt'], 'HEAD^');
        });
      });

      it('when fetching', async function() {
        const {localRepoPath} = await setUpLocalAndRemoteRepositories();
        const repository = new Repository(localRepoPath);
        await repository.getLoadPromise();

        await repository.commit('wat', {allowEmpty: true});
        await repository.commit('huh', {allowEmpty: true});

        await assertCorrectInvalidation({repository}, async () => {
          await repository.fetch('master');
        });
      });

      it('when pulling', async function() {
        const {localRepoPath} = await setUpLocalAndRemoteRepositories({remoteAhead: true});
        const repository = new Repository(localRepoPath);
        await repository.getLoadPromise();

        await fs.writeFile(path.join(localRepoPath, 'new-file.txt'), 'one\n', {encoding: 'utf8'});
        await repository.stageFiles(['new-file.txt']);
        await repository.commit('wat');

        await assertCorrectInvalidation({repository}, async () => {
          await repository.pull('master');
        });
      });

      it('when pushing', async function() {
        const {localRepoPath} = await setUpLocalAndRemoteRepositories();
        const repository = new Repository(localRepoPath);
        await repository.getLoadPromise();

        await fs.writeFile(path.join(localRepoPath, 'new-file.txt'), 'one\n', {encoding: 'utf8'});
        await repository.stageFiles(['new-file.txt']);
        await repository.commit('wat');

        await assertCorrectInvalidation({repository}, async () => {
          await repository.push('master');
        });
      });

      it('when setting a config option', async function() {
        const workdir = await cloneRepository('multi-commits-files');
        const repository = new Repository(workdir);
        await repository.getLoadPromise();

        const optionNames = ['core.editor', 'color.ui'];
        await assertCorrectInvalidation({repository, optionNames}, async () => {
          await repository.setConfig('core.editor', 'atom --wait #obvs');
        });
      });

      it('when discarding working directory changes', async function() {
        const workdir = await cloneRepository('multi-commits-files');
        const repository = new Repository(workdir);
        await repository.getLoadPromise();

        await Promise.all([
          fs.writeFile(path.join(workdir, 'a.txt'), 'aaa\n', {encoding: 'utf8'}),
          fs.writeFile(path.join(workdir, 'c.txt'), 'baz\n', {encoding: 'utf8'}),
        ]);

        await assertCorrectInvalidation({repository}, async () => {
          await repository.discardWorkDirChangesForPaths(['a.txt', 'c.txt']);
        });
      });

      it('when adding a remote', async function() {
        const workdir = await cloneRepository('multi-commits-files');
        const repository = new Repository(workdir);
        await repository.getLoadPromise();

        const optionNames = ['core.editor', 'remotes.aaa.fetch', 'remotes.aaa.url'];
        await assertCorrectInvalidation({repository, optionNames}, async () => {
          await repository.addRemote('aaa', 'git@github.com:aaa/bbb.git');
        });
      });
    });

    describe('from filesystem events', function() {
      let sub;

      afterEach(function() {
        sub && sub.dispose();
      });

      it('when staging files', async function() {
        const {repository, observer, subscriptions} = await wireUpObserver();
        sub = subscriptions;

        await fs.writeFile(path.join(repository.getWorkingDirectoryPath(), 'a.txt'), 'boop\n', {encoding: 'utf8'});

        await assertCorrectInvalidation({repository}, async () => {
          await observer.start();
          await repository.git.stageFiles(['a.txt']);
          await expectEvents(repository, path.join('.git', 'index'));
        });
      });

      it('when unstaging files', async function() {
        const {repository, observer, subscriptions} = await wireUpObserver();
        sub = subscriptions;

        await fs.writeFile(path.join(repository.getWorkingDirectoryPath(), 'a.txt'), 'boop\n', {encoding: 'utf8'});
        await repository.git.stageFiles(['a.txt']);

        await assertCorrectInvalidation({repository}, async () => {
          await observer.start();
          await repository.git.unstageFiles(['a.txt']);
          await expectEvents(repository, path.join('.git', 'index'));
        });
      });

      it('when staging files from a parent commit', async function() {
        const {repository, observer, subscriptions} = await wireUpObserver();
        sub = subscriptions;

        await assertCorrectInvalidation({repository}, async () => {
          await observer.start();
          await repository.git.unstageFiles(['a.txt'], 'HEAD~');
          await expectEvents(repository, path.join('.git', 'index'));
        });
      });

      it('when applying a patch to the index', async function() {
        const {repository, observer, subscriptions} = await wireUpObserver();
        sub = subscriptions;

        await fs.writeFile(path.join(repository.getWorkingDirectoryPath(), 'a.txt'), 'boop\n', {encoding: 'utf8'});
        const patch = await repository.getFilePatchForPath('a.txt');

        await assertCorrectInvalidation({repository}, async () => {
          await observer.start();
          await repository.git.applyPatch(patch.toString(), {index: true});
          await expectEvents(
            repository,
            path.join('.git', 'index'),
          );
        });
      });

      it('when applying a patch to the working directory', async function() {
        const {repository, observer, subscriptions} = await wireUpObserver();
        sub = subscriptions;

        await fs.writeFile(path.join(repository.getWorkingDirectoryPath(), 'a.txt'), 'boop\n', {encoding: 'utf8'});
        const patch = (await repository.getFilePatchForPath('a.txt')).getUnstagePatchForLines(new Set([0]));

        await assertCorrectInvalidation({repository}, async () => {
          await observer.start();
          await repository.git.applyPatch(patch.toString());
          await expectEvents(
            repository,
            'a.txt',
          );
        });
      });

      it('when committing', async function() {
        const {repository, observer, subscriptions} = await wireUpObserver();
        sub = subscriptions;

        await fs.writeFile(path.join(repository.getWorkingDirectoryPath(), 'a.txt'), 'boop\n', {encoding: 'utf8'});
        await repository.stageFiles(['a.txt']);

        await assertCorrectInvalidation({repository}, async () => {
          await observer.start();
          await repository.git.commit('boop your snoot');
          await expectEvents(
            repository,
            path.join('.git', 'index'),
            path.join('.git', 'refs', 'heads', 'master'),
          );
        });
      });

      it('when merging', async function() {
        const {repository, observer, subscriptions} = await wireUpObserver('merge-conflict');
        sub = subscriptions;

        await assertCorrectInvalidation({repository}, async () => {
          await observer.start();
          await assert.isRejected(repository.git.merge('origin/branch'));
          await expectEvents(
            repository,
            path.join('.git', 'index'),
            'modified-on-both-ours.txt',
            path.join('.git', 'MERGE_HEAD'),
          );
        });
      });

      it('when aborting a merge', async function() {
        const {repository, observer, subscriptions} = await wireUpObserver('merge-conflict');
        sub = subscriptions;
        await assert.isRejected(repository.merge('origin/branch'));

        await assertCorrectInvalidation({repository}, async () => {
          await observer.start();
          await repository.git.abortMerge();
          await expectEvents(
            repository,
            path.join('.git', 'index'),
            'modified-on-both-ours.txt',
            path.join('.git', 'MERGE_HEAD'),
          );
        });
      });

      it('when checking out a revision', async function() {
        // Known flake: https://github.com/atom/github/issues/1958
        this.retries(5);

        const {repository, observer, subscriptions} = await wireUpObserver();
        sub = subscriptions;

        await assertCorrectInvalidation({repository}, async () => {
          await observer.start();
          await repository.git.checkout('HEAD^');
          await expectEvents(
            repository,
            path.join('.git', 'index'),
            path.join('.git', 'HEAD'),
            'b.txt',
            'c.txt',
          );
        });
      });

      it('when checking out paths', async function() {
        const {repository, observer, subscriptions} = await wireUpObserver();
        sub = subscriptions;

        await assertCorrectInvalidation({repository}, async () => {
          await observer.start();
          await repository.git.checkoutFiles(['b.txt'], 'HEAD^');
          await expectEvents(
            repository,
            'b.txt',
            path.join('.git', 'index'),
          );
        });
      });

      it('when fetching', async function() {
        const {localRepoPath} = await setUpLocalAndRemoteRepositories({remoteAhead: true});
        const {repository, observer, subscriptions} = await wireUpObserver(null, localRepoPath);
        sub = subscriptions;

        await repository.commit('wat', {allowEmpty: true});
        await repository.commit('huh', {allowEmpty: true});

        await assertCorrectInvalidation({repository}, async () => {
          await observer.start();
          await repository.git.fetch('origin', 'master');
          await expectEvents(
            repository,
            path.join('.git', 'refs', 'remotes', 'origin', 'master'),
          );
        });
      });

      it('when pulling', async function() {
        const {localRepoPath} = await setUpLocalAndRemoteRepositories({remoteAhead: true});
        const {repository, observer, subscriptions} = await wireUpObserver(null, localRepoPath);
        sub = subscriptions;

        await fs.writeFile(path.join(localRepoPath, 'file.txt'), 'one\n', {encoding: 'utf8'});
        await repository.stageFiles(['file.txt']);
        await repository.commit('wat');

        await assertCorrectInvalidation({repository}, async () => {
          await observer.start();
          await assert.isRejected(repository.git.pull('origin', 'master'));
          await expectEvents(
            repository,
            'file.txt',
            path.join('.git', 'refs', 'remotes', 'origin', 'master'),
            path.join('.git', 'MERGE_HEAD'),
            path.join('.git', 'index'),
          );
        });
      });

      it('when pushing', async function() {
        const {localRepoPath} = await setUpLocalAndRemoteRepositories();
        const {repository, observer, subscriptions} = await wireUpObserver(null, localRepoPath);
        sub = subscriptions;

        await fs.writeFile(path.join(localRepoPath, 'new-file.txt'), 'one\n', {encoding: 'utf8'});
        await repository.stageFiles(['new-file.txt']);
        await repository.commit('wat');

        await assertCorrectInvalidation({repository}, async () => {
          await observer.start();
          await repository.git.push('origin', 'master');
          await expectEvents(
            repository,
            path.join('.git', 'refs', 'remotes', 'origin', 'master'),
          );
        });
      });

      it('when setting a config option', async function() {
        const {repository, observer, subscriptions} = await wireUpObserver();
        sub = subscriptions;

        const optionNames = ['core.editor', 'color.ui'];
        await assertCorrectInvalidation({repository, optionNames}, async () => {
          await observer.start();
          await repository.git.setConfig('core.editor', 'ed # :trollface:');
          await expectEvents(
            repository,
            path.join('.git', 'config'),
          );
        });
      });

      it('when changing files in the working directory', async function() {
        const {repository, observer, subscriptions} = await wireUpObserver();
        sub = subscriptions;

        await assertCorrectInvalidation({repository}, async () => {
          await observer.start();
          await fs.writeFile(path.join(repository.getWorkingDirectoryPath(), 'b.txt'), 'new contents\n', {encoding: 'utf8'});
          await expectEvents(
            repository,
            'b.txt',
          );
        });
      });
    });

    it('manually invalidates some keys when the WorkspaceChangeObserver indicates the window is focused', async function() {
      const workdir = await cloneRepository('three-files');
      const repository = new Repository(workdir);
      await repository.getLoadPromise();

      const readerMethods = await getCacheReaderMethods({repository});
      function readerValues() {
        return new Map(
          Array.from(readerMethods.entries(), ([name, call]) => {
            const promise = call();
            if (process.platform === 'win32') {
              promise.catch(() => {});
            }
            return [name, promise];
          }),
        );
      }

      const before = readerValues();
      repository.observeFilesystemChange([{special: FOCUS}]);
      const after = readerValues();

      const invalidated = Array.from(readerMethods.keys()).filter(key => before.get(key) !== after.get(key));

      assert.sameMembers(invalidated, [
        'getStatusBundle',
        'getFilePatchForPath {unstaged} a.txt',
        'getFilePatchForPath {unstaged} b.txt',
        'getFilePatchForPath {unstaged} c.txt',
        `getFilePatchForPath {unstaged} ${path.join('subdir-1/a.txt')}`,
        `getFilePatchForPath {unstaged} ${path.join('subdir-1/b.txt')}`,
        `getFilePatchForPath {unstaged} ${path.join('subdir-1/c.txt')}`,
        'getDiffsForFilePath a.txt',
        'getDiffsForFilePath b.txt',
        'getDiffsForFilePath c.txt',
        `getDiffsForFilePath ${path.join('subdir-1/a.txt')}`,
        `getDiffsForFilePath ${path.join('subdir-1/b.txt')}`,
        `getDiffsForFilePath ${path.join('subdir-1/c.txt')}`,
      ]);
    });
  });

  describe('commit message', function() {
    let sub;

    afterEach(function() {
      sub && sub.dispose();
    });

    describe('initial state', function() {
      let workdir;

      beforeEach(async function() {
        workdir = await cloneRepository();
      });

      it('is initialized to the merge message if one is present', async function() {
        await fs.writeFile(path.join(workdir, '.git/MERGE_MSG'), 'sup', {encoding: 'utf8'});

        const repository = new Repository(workdir);
        await repository.getLoadPromise();

        await assert.async.strictEqual(repository.getCommitMessage(), 'sup');
      });

      it('is initialized to the commit message template if one is present', async function() {
        await fs.writeFile(path.join(workdir, 'template'), 'hai', {encoding: 'utf8'});
        await CompositeGitStrategy.create(workdir).setConfig('commit.template', path.join(workdir, 'template'));

        const repository = new Repository(workdir);
        await repository.getLoadPromise();
        await new Promise(resolve => {
          sub = repository.onDidUpdate(() => {
            sub.dispose();
            resolve();
          });
        });

        await assert.async.strictEqual(repository.getCommitMessage(), 'hai');
      });
    });

    describe('update broadcast', function() {
      it('broadcasts an update when set', async function() {
        const repository = new Repository(await cloneRepository());
        await repository.getLoadPromise();
        const didUpdate = sinon.spy();
        sub = repository.onDidUpdate(didUpdate);

        repository.setCommitMessage('new message');
        assert.isTrue(didUpdate.called);
      });

      it('may suppress the update when set', async function() {
        const repository = new Repository(await cloneRepository());
        await repository.getLoadPromise();
        const didUpdate = sinon.spy();
        sub = repository.onDidUpdate(didUpdate);

        repository.setCommitMessage('quietly now', {suppressUpdate: true});
        assert.isFalse(didUpdate.called);
      });
    });

    describe('updateCommitMessageAfterFileSystemChange', function() {
      it('handles events with no `path` property', async function() {
        const {repository} = await wireUpObserver();

        // sometimes we all lose our path in life.
        const eventWithNoPath = {};
        try {
          await repository.updateCommitMessageAfterFileSystemChange([eventWithNoPath]);
          // this is a little jank but we want to test that the code does not throw an error
          // and chai's promise assertions did not work when we negated our assertion.
        } catch (e) {
          throw e;
        }
      });
    });

    describe('config commit.template change', function() {
      it('updates commit messages to new template', async function() {
        const {repository, observer, subscriptions} = await wireUpObserver();
        sub = subscriptions;
        await observer.start();

        assert.strictEqual(repository.getCommitMessage(), '');

        const templatePath = path.join(repository.getWorkingDirectoryPath(), 'a.txt');
        await repository.git.setConfig('commit.template', templatePath);
        await expectEvents(
          repository,
          path.join('.git', 'config'),
        );
        await assert.async.strictEqual(repository.getCommitMessage(), fs.readFileSync(templatePath, 'utf8'));
      });

      it('leaves the commit message alone if the template content did not change', async function() {
        const {repository, observer, subscriptions} = await wireUpObserver();
        sub = subscriptions;
        await observer.start();

        const templateOnePath = path.join(repository.getWorkingDirectoryPath(), 'the-template-0.txt');
        const templateTwoPath = path.join(repository.getWorkingDirectoryPath(), 'the-template-1.txt');
        const templateContent = 'the same';

        await Promise.all(
          [templateOnePath, templateTwoPath].map(p => fs.writeFile(p, templateContent, {encoding: 'utf8'})),
        );

        await repository.git.setConfig('commit.template', templateOnePath);
        await expectEvents(repository, path.join('.git', 'config'));
        await assert.async.strictEqual(repository.getCommitMessage(), 'the same');

        repository.setCommitMessage('different');

        await repository.git.setConfig('commit.template', templateTwoPath);
        await expectEvents(repository, path.join('.git', 'config'));
        assert.strictEqual(repository.getCommitMessage(), 'different');
      });

      it('updates commit message to empty string if commit.template is unset', async function() {
        const {repository, observer, subscriptions} = await wireUpObserver();
        sub = subscriptions;
        await observer.start();

        assert.strictEqual(repository.getCommitMessage(), '');

        const templatePath = path.join(repository.getWorkingDirectoryPath(), 'a.txt');
        await repository.git.setConfig('commit.template', templatePath);
        await expectEvents(
          repository,
          path.join('.git', 'config'),
        );

        await assert.async.strictEqual(repository.getCommitMessage(), fs.readFileSync(templatePath, 'utf8'));

        await repository.git.unsetConfig('commit.template');

        await expectEvents(
          repository,
          path.join('.git', 'config'),
        );
        await assert.async.strictEqual(repository.getCommitMessage(), '');
      });
    });

    describe('merge events', function() {
      describe('when commit message is empty', function() {
        it('merge message is set as new commit message', async function() {
          const {repository, observer, subscriptions} = await wireUpObserver('merge-conflict');
          sub = subscriptions;
          await observer.start();

          assert.strictEqual(repository.getCommitMessage(), '');
          await assert.isRejected(repository.git.merge('origin/branch'));
          await expectEvents(
            repository,
            path.join('.git', 'MERGE_HEAD'),
          );
          await assert.async.strictEqual(repository.getCommitMessage(), await repository.getMergeMessage());
        });
      });

      describe('when commit message contains unmodified template', function() {
        it('merge message is set as new commit message', async function() {
          const {repository, observer, subscriptions} = await wireUpObserver('merge-conflict');
          sub = subscriptions;
          await observer.start();

          const templatePath = path.join(repository.getWorkingDirectoryPath(), 'added-to-both.txt');
          const templateText = fs.readFileSync(templatePath, 'utf8');
          await repository.git.setConfig('commit.template', templatePath);
          await expectEvents(
            repository,
            path.join('.git', 'config'),
          );

          await assert.async.strictEqual(repository.getCommitMessage(), templateText);

          await assert.isRejected(repository.git.merge('origin/branch'));
          await expectEvents(
            repository,
            path.join('.git', 'MERGE_HEAD'),
          );
          await assert.async.strictEqual(repository.getCommitMessage(), await repository.getMergeMessage());
        });
      });

      describe('when commit message is "dirty"', function() {
        it('leaves commit message as is', async function() {
          const {repository, observer, subscriptions} = await wireUpObserver('merge-conflict');
          sub = subscriptions;
          await observer.start();

          const dirtyMessage = 'foo bar baz';
          repository.setCommitMessage(dirtyMessage);
          await assert.isRejected(repository.git.merge('origin/branch'));
          await expectEvents(
            repository,
            path.join('.git', 'MERGE_HEAD'),
          );
          assert.strictEqual(repository.getCommitMessage(), dirtyMessage);
        });
      });

      describe('when merge is aborted', function() {
        it('merge message gets cleared', async function() {
          const {repository, observer, subscriptions} = await wireUpObserver('merge-conflict');
          sub = subscriptions;
          await observer.start();
          await assert.isRejected(repository.git.merge('origin/branch'));
          await expectEvents(
            repository,
            path.join('.git', 'MERGE_HEAD'),
          );
          await assert.async.strictEqual(repository.getCommitMessage(), await repository.getMergeMessage());

          await repository.abortMerge();
          await expectEvents(
            repository,
            path.join('.git', 'MERGE_HEAD'),
          );
          assert.strictEqual(repository.getCommitMessage(), '');

        });

        describe('when commit message template is present', function() {
          it('sets template as commit message', async function() {
            const {repository, observer, subscriptions} = await wireUpObserver('merge-conflict');
            sub = subscriptions;
            await observer.start();

            const templatePath = path.join(repository.getWorkingDirectoryPath(), 'added-to-both.txt');
            const templateText = fs.readFileSync(templatePath, 'utf8');
            await repository.git.setConfig('commit.template', templatePath);
            await expectEvents(
              repository,
              path.join('.git', 'config'),
            );

            await assert.isRejected(repository.git.merge('origin/branch'));
            await expectEvents(
              repository,
              path.join('.git', 'MERGE_HEAD'),
            );
            await assert.async.strictEqual(repository.getCommitMessage(), await repository.getMergeMessage());

            await repository.abortMerge();
            await expectEvents(
              repository,
              path.join('.git', 'MERGE_HEAD'),
            );

            await assert.async.strictEqual(repository.getCommitMessage(), templateText);
          });
        });
      });
    });
  });
});
