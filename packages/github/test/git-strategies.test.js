import fs from 'fs-extra';
import path from 'path';
import http from 'http';
import os from 'os';

import mkdirp from 'mkdirp';
import dedent from 'dedent-js';
import hock from 'hock';
import {GitProcess} from 'dugite';

import CompositeGitStrategy from '../lib/composite-git-strategy';
import GitShellOutStrategy, {LargeRepoError} from '../lib/git-shell-out-strategy';
import WorkerManager from '../lib/worker-manager';
import Author from '../lib/models/author';

import {cloneRepository, initRepository, assertDeepPropertyVals, setUpLocalAndRemoteRepositories} from './helpers';
import {normalizeGitHelperPath, getTempDir} from '../lib/helpers';
import * as reporterProxy from '../lib/reporter-proxy';

/**
 * KU Thoughts: The GitShellOutStrategy methods are tested in Repository tests for the most part
 *  For now, in order to minimize duplication, I'll limit test coverage here to methods that produce
 *  output that we rely on, to serve as documentation
 */

[
  [GitShellOutStrategy],
].forEach(function(strategies) {
  const createTestStrategy = (...args) => {
    return CompositeGitStrategy.withStrategies(strategies)(...args);
  };

  describe(`Git commands for CompositeGitStrategy made of [${strategies.map(s => s.name).join(', ')}]`, function() {
    describe('exec', function() {
      let git, incrementCounterStub;

      beforeEach(async function() {
        const workingDir = await cloneRepository();
        git = createTestStrategy(workingDir);
        incrementCounterStub = sinon.stub(reporterProxy, 'incrementCounter');
      });

      describe('when the WorkerManager is not ready or disabled', function() {
        beforeEach(function() {
          sinon.stub(WorkerManager.getInstance(), 'isReady').returns(false);
        });

        it('kills the git process when cancel is triggered by the prompt server', async function() {
          const promptStub = sinon.stub().rejects();
          git.setPromptCallback(promptStub);

          const stdin = dedent`
            host=noway.com
            username=me

          `;
          await git.exec(['credential', 'fill'], {useGitPromptServer: true, stdin});

          assert.isTrue(promptStub.called);
        });
      });

      it('rejects if the process fails to spawn for an unexpected reason', async function() {
        sinon.stub(git, 'executeGitCommand').returns({promise: Promise.reject(new Error('wat'))});
        await assert.isRejected(git.exec(['version']), /wat/);
      });

      it('does not call incrementCounter when git command is on the ignore list', async function() {
        await git.exec(['status']);
        assert.equal(incrementCounterStub.callCount, 0);
      });

      it('does call incrementCounter when git command is NOT on the ignore list', async function() {
        await git.exec(['commit', '--allow-empty', '-m', 'make an empty commit']);

        assert.equal(incrementCounterStub.callCount, 1);
        assert.deepEqual(incrementCounterStub.lastCall.args, ['commit']);
      });
    });

    // https://github.com/atom/github/issues/1051
    // https://github.com/atom/github/issues/898
    it('passes all environment variables to spawned git process', async function() {
      const workingDirPath = await cloneRepository('three-files');
      const git = createTestStrategy(workingDirPath);

      // dugite copies the env for us, so this is only an issue when using a Renderer process
      await WorkerManager.getInstance().getReadyPromise();

      const hookContent = dedent`
        #!/bin/sh

        if [ "$ALLOWCOMMIT" != "true" ]
        then
          echo "cannot commit. set \\$ALLOWCOMMIT to 'true'"
          exit 1
        fi
      `;

      const hookPath = path.join(workingDirPath, '.git', 'hooks', 'pre-commit');
      await fs.writeFile(hookPath, hookContent, {encoding: 'utf8'});
      fs.chmodSync(hookPath, 0o755);

      delete process.env.ALLOWCOMMIT;
      await assert.isRejected(git.exec(['commit', '--allow-empty', '-m', 'commit yo']), /ALLOWCOMMIT/);

      process.env.ALLOWCOMMIT = 'true';
      await git.exec(['commit', '--allow-empty', '-m', 'commit for real']);
    });

    describe('resolveDotGitDir', function() {
      it('returns the path to the .git dir for a working directory if it exists, and null otherwise', async function() {
        const workingDirPath = await cloneRepository('three-files');
        const git = createTestStrategy(workingDirPath);
        const dotGitFolder = await git.resolveDotGitDir(workingDirPath);
        assert.equal(dotGitFolder, path.join(workingDirPath, '.git'));

        fs.removeSync(path.join(workingDirPath, '.git'));
        assert.isNull(await git.resolveDotGitDir(workingDirPath));
      });

      it('supports gitdir files', async function() {
        const workingDirPath = await cloneRepository('three-files');
        const workingDirPathWithDotGitFile = await getTempDir();
        await fs.writeFile(
          path.join(workingDirPathWithDotGitFile, '.git'),
          `gitdir: ${path.join(workingDirPath, '.git')}`,
          {encoding: 'utf8'},
        );

        const git = createTestStrategy(workingDirPathWithDotGitFile);
        const dotGitFolder = await git.resolveDotGitDir(workingDirPathWithDotGitFile);
        assert.equal(dotGitFolder, path.join(workingDirPath, '.git'));
      });
    });

    describe('fetchCommitMessageTemplate', function() {
      let git, workingDirPath, templateText;

      beforeEach(async function() {
        workingDirPath = await cloneRepository('three-files');
        git = createTestStrategy(workingDirPath);
        templateText = 'some commit message';
      });

      it('gets commit message from template', async function() {
        const commitMsgTemplatePath = path.join(workingDirPath, '.gitmessage');
        await fs.writeFile(commitMsgTemplatePath, templateText, {encoding: 'utf8'});

        await git.setConfig('commit.template', commitMsgTemplatePath);
        assert.equal(await git.fetchCommitMessageTemplate(), templateText);
      });

      it('if config is not set return null', async function() {
        assert.isNotOk(await git.getConfig('commit.template')); // falsy value of null or ''
        assert.isNull(await git.fetchCommitMessageTemplate());
      });

      it('if config is set but file does not exist throw an error', async function() {
        const nonExistentCommitTemplatePath = path.join(workingDirPath, 'file-that-doesnt-exist');
        await git.setConfig('commit.template', nonExistentCommitTemplatePath);
        await assert.isRejected(
          git.fetchCommitMessageTemplate(),
          `Invalid commit template path set in Git config: ${nonExistentCommitTemplatePath}`,
        );
      });

      it('replaces ~ with your home directory', async function() {
        // Fun fact: even on Windows, git does not accept "~\does-not-exist.txt"
        await git.setConfig('commit.template', '~/does-not-exist.txt');
        await assert.isRejected(
          git.fetchCommitMessageTemplate(),
          `Invalid commit template path set in Git config: ${path.join(os.homedir(), 'does-not-exist.txt')}`,
        );
      });

      it("replaces ~user with user's home directory", async function() {
        const expectedFullPath = path.join(path.dirname(os.homedir()), 'nope/does-not-exist.txt');
        await git.setConfig('commit.template', '~nope/does-not-exist.txt');
        await assert.isRejected(
          git.fetchCommitMessageTemplate(),
          `Invalid commit template path set in Git config: ${expectedFullPath}`,
        );
      });

      it('interprets relative paths local to the working directory', async function() {
        const subDir = path.join(workingDirPath, 'abc/def/ghi');
        const subPath = path.join(subDir, 'template.txt');
        await fs.mkdirs(subDir);
        await fs.writeFile(subPath, templateText, {encoding: 'utf8'});
        await git.setConfig('commit.template', path.join('abc/def/ghi/template.txt'));
        assert.strictEqual(await git.fetchCommitMessageTemplate(), templateText);
      });
    });


    describe('getStatusBundle()', function() {
      if (process.platform === 'win32') {
        it('normalizes the path separator on Windows', async function() {
          const workingDir = await cloneRepository('three-files');
          const git = createTestStrategy(workingDir);
          const [relPathA, relPathB] = ['a.txt', 'b.txt'].map(fileName => path.join('subdir-1', fileName));
          const [absPathA, absPathB] = [relPathA, relPathB].map(relPath => path.join(workingDir, relPath));

          await fs.writeFile(absPathA, 'some changes here\n', {encoding: 'utf8'});
          await fs.writeFile(absPathB, 'more changes here\n', {encoding: 'utf8'});
          await git.stageFiles([relPathB]);

          const {changedEntries} = await git.getStatusBundle();
          const changedPaths = changedEntries.map(entry => entry.filePath);
          assert.deepEqual(changedPaths, [relPathA, relPathB]);
        });
      }

      it('throws a LargeRepoError when the status output is too large', async function() {
        const workingDir = await cloneRepository('three-files');
        const git = createTestStrategy(workingDir);

        sinon.stub(git, 'exec').resolves({length: 1024 * 1024 * 10 + 1});

        await assert.isRejected(git.getStatusBundle(), LargeRepoError);
      });
    });

    describe('getHeadCommit()', function() {
      it('gets the SHA and message of the most recent commit', async function() {
        const workingDirPath = await cloneRepository('three-files');
        const git = createTestStrategy(workingDirPath);

        const commit = await git.getHeadCommit();
        assert.equal(commit.sha, '66d11860af6d28eb38349ef83de475597cb0e8b4');
        assert.equal(commit.messageSubject, 'Initial commit');
        assert.isFalse(commit.unbornRef);
      });

      it('notes when HEAD is an unborn ref', async function() {
        const workingDirPath = await initRepository();
        const git = createTestStrategy(workingDirPath);

        const commit = await git.getHeadCommit();
        assert.isTrue(commit.unbornRef);
      });
    });

    describe('getCommits()', function() {
      describe('when no commits exist in the repository', function() {
        it('returns an array with an unborn ref commit when the include unborn option is passed', async function() {
          const workingDirPath = await initRepository();
          const git = createTestStrategy(workingDirPath);

          const commits = await git.getCommits({includeUnborn: true});
          assert.lengthOf(commits, 1);
          assert.isTrue(commits[0].unbornRef);
        });

        it('returns an empty array when the include unborn option is not passed', async function() {
          const workingDirPath = await initRepository();
          const git = createTestStrategy(workingDirPath);

          const commits = await git.getCommits();
          assert.lengthOf(commits, 0);
        });
      });

      it('returns all commits if fewer than max commits exist', async function() {
        const workingDirPath = await cloneRepository('multiple-commits');
        const git = createTestStrategy(workingDirPath);

        const commits = await git.getCommits({max: 10});
        assert.lengthOf(commits, 3);

        assert.deepEqual(commits[0], {
          sha: '90b17a8e3fa0218f42afc1dd24c9003e285f4a82',
          author: new Author('kuychaco@github.com', 'Katrina Uychaco'),
          authorDate: 1471113656,
          messageSubject: 'third commit',
          messageBody: '',
          coAuthors: [],
          unbornRef: false,
          patch: [],
        });
        assert.deepEqual(commits[1], {
          sha: '18920c900bfa6e4844853e7e246607a31c3e2e8c',
          author: new Author('kuychaco@github.com', 'Katrina Uychaco'),
          authorDate: 1471113642,
          messageSubject: 'second commit',
          messageBody: '',
          coAuthors: [],
          unbornRef: false,
          patch: [],
        });
        assert.deepEqual(commits[2], {
          sha: '46c0d7179fc4e348c3340ff5e7957b9c7d89c07f',
          author: new Author('kuychaco@github.com', 'Katrina Uychaco'),
          authorDate: 1471113625,
          messageSubject: 'first commit',
          messageBody: '',
          coAuthors: [],
          unbornRef: false,
          patch: [],
        });
      });

      it('returns an array of the last max commits', async function() {
        const workingDirPath = await cloneRepository('multiple-commits');
        const git = createTestStrategy(workingDirPath);

        for (let i = 1; i <= 10; i++) {
          // eslint-disable-next-line no-await-in-loop
          await git.commit(`Commit ${i}`, {allowEmpty: true});
        }

        const commits = await git.getCommits({max: 10});
        assert.lengthOf(commits, 10);

        assert.strictEqual(commits[0].messageSubject, 'Commit 10');
        assert.strictEqual(commits[9].messageSubject, 'Commit 1');
      });

      it('includes co-authors based on commit body trailers', async function() {
        const workingDirPath = await cloneRepository('multiple-commits');
        const git = createTestStrategy(workingDirPath);

        await git.commit(dedent`
          Implemented feature collaboratively

          Co-authored-by: name <name@example.com>
          Co-authored-by: another-name <another-name@example.com>
          Co-authored-by: yet-another <yet-another@example.com>
        `, {allowEmpty: true});

        const commits = await git.getCommits({max: 1});
        assert.lengthOf(commits, 1);
        assert.deepEqual(commits[0].coAuthors, [
          new Author('name@example.com', 'name'),
          new Author('another-name@example.com', 'another-name'),
          new Author('yet-another@example.com', 'yet-another'),
        ]);
      });

      it('preserves newlines and whitespace in the original commit body', async function() {
        const workingDirPath = await cloneRepository('multiple-commits');
        const git = createTestStrategy(workingDirPath);

        await git.commit(dedent`
          Implemented feature

          Detailed explanation paragraph 1

          Detailed explanation paragraph 2
          #123 with an issue reference
        `.trim(), {allowEmpty: true, verbatim: true});

        const commits = await git.getCommits({max: 1});
        assert.lengthOf(commits, 1);
        assert.strictEqual(commits[0].messageSubject, 'Implemented feature');
        assert.strictEqual(commits[0].messageBody,
          'Detailed explanation paragraph 1\n\nDetailed explanation paragraph 2\n#123 with an issue reference');
      });

      describe('when patch option is true', function() {
        it('returns the diff associated with fetched commits', async function() {
          const workingDirPath = await cloneRepository('multiple-commits');
          const git = createTestStrategy(workingDirPath);

          const commits = await git.getCommits({max: 3, includePatch: true});

          assertDeepPropertyVals(commits[0].patch, [{
            oldPath: 'file.txt',
            newPath: 'file.txt',
            oldMode: '100644',
            newMode: '100644',
            hunks: [
              {
                oldStartLine: 1,
                oldLineCount: 1,
                newStartLine: 1,
                newLineCount: 1,
                heading: '',
                lines: [
                  '-two',
                  '+three',
                ],
              },
            ],
            status: 'modified',
          }]);

          assertDeepPropertyVals(commits[1].patch, [{
            oldPath: 'file.txt',
            newPath: 'file.txt',
            oldMode: '100644',
            newMode: '100644',
            hunks: [
              {
                oldStartLine: 1,
                oldLineCount: 1,
                newStartLine: 1,
                newLineCount: 1,
                heading: '',
                lines: [
                  '-one',
                  '+two',
                ],
              },
            ],
            status: 'modified',
          }]);

          assertDeepPropertyVals(commits[2].patch, [{
            oldPath: null,
            newPath: 'file.txt',
            oldMode: null,
            newMode: '100644',
            hunks: [
              {
                oldStartLine: 0,
                oldLineCount: 0,
                newStartLine: 1,
                newLineCount: 1,
                heading: '',
                lines: [
                  '+one',
                ],
              },
            ],
            status: 'added',
          }]);
        });
      });
    });

    describe('getAuthors', function() {
      it('returns list of all authors in the last <max> commits', async function() {
        const workingDirPath = await cloneRepository('multiple-commits');
        const git = createTestStrategy(workingDirPath);

        await git.exec(['config', 'user.name', 'Mona Lisa']);
        await git.exec(['config', 'user.email', 'mona@lisa.com']);
        await git.commit('Commit from Mona', {allowEmpty: true});

        await git.exec(['config', 'user.name', 'Hubot']);
        await git.exec(['config', 'user.email', 'hubot@github.com']);
        await git.commit('Commit from Hubot', {allowEmpty: true});

        await git.exec(['config', 'user.name', 'Me']);
        await git.exec(['config', 'user.email', 'me@github.com']);
        await git.commit('Commit from me', {allowEmpty: true});

        const authors = await git.getAuthors({max: 3});
        assert.deepEqual(authors, {
          'mona@lisa.com': 'Mona Lisa',
          'hubot@github.com': 'Hubot',
          'me@github.com': 'Me',
        });
      });

      it('includes commit authors', async function() {
        const workingDirPath = await cloneRepository('multiple-commits');
        const git = createTestStrategy(workingDirPath);

        await git.exec(['config', 'user.name', 'Com Mitter']);
        await git.exec(['config', 'user.email', 'comitter@place.com']);
        await git.exec(['commit', '--allow-empty', '--author="A U Thor <author@site.org>"', '-m', 'Commit together!']);

        const authors = await git.getAuthors({max: 1});
        assert.deepEqual(authors, {
          'comitter@place.com': 'Com Mitter',
          'author@site.org': 'A U Thor',
        });
      });

      it('includes co-authors from trailers', async function() {
        const workingDirPath = await cloneRepository('multiple-commits');
        const git = createTestStrategy(workingDirPath);

        await git.exec(['config', 'user.name', 'Com Mitter']);
        await git.exec(['config', 'user.email', 'comitter@place.com']);

        await git.commit(dedent`
          Implemented feature collaboratively

          Co-authored-by: name <name@example.com>
          Co-authored-by: another name <another-name@example.com>
          Co-authored-by: yet another name <yet-another@example.com>
        `, {allowEmpty: true});

        const authors = await git.getAuthors({max: 1});
        assert.deepEqual(authors, {
          'comitter@place.com': 'Com Mitter',
          'name@example.com': 'name',
          'another-name@example.com': 'another name',
          'yet-another@example.com': 'yet another name',
        });
      });

      it('returns an empty array when there are no commits', async function() {
        const workingDirPath = await initRepository();
        const git = createTestStrategy(workingDirPath);

        const authors = await git.getAuthors({max: 1});
        assert.deepEqual(authors, []);
      });

      it('propagates other git errors', async function() {
        const workingDirPath = await cloneRepository('multiple-commits');
        const git = createTestStrategy(workingDirPath);
        sinon.stub(git, 'exec').rejects(new Error('oh no'));

        await assert.isRejected(git.getAuthors(), /oh no/);
      });
    });

    describe('diffFileStatus', function() {
      it('returns an object with working directory file diff status between relative to specified target commit', async function() {
        const workingDirPath = await cloneRepository('three-files');
        const git = createTestStrategy(workingDirPath);
        fs.writeFileSync(path.join(workingDirPath, 'a.txt'), 'qux\nfoo\nbar\n', 'utf8');
        fs.unlinkSync(path.join(workingDirPath, 'b.txt'));
        fs.renameSync(path.join(workingDirPath, 'c.txt'), path.join(workingDirPath, 'd.txt'));
        fs.writeFileSync(path.join(workingDirPath, 'e.txt'), 'qux', 'utf8');
        const diffOutput = await git.diffFileStatus({target: 'HEAD'});
        assert.deepEqual(diffOutput, {
          'a.txt': 'modified',
          'b.txt': 'deleted',
          'c.txt': 'deleted',
          'd.txt': 'added',
          'e.txt': 'added',
        });
      });

      it('returns an empty object if there are no added, modified, or removed files', async function() {
        const workingDirPath = await cloneRepository('three-files');
        const git = createTestStrategy(workingDirPath);
        const diffOutput = await git.diffFileStatus({target: 'HEAD'});
        assert.deepEqual(diffOutput, {});
      });

      it('only returns untracked files if the staged option is not passed', async function() {
        const workingDirPath = await cloneRepository('three-files');
        const git = createTestStrategy(workingDirPath);
        fs.writeFileSync(path.join(workingDirPath, 'new-file.txt'), 'qux', 'utf8');
        let diffOutput = await git.diffFileStatus({target: 'HEAD'});
        assert.deepEqual(diffOutput, {'new-file.txt': 'added'});
        diffOutput = await git.diffFileStatus({target: 'HEAD', staged: true});
        assert.deepEqual(diffOutput, {});
      });
    });

    describe('getUntrackedFiles', function() {
      it('returns an array of untracked file paths', async function() {
        const workingDirPath = await cloneRepository('three-files');
        const git = createTestStrategy(workingDirPath);
        fs.writeFileSync(path.join(workingDirPath, 'd.txt'), 'foo', 'utf8');
        fs.writeFileSync(path.join(workingDirPath, 'e.txt'), 'bar', 'utf8');
        fs.writeFileSync(path.join(workingDirPath, 'f.txt'), 'qux', 'utf8');
        assert.deepEqual(await git.getUntrackedFiles(), ['d.txt', 'e.txt', 'f.txt']);
      });

      it('handles untracked files in nested folders', async function() {
        const workingDirPath = await cloneRepository('three-files');
        const git = createTestStrategy(workingDirPath);
        fs.writeFileSync(path.join(workingDirPath, 'd.txt'), 'foo', 'utf8');
        const folderPath = path.join(workingDirPath, 'folder', 'subfolder');
        mkdirp.sync(folderPath);
        fs.writeFileSync(path.join(folderPath, 'e.txt'), 'bar', 'utf8');
        fs.writeFileSync(path.join(folderPath, 'f.txt'), 'qux', 'utf8');
        assert.deepEqual(await git.getUntrackedFiles(), [
          'd.txt',
          path.join('folder', 'subfolder', 'e.txt'),
          path.join('folder', 'subfolder', 'f.txt'),
        ]);
      });

      it('returns an empty array if there are no untracked files', async function() {
        const workingDirPath = await cloneRepository('three-files');
        const git = createTestStrategy(workingDirPath);
        assert.deepEqual(await git.getUntrackedFiles(), []);
      });
    });

    describe('getDiffsForFilePath', function() {
      it('returns an empty array if there are no modified, added, or deleted files', async function() {
        const workingDirPath = await cloneRepository('three-files');
        const git = createTestStrategy(workingDirPath);

        const diffOutput = await git.getDiffsForFilePath('a.txt');
        assert.deepEqual(diffOutput, []);
      });

      it('ignores merge conflict files', async function() {
        const workingDirPath = await cloneRepository('merge-conflict');
        const git = createTestStrategy(workingDirPath);
        const diffOutput = await git.getDiffsForFilePath('added-to-both.txt');
        assert.deepEqual(diffOutput, []);
      });

      it('bypasses external diff tools', async function() {
        const workingDirPath = await cloneRepository('three-files');
        const git = createTestStrategy(workingDirPath);

        fs.writeFileSync(path.join(workingDirPath, 'a.txt'), 'qux\nfoo\nbar\n', 'utf8');
        process.env.GIT_EXTERNAL_DIFF = 'bogus_app_name';
        const diffOutput = await git.getDiffsForFilePath('a.txt');
        delete process.env.GIT_EXTERNAL_DIFF;

        assert.isDefined(diffOutput);
      });

      it('rejects if an unexpected number of diffs is returned', async function() {
        const workingDirPath = await cloneRepository();
        const git = createTestStrategy(workingDirPath);
        sinon.stub(git, 'exec').resolves(dedent`
          diff --git aaa.txt aaa.txt
          index df565d30..244a7225 100644
          --- aaa.txt
          +++ aaa.txt
          @@ -100,3 +100,3 @@
           000
          -001
          +002
           003
          diff --git aaa.txt aaa.txt
          index df565d30..244a7225 100644
          --- aaa.txt
          +++ aaa.txt
          @@ -100,3 +100,3 @@
           000
          -001
          +002
           003
          diff --git aaa.txt aaa.txt
          index df565d30..244a7225 100644
          --- aaa.txt
          +++ aaa.txt
          @@ -100,3 +100,3 @@
           000
          -001
          +002
           003
        `);

        await assert.isRejected(git.getDiffsForFilePath('aaa.txt'), /Expected between 0 and 2 diffs/);
      });

      describe('when the file is unstaged', function() {
        it('returns a diff comparing the working directory copy of the file and the version on the index', async function() {
          const workingDirPath = await cloneRepository('three-files');
          const git = createTestStrategy(workingDirPath);
          fs.writeFileSync(path.join(workingDirPath, 'a.txt'), 'qux\nfoo\nbar\n', 'utf8');
          fs.renameSync(path.join(workingDirPath, 'c.txt'), path.join(workingDirPath, 'd.txt'));

          assertDeepPropertyVals(await git.getDiffsForFilePath('a.txt'), [{
            oldPath: 'a.txt',
            newPath: 'a.txt',
            oldMode: '100644',
            newMode: '100644',
            hunks: [
              {
                oldStartLine: 1,
                oldLineCount: 1,
                newStartLine: 1,
                newLineCount: 3,
                heading: '',
                lines: [
                  '+qux',
                  ' foo',
                  '+bar',
                ],
              },
            ],
            status: 'modified',
          }]);

          assertDeepPropertyVals(await git.getDiffsForFilePath('c.txt'), [{
            oldPath: 'c.txt',
            newPath: null,
            oldMode: '100644',
            newMode: null,
            hunks: [
              {
                oldStartLine: 1,
                oldLineCount: 1,
                newStartLine: 0,
                newLineCount: 0,
                heading: '',
                lines: ['-baz'],
              },
            ],
            status: 'deleted',
          }]);

          assertDeepPropertyVals(await git.getDiffsForFilePath('d.txt'), [{
            oldPath: null,
            newPath: 'd.txt',
            oldMode: null,
            newMode: '100644',
            hunks: [
              {
                oldStartLine: 0,
                oldLineCount: 0,
                newStartLine: 1,
                newLineCount: 1,
                heading: '',
                lines: ['+baz'],
              },
            ],
            status: 'added',
          }]);
        });
      });

      describe('when the file is staged', function() {
        it('returns a diff comparing the index and head versions of the file', async function() {
          const workingDirPath = await cloneRepository('three-files');
          const git = createTestStrategy(workingDirPath);
          fs.writeFileSync(path.join(workingDirPath, 'a.txt'), 'qux\nfoo\nbar\n', 'utf8');
          fs.renameSync(path.join(workingDirPath, 'c.txt'), path.join(workingDirPath, 'd.txt'));
          await git.exec(['add', '.']);

          assertDeepPropertyVals(await git.getDiffsForFilePath('a.txt', {staged: true}), [{
            oldPath: 'a.txt',
            newPath: 'a.txt',
            oldMode: '100644',
            newMode: '100644',
            hunks: [
              {
                oldStartLine: 1,
                oldLineCount: 1,
                newStartLine: 1,
                newLineCount: 3,
                heading: '',
                lines: [
                  '+qux',
                  ' foo',
                  '+bar',
                ],
              },
            ],
            status: 'modified',
          }]);

          assertDeepPropertyVals(await git.getDiffsForFilePath('c.txt', {staged: true}), [{
            oldPath: 'c.txt',
            newPath: null,
            oldMode: '100644',
            newMode: null,
            hunks: [
              {
                oldStartLine: 1,
                oldLineCount: 1,
                newStartLine: 0,
                newLineCount: 0,
                heading: '',
                lines: ['-baz'],
              },
            ],
            status: 'deleted',
          }]);

          assertDeepPropertyVals(await git.getDiffsForFilePath('d.txt', {staged: true}), [{
            oldPath: null,
            newPath: 'd.txt',
            oldMode: null,
            newMode: '100644',
            hunks: [
              {
                oldStartLine: 0,
                oldLineCount: 0,
                newStartLine: 1,
                newLineCount: 1,
                heading: '',
                lines: ['+baz'],
              },
            ],
            status: 'added',
          }]);
        });
      });

      describe('when the file is staged and a base commit is specified', function() {
        it('returns a diff comparing the file on the index and in the specified commit', async function() {
          const workingDirPath = await cloneRepository('multiple-commits');
          const git = createTestStrategy(workingDirPath);

          assertDeepPropertyVals(await git.getDiffsForFilePath('file.txt', {staged: true, baseCommit: 'HEAD~'}), [{
            oldPath: 'file.txt',
            newPath: 'file.txt',
            oldMode: '100644',
            newMode: '100644',
            hunks: [
              {
                oldStartLine: 1,
                oldLineCount: 1,
                newStartLine: 1,
                newLineCount: 1,
                heading: '',
                lines: ['-two', '+three'],
              },
            ],
            status: 'modified',
          }]);
        });
      });

      describe('when the file is new', function() {
        it('returns a diff representing the addition of the file', async function() {
          const workingDirPath = await cloneRepository('three-files');
          const git = createTestStrategy(workingDirPath);
          fs.writeFileSync(path.join(workingDirPath, 'new-file.txt'), 'qux\nfoo\nbar\n', 'utf8');
          assertDeepPropertyVals(await git.getDiffsForFilePath('new-file.txt'), [{
            oldPath: null,
            newPath: 'new-file.txt',
            oldMode: null,
            newMode: '100644',
            hunks: [
              {
                oldStartLine: 0,
                oldLineCount: 0,
                newStartLine: 1,
                newLineCount: 3,
                heading: '',
                lines: [
                  '+qux',
                  '+foo',
                  '+bar',
                ],
              },
            ],
            status: 'added',
          }]);

        });

        describe('when the file is binary', function() {
          it('returns an empty diff', async function() {
            const workingDirPath = await cloneRepository('three-files');
            const git = createTestStrategy(workingDirPath);
            const data = new Buffer(10);
            for (let i = 0; i < 10; i++) {
              data.writeUInt8(i + 200, i);
            }
            // make the file executable so we test that executable mode is set correctly
            fs.writeFileSync(path.join(workingDirPath, 'new-file.bin'), data, {mode: 0o755});

            const expectedFileMode = process.platform === 'win32' ? '100644' : '100755';

            assertDeepPropertyVals(await git.getDiffsForFilePath('new-file.bin'), [{
              oldPath: null,
              newPath: 'new-file.bin',
              oldMode: null,
              newMode: expectedFileMode,
              hunks: [],
              status: 'added',
            }]);
          });
        });
      });
    });

    describe('getStagedChangesPatch', function() {
      it('returns an empty patch if there are no staged files', async function() {
        const workdir = await cloneRepository('three-files');
        const git = createTestStrategy(workdir);
        const mp = await git.getStagedChangesPatch();
        assert.lengthOf(mp, 0);
      });

      it('returns a combined diff of all staged files', async function() {
        const workdir = await cloneRepository('each-staging-group');
        const git = createTestStrategy(workdir);

        await assert.isRejected(git.merge('origin/branch'));
        await fs.writeFile(path.join(workdir, 'unstaged-1.txt'), 'Unstaged file');
        await fs.writeFile(path.join(workdir, 'unstaged-2.txt'), 'Unstaged file');

        await fs.writeFile(path.join(workdir, 'staged-1.txt'), 'Staged file');
        await fs.writeFile(path.join(workdir, 'staged-2.txt'), 'Staged file');
        await fs.writeFile(path.join(workdir, 'staged-3.txt'), 'Staged file');
        await git.stageFiles(['staged-1.txt', 'staged-2.txt', 'staged-3.txt']);

        const diffs = await git.getStagedChangesPatch();
        assert.deepEqual(diffs.map(diff => diff.newPath), ['staged-1.txt', 'staged-2.txt', 'staged-3.txt']);
      });
    });

    describe('isMerging', function() {
      it('returns true if `.git/MERGE_HEAD` exists', async function() {
        const workingDirPath = await cloneRepository('merge-conflict');
        const dotGitDir = path.join(workingDirPath, '.git');
        const git = createTestStrategy(workingDirPath);
        let isMerging = await git.isMerging(dotGitDir);
        assert.isFalse(isMerging);

        try {
          await git.merge('origin/branch');
        } catch (e) {
          // expect merge to have conflicts
        }
        isMerging = await git.isMerging(dotGitDir);
        assert.isTrue(isMerging);

        fs.unlinkSync(path.join(workingDirPath, '.git', 'MERGE_HEAD'));
        isMerging = await git.isMerging(dotGitDir);
        assert.isFalse(isMerging);
      });
    });

    describe('checkout(branchName, {createNew})', function() {
      it('returns the current branch name', async function() {
        const workingDirPath = await cloneRepository('merge-conflict');
        const git = createTestStrategy(workingDirPath);
        assert.deepEqual((await git.exec(['symbolic-ref', '--short', 'HEAD'])).trim(), 'master');
        await git.checkout('branch');
        assert.deepEqual((await git.exec(['symbolic-ref', '--short', 'HEAD'])).trim(), 'branch');

        // newBranch does not yet exist
        await assert.isRejected(git.checkout('newBranch'));
        assert.deepEqual((await git.exec(['symbolic-ref', '--short', 'HEAD'])).trim(), 'branch');
        assert.deepEqual((await git.exec(['symbolic-ref', '--short', 'HEAD'])).trim(), 'branch');
        await git.checkout('newBranch', {createNew: true});
        assert.deepEqual((await git.exec(['symbolic-ref', '--short', 'HEAD'])).trim(), 'newBranch');
      });

      it('specifies a different starting point with startPoint', async function() {
        const workingDirPath = await cloneRepository('multiple-commits');
        const git = createTestStrategy(workingDirPath);
        await git.checkout('new-branch', {createNew: true, startPoint: 'HEAD^'});

        assert.strictEqual((await git.exec(['symbolic-ref', '--short', 'HEAD'])).trim(), 'new-branch');
        const commit = await git.getCommit('HEAD');
        assert.strictEqual(commit.messageSubject, 'second commit');
      });

      it('establishes a tracking relationship with track', async function() {
        const workingDirPath = await cloneRepository('multiple-commits');
        const git = createTestStrategy(workingDirPath);
        await git.checkout('other-branch', {createNew: true, startPoint: 'HEAD^^'});
        await git.checkout('new-branch', {createNew: true, startPoint: 'other-branch', track: true});

        assert.strictEqual((await git.exec(['symbolic-ref', '--short', 'HEAD'])).trim(), 'new-branch');
        const commit = await git.getCommit('HEAD');
        assert.strictEqual(commit.messageSubject, 'first commit');
        assert.strictEqual(await git.getConfig('branch.new-branch.merge'), 'refs/heads/other-branch');
      });
    });

    describe('reset()', function() {
      describe('when soft and HEAD~ are passed as arguments', function() {
        it('performs a soft reset to the parent of head', async function() {
          const workingDirPath = await cloneRepository('three-files');
          const git = createTestStrategy(workingDirPath);

          fs.appendFileSync(path.join(workingDirPath, 'a.txt'), 'bar\n', 'utf8');
          await git.exec(['add', '.']);
          await git.commit('add stuff');

          const parentCommit = await git.getCommit('HEAD~');

          await git.reset('soft', 'HEAD~');

          const commitAfterReset = await git.getCommit('HEAD');
          assert.strictEqual(commitAfterReset.sha, parentCommit.sha);

          const stagedChanges = await git.getDiffsForFilePath('a.txt', {staged: true});
          assert.lengthOf(stagedChanges, 1);
          const stagedChange = stagedChanges[0];
          assert.strictEqual(stagedChange.newPath, 'a.txt');
          assert.deepEqual(stagedChange.hunks[0].lines, [' foo', '+bar']);
        });
      });

      it('fails when an invalid type is passed', async function() {
        const workingDirPath = await cloneRepository('three-files');
        const git = createTestStrategy(workingDirPath);
        assert.throws(() => git.reset('scrambled'), /Invalid type scrambled/);
      });
    });

    describe('deleteRef()', function() {
      it('soft-resets an initial commit', async function() {
        const workingDirPath = await cloneRepository('three-files');
        const git = createTestStrategy(workingDirPath);

        // Ensure that three-files still has only a single commit
        assert.lengthOf(await git.getCommits({max: 10}), 1);

        // Put something into the index to ensure it doesn't get lost
        fs.appendFileSync(path.join(workingDirPath, 'a.txt'), 'zzz\n', 'utf8');
        await git.exec(['add', '.']);

        await git.deleteRef('HEAD');

        const after = await git.getCommit('HEAD');
        assert.isTrue(after.unbornRef);

        const stagedChanges = await git.getDiffsForFilePath('a.txt', {staged: true});
        assert.lengthOf(stagedChanges, 1);
        const stagedChange = stagedChanges[0];
        assert.strictEqual(stagedChange.newPath, 'a.txt');
        assert.deepEqual(stagedChange.hunks[0].lines, ['+foo', '+zzz']);
      });
    });

    describe('getBranches()', function() {
      const sha = '66d11860af6d28eb38349ef83de475597cb0e8b4';

      const master = {
        name: 'master',
        head: false,
        sha,
        upstream: {trackingRef: 'refs/remotes/origin/master', remoteName: 'origin', remoteRef: 'refs/heads/master'},
        push: {trackingRef: 'refs/remotes/origin/master', remoteName: 'origin', remoteRef: 'refs/heads/master'},
      };

      const currentMaster = {
        ...master,
        head: true,
      };

      it('returns an array of all branches', async function() {
        const workingDirPath = await cloneRepository('three-files');
        const git = createTestStrategy(workingDirPath);

        assert.deepEqual(await git.getBranches(), [currentMaster]);
        await git.checkout('new-branch', {createNew: true});
        assert.deepEqual(await git.getBranches(), [master, {name: 'new-branch', head: true, sha}]);
        await git.checkout('another-branch', {createNew: true});
        assert.deepEqual(await git.getBranches(), [
          {name: 'another-branch', head: true, sha},
          master,
          {name: 'new-branch', head: false, sha},
        ]);
      });

      it('includes branches with slashes in the name', async function() {
        const workingDirPath = await cloneRepository('three-files');
        const git = createTestStrategy(workingDirPath);
        assert.deepEqual(await git.getBranches(), [currentMaster]);
        await git.checkout('a/fancy/new/branch', {createNew: true});
        assert.deepEqual(await git.getBranches(), [{name: 'a/fancy/new/branch', head: true, sha}, master]);
      });
    });

    describe('getBranchesWithCommit', function() {
      let git;

      const SHA = '18920c900bfa6e4844853e7e246607a31c3e2e8c';

      beforeEach(async function() {
        const {localRepoPath} = await setUpLocalAndRemoteRepositories('multiple-commits');
        git = createTestStrategy(localRepoPath);
      });

      it('includes only local refs', async function() {
        assert.sameMembers(await git.getBranchesWithCommit(SHA), ['refs/heads/master']);
      });

      it('includes both local and remote refs', async function() {
        assert.sameMembers(
          await git.getBranchesWithCommit(SHA, {showLocal: true, showRemote: true}),
          ['refs/heads/master', 'refs/remotes/origin/HEAD', 'refs/remotes/origin/master'],
        );
      });

      it('includes only remote refs', async function() {
        assert.sameMembers(
          await git.getBranchesWithCommit(SHA, {showRemote: true}),
          ['refs/remotes/origin/HEAD', 'refs/remotes/origin/master'],
        );
      });

      it('includes only refs matching a pattern', async function() {
        assert.sameMembers(
          await git.getBranchesWithCommit(SHA, {showLocal: true, showRemote: true, pattern: 'origin/master'}),
          ['refs/remotes/origin/master'],
        );
      });
    });

    describe('getRemotes()', function() {
      it('returns an array of remotes', async function() {
        const workingDirPath = await cloneRepository('three-files');
        const git = createTestStrategy(workingDirPath);
        await git.exec(['remote', 'set-url', 'origin', 'git@github.com:other/origin.git']);
        await git.exec(['remote', 'add', 'upstream', 'git@github.com:my/upstream.git']);
        await git.exec(['remote', 'add', 'another.remote', 'git@github.com:another/upstream.git']);
        const remotes = await git.getRemotes();
        // Note: nodegit returns remote names in alphabetical order
        assert.equal(remotes.length, 3);
        [
          {name: 'another.remote', url: 'git@github.com:another/upstream.git'},
          {name: 'origin', url: 'git@github.com:other/origin.git'},
          {name: 'upstream', url: 'git@github.com:my/upstream.git'},
        ].forEach(remote => {
          assert.deepInclude(remotes, remote);
        });
      });

      it('returns an empty array when no remotes are set up', async function() {
        const workingDirPath = await cloneRepository('three-files');
        const git = createTestStrategy(workingDirPath);
        await git.exec(['remote', 'rm', 'origin']);
        const remotes = await git.getRemotes();
        assert.deepEqual(remotes, []);
      });
    });

    describe('getConfig() and setConfig()', function() {
      it('gets and sets configs', async function() {
        const workingDirPath = await cloneRepository('three-files');
        const git = createTestStrategy(workingDirPath);
        assert.isNull(await git.getConfig('awesome.devs'));
        await git.setConfig('awesome.devs', 'BinaryMuse,kuychaco,smashwilson');
        assert.equal('BinaryMuse,kuychaco,smashwilson', await git.getConfig('awesome.devs'));
      });

      it('propagates unexpected git errors', async function() {
        const workingDirPath = await cloneRepository('three-files');
        const git = createTestStrategy(workingDirPath);
        sinon.stub(git, 'exec').rejects(new Error('AHHHH'));

        await assert.isRejected(git.getConfig('some.key'), /AHHHH/);
      });
    });

    describe('commit(message, options)', function() {
      describe('formatting commit message', function() {
        let message;

        beforeEach(function() {
          message = [
            '    Make a commit    ',
            '',
            '# Comments:',
            '#  blah blah blah',
            '',
            '',
            '',
            'other stuff        ',
            '',
            'and things',
            '',
          ].join('\n');
        });

        it('strips out comments and whitespace from message passed', async function() {
          const workingDirPath = await cloneRepository('multiple-commits');
          const git = createTestStrategy(workingDirPath);
          await git.setConfig('commit.cleanup', 'default');

          await git.commit(message, {allowEmpty: true});

          const lastCommit = await git.getHeadCommit();
          assert.strictEqual(lastCommit.messageSubject, 'Make a commit');
          assert.strictEqual(lastCommit.messageBody, 'other stuff\n\nand things');
        });

        it('passes a message through verbatim', async function() {
          const workingDirPath = await cloneRepository('multiple-commits');
          const git = createTestStrategy(workingDirPath);
          await git.setConfig('commit.cleanup', 'default');

          await git.commit(message, {allowEmpty: true, verbatim: true});

          const lastCommit = await git.getHeadCommit();
          assert.strictEqual(lastCommit.messageSubject, 'Make a commit');
          assert.strictEqual(lastCommit.messageBody, [
            '# Comments:',
            '#  blah blah blah',
            '',
            '',
            '',
            'other stuff        ',
            '',
            'and things',
          ].join('\n'));
        });
        it('strips commented lines if commit template is used', async function() {
          const workingDirPath = await cloneRepository('three-files');
          const git = createTestStrategy(workingDirPath);
          const templateText = '# this line should be stripped';

          const commitMsgTemplatePath = path.join(workingDirPath, '.gitmessage');
          await fs.writeFile(commitMsgTemplatePath, templateText, {encoding: 'utf8'});

          await git.setConfig('commit.template', commitMsgTemplatePath);
          await git.setConfig('commit.cleanup', 'default');
          const commitMessage = ['this line should not be stripped', '', 'neither should this one', '', '# but this one should', templateText].join('\n');
          await git.commit(commitMessage, {allowEmpty: true, verbatim: true});

          const lastCommit = await git.getHeadCommit();
          assert.strictEqual(lastCommit.messageSubject, 'this line should not be stripped');
          //  message body should not contain the template text
          assert.strictEqual(lastCommit.messageBody, 'neither should this one');
        });
        it('respects core.commentChar from git settings when determining which comment to strip', async function() {
          const workingDirPath = await cloneRepository('three-files');
          const git = createTestStrategy(workingDirPath);
          const templateText = 'templates are just the best';

          const commitMsgTemplatePath = path.join(workingDirPath, '.gitmessage');
          await fs.writeFile(commitMsgTemplatePath, templateText, {encoding: 'utf8'});

          await git.setConfig('commit.template', commitMsgTemplatePath);
          await git.setConfig('commit.cleanup', 'default');
          await git.setConfig('core.commentChar', '$');

          const commitMessage = ['# this line should not be stripped', '$ but this one should', '', 'ch-ch-changes'].join('\n');
          await git.commit(commitMessage, {allowEmpty: true, verbatim: true});

          const lastCommit = await git.getHeadCommit();
          assert.strictEqual(lastCommit.messageSubject, '# this line should not be stripped');
          assert.strictEqual(lastCommit.messageBody, 'ch-ch-changes');
        });
      });

      describe('when amend option is true', function() {
        it('amends the last commit', async function() {
          const workingDirPath = await cloneRepository('multiple-commits');
          const git = createTestStrategy(workingDirPath);
          const lastCommit = await git.getHeadCommit();
          const lastCommitParent = await git.getCommit('HEAD~');
          await git.commit('amend last commit', {amend: true, allowEmpty: true});
          const amendedCommit = await git.getHeadCommit();
          const amendedCommitParent = await git.getCommit('HEAD~');

          assert.strictEqual(amendedCommit.messageSubject, 'amend last commit');
          assert.notDeepEqual(lastCommit, amendedCommit);
          assert.deepEqual(lastCommitParent, amendedCommitParent);
        });

        it('leaves the commit message unchanged', async function() {
          const workingDirPath = await cloneRepository('multiple-commits');
          const git = createTestStrategy(workingDirPath);
          await git.commit('first\n\nsecond\n\nthird', {allowEmpty: true});

          await git.commit('', {amend: true, allowEmpty: true});
          const amendedCommit = await git.getHeadCommit();
          assert.strictEqual(amendedCommit.messageSubject, 'first');
          assert.strictEqual(amendedCommit.messageBody, 'second\n\nthird');
        });

        it('attempts to amend an unborn commit', async function() {
          const workingDirPath = await initRepository();
          const git = createTestStrategy(workingDirPath);

          await assert.isRejected(git.commit('', {amend: true, allowEmpty: true}), /You have nothing to amend/);
        });
      });
    });

    describe('addCoAuthorsToMessage', function() {
      it('always adds trailing newline', async () => {
        const workingDirPath = await cloneRepository('multiple-commits');
        const git = createTestStrategy(workingDirPath);

        assert.equal(await git.addCoAuthorsToMessage('test'), 'test\n');
      });

      it('appends trailers to a summary-only message', async () => {
        const workingDirPath = await cloneRepository('three-files');
        const git = createTestStrategy(workingDirPath);

        const coAuthors = [
          {
            name: 'Markus Olsson',
            email: 'niik@github.com',
          },
          {
            name: 'Neha Batra',
            email: 'nerdneha@github.com',
          },
        ];

        assert.equal(await git.addCoAuthorsToMessage('foo', coAuthors),
          dedent`
            foo

            Co-Authored-By: Markus Olsson <niik@github.com>
            Co-Authored-By: Neha Batra <nerdneha@github.com>

          `,
        );
      });

      // note, this relies on the default git config
      it('merges duplicate trailers', async () => {
        const workingDirPath = await cloneRepository('three-files');
        const git = createTestStrategy(workingDirPath);

        const coAuthors = [
          {
            name: 'Markus Olsson',
            email: 'niik@github.com',
          },
          {
            name: 'Neha Batra',
            email: 'nerdneha@github.com',
          },
        ];

        assert.equal(
          await git.addCoAuthorsToMessage(
            'foo\n\nCo-Authored-By: Markus Olsson <niik@github.com>',
            coAuthors,
          ),
          dedent`
            foo

            Co-Authored-By: Markus Olsson <niik@github.com>
            Co-Authored-By: Neha Batra <nerdneha@github.com>

          `,
        );
      });

      // note, this relies on the default git config
      it('fixes up malformed trailers when trailers are given', async () => {
        const workingDirPath = await cloneRepository('three-files');
        const git = createTestStrategy(workingDirPath);

        const coAuthors = [
          {
            name: 'Neha Batra',
            email: 'nerdneha@github.com',
          },
        ];

        assert.equal(
          await git.addCoAuthorsToMessage(
            // note the lack of space after :
            'foo\n\nCo-Authored-By:Markus Olsson <niik@github.com>',
            coAuthors,
          ),
          dedent`
            foo

            Co-Authored-By: Markus Olsson <niik@github.com>
            Co-Authored-By: Neha Batra <nerdneha@github.com>

          `,
        );
      });
    });

    describe('checkoutSide', function() {
      it('is a no-op when no paths are provided', async function() {
        const workdir = await cloneRepository();
        const git = await createTestStrategy(workdir);
        sinon.spy(git, 'exec');

        await git.checkoutSide('ours', []);
        assert.isFalse(git.exec.called);
      });
    });

    // Only needs to be tested on strategies that actually implement gpgExec
    describe('GPG signing', function() {
      let git;

      // eslint-disable-next-line jasmine/no-global-setup
      beforeEach(async function() {
        const workingDirPath = await cloneRepository('multiple-commits');
        git = createTestStrategy(workingDirPath);
        sinon.stub(git, 'fetchCommitMessageTemplate').returns(null);
      });

      const operations = [
        {
          command: 'commit',
          progressiveTense: 'committing',
          usesPromptServerAlready: false,
          action: () => git.commit('message', {verbatim: true}),
        },
        {
          command: 'merge',
          progressiveTense: 'merging',
          usesPromptServerAlready: false,
          action: () => git.merge('some-branch'),
        },
        {
          command: 'pull',
          progressiveTense: 'pulling',
          usesPromptServerAlready: true,
          action: () => git.pull('origin', 'some-branch'),
        },
      ];

      const notCancelled = () => assert.fail('', '', 'Unexpected operation cancel');

      operations.forEach(op => {
        it(`tries a ${op.command} without a GPG prompt first`, async function() {
          const execStub = sinon.stub(git, 'executeGitCommand');
          execStub.returns({
            promise: Promise.resolve({stdout: '', stderr: '', exitCode: 0}),
            cancel: notCancelled,
          });

          await op.action();

          const [args, options] = execStub.getCall(0).args;
          assertGitConfigSetting(args, op.command, 'gpg.program', '.*gpg-wrapper\\.sh$');
          assert.isUndefined(options.env.ATOM_GITHUB_GPG_PROMPT);
        });

        it(`retries and overrides gpg.program when ${op.progressiveTense}`, async function() {
          const execStub = sinon.stub(git, 'executeGitCommand');
          execStub.onCall(0).returns({
            promise: Promise.resolve({
              stdout: '',
              stderr: 'stderr includes "gpg failed"',
              exitCode: 128,
            }),
            cancel: notCancelled,
          });
          execStub.returns({
            promise: Promise.resolve({stdout: '', stderr: '', exitCode: 0}),
            cancel: notCancelled,
          });

          await op.action();

          const [args, options] = execStub.getCall(1).args;
          assertGitConfigSetting(args, op.command, 'gpg.program', '.*gpg-wrapper\\.sh$');
          assert.isDefined(options.env.ATOM_GITHUB_SOCK_ADDR);
          assert.isDefined(options.env.ATOM_GITHUB_GPG_PROMPT);
        });

        if (!op.usesPromptServerAlready) {
          it(`retries a ${op.command} with a GitPromptServer and gpg.program when GPG signing fails`, async function() {
            const execStub = sinon.stub(git, 'executeGitCommand');
            execStub.onCall(0).returns({
              promise: Promise.resolve({
                stdout: '',
                stderr: 'stderr includes "gpg failed"',
                exitCode: 128,
              }),
              cancel: notCancelled,
            });
            execStub.returns(Promise.resolve({stdout: '', stderr: '', exitCode: 0}));
            execStub.returns({
              promise: Promise.resolve({stdout: '', stderr: '', exitCode: 0}),
              cancel: notCancelled,
            });

            // Should not throw
            await op.action();

            const [args0, options0] = execStub.getCall(0).args;
            assertGitConfigSetting(args0, op.command, 'gpg.program', '.*gpg-wrapper\\.sh$');
            assert.isUndefined(options0.env.ATOM_GITHUB_SOCK_ADDR);
            assert.isUndefined(options0.env.ATOM_GITHUB_GPG_PROMPT);

            const [args1, options1] = execStub.getCall(1).args;
            assertGitConfigSetting(args1, op.command, 'gpg.program', '.*gpg-wrapper\\.sh$');
            assert.isDefined(options1.env.ATOM_GITHUB_SOCK_ADDR);
            assert.isDefined(options1.env.ATOM_GITHUB_GPG_PROMPT);
          });
        }
      });
    });

    describe('the built-in credential helper', function() {
      let git, originalEnv;

      beforeEach(async function() {
        const workingDirPath = await cloneRepository('multiple-commits');
        git = createTestStrategy(workingDirPath, {
          prompt: Promise.resolve(''),
        });

        originalEnv = {};
        ['PATH', 'DISPLAY', 'GIT_ASKPASS', 'SSH_ASKPASS', 'GIT_SSH_COMMAND'].forEach(varName => {
          originalEnv[varName] = process.env[varName];
        });
      });

      afterEach(function() {
        Object.keys(originalEnv).forEach(varName => {
          process.env[varName] = originalEnv[varName];
        });
      });

      const operations = [
        {
          command: 'fetch',
          progressiveTense: 'fetching',
          action: () => git.fetch('origin', 'some-branch'),
        },
        {
          command: 'pull',
          progressiveTense: 'pulling',
          action: () => git.pull('origin', 'some-branch'),
        },
        {
          command: 'push',
          progressiveTense: 'pushing',
          action: () => git.push('origin', 'some-branch'),
        },
        {
          command: 'clone',
          progressiveTense: 'cloning',
          action: () => git.clone('https://github.com/atom/github'),
        },
      ];

      const notCancelled = () => assert.fail('', '', 'Unexpected operation cancel');

      operations.forEach(op => {
        it(`temporarily supplements credential.helper when ${op.progressiveTense}`, async function() {
          const execStub = sinon.stub(git, 'executeGitCommand');
          execStub.returns({
            promise: Promise.resolve({stdout: '', stderr: '', exitCode: 0}),
            cancel: notCancelled,
          });
          if (op.configureStub) {
            op.configureStub(git);
          }


          delete process.env.DISPLAY;
          process.env.GIT_ASKPASS = '/some/git-askpass.sh';
          process.env.SSH_ASKPASS = '/some/ssh-askpass.sh';
          process.env.GIT_SSH_COMMAND = '/original/ssh-command';

          await op.action();

          const [args, options] = execStub.getCall(0).args;

          // Used by https remotes
          assertGitConfigSetting(args, op.command, 'credential.helper', '.*git-credential-atom\\.sh');

          // Used by SSH remotes
          assert.match(options.env.DISPLAY, /^.+$/);
          assert.match(options.env.SSH_ASKPASS, /git-askpass-atom\.sh$/);
          assert.match(options.env.GIT_ASKPASS, /git-askpass-atom\.sh$/);
          if (process.platform === 'linux') {
            assert.match(options.env.GIT_SSH_COMMAND, /linux-ssh-wrapper\.sh$/);
          }

          // Preserved environment variables for subprocesses
          assert.equal(options.env.ATOM_GITHUB_ORIGINAL_GIT_ASKPASS, '/some/git-askpass.sh');
          assert.equal(options.env.ATOM_GITHUB_ORIGINAL_SSH_ASKPASS, '/some/ssh-askpass.sh');
          assert.equal(options.env.ATOM_GITHUB_ORIGINAL_GIT_SSH_COMMAND, '/original/ssh-command');
        });
      });
    });

    describe('createBlob({filePath})', function() {
      it('creates a blob for the file path specified and returns its sha', async function() {
        const workingDirPath = await cloneRepository('three-files');
        const git = createTestStrategy(workingDirPath);
        fs.writeFileSync(path.join(workingDirPath, 'a.txt'), 'qux\nfoo\nbar\n', 'utf8');
        const sha = await git.createBlob({filePath: 'a.txt'});
        assert.equal(sha, 'c9f54222977c93ea17ba4a5a53c611fa7f1aaf56');
        const contents = await git.exec(['cat-file', '-p', sha]);
        assert.equal(contents, 'qux\nfoo\nbar\n');
      });

      it('creates a blob for the stdin specified and returns its sha', async function() {
        const workingDirPath = await cloneRepository('three-files');
        const git = createTestStrategy(workingDirPath);
        const sha = await git.createBlob({stdin: 'foo\n'});
        assert.equal(sha, '257cc5642cb1a054f08cc83f2d943e56fd3ebe99');
        const contents = await git.exec(['cat-file', '-p', sha]);
        assert.equal(contents, 'foo\n');
      });

      it('propagates unexpected git errors from hash-object', async function() {
        const workingDirPath = await cloneRepository();
        const git = createTestStrategy(workingDirPath);
        sinon.stub(git, 'exec').rejects(new Error('shiiiit'));

        await assert.isRejected(git.createBlob({filePath: 'a.txt'}), /shiiiit/);
      });

      it('rejects if neither file path or stdin are provided', async function() {
        const workingDirPath = await cloneRepository();
        const git = createTestStrategy(workingDirPath);
        await assert.isRejected(git.createBlob(), /Must supply file path or stdin/);
      });
    });

    describe('expandBlobToFile(absFilePath, sha)', function() {
      it('restores blob contents for sha to specified file path', async function() {
        const workingDirPath = await cloneRepository('three-files');
        const git = createTestStrategy(workingDirPath);
        const absFilePath = path.join(workingDirPath, 'a.txt');
        fs.writeFileSync(absFilePath, 'qux\nfoo\nbar\n', 'utf8');
        const sha = await git.createBlob({filePath: 'a.txt'});
        fs.writeFileSync(absFilePath, 'modifications', 'utf8');
        await git.expandBlobToFile(absFilePath, sha);
        assert.equal(fs.readFileSync(absFilePath), 'qux\nfoo\nbar\n');
      });
    });

    describe('getBlobContents(sha)', function() {
      it('returns blob contents for sha', async function() {
        const workingDirPath = await cloneRepository('three-files');
        const git = createTestStrategy(workingDirPath);
        const sha = await git.createBlob({stdin: 'foo\nbar\nbaz\n'});
        const contents = await git.getBlobContents(sha);
        assert.equal(contents, 'foo\nbar\nbaz\n');
      });
    });

    describe('getFileMode(filePath)', function() {
      it('returns the file mode of the specified file', async function() {
        const workingDirPath = await cloneRepository('three-files');
        const git = createTestStrategy(workingDirPath);
        const absFilePath = path.join(workingDirPath, 'a.txt');
        fs.writeFileSync(absFilePath, 'qux\nfoo\nbar\n', 'utf8');

        assert.equal(await git.getFileMode('a.txt'), '100644');

        await git.exec(['update-index', '--chmod=+x', 'a.txt']);
        assert.equal(await git.getFileMode('a.txt'), '100755');
      });

      it('returns the file mode for untracked files', async function() {
        const workingDirPath = await cloneRepository('three-files');
        const git = createTestStrategy(workingDirPath);
        const absFilePath = path.join(workingDirPath, 'new-file.txt');
        fs.writeFileSync(absFilePath, 'qux\nfoo\nbar\n', 'utf8');
        const regularMode = (await fs.stat(absFilePath)).mode;
        const executableMode = regularMode | fs.constants.S_IXUSR; // eslint-disable-line no-bitwise

        assert.equal(await git.getFileMode('new-file.txt'), '100644');

        fs.chmodSync(absFilePath, executableMode);
        const expectedFileMode = process.platform === 'win32' ? '100644' : '100755';
        assert.equal(await git.getFileMode('new-file.txt'), expectedFileMode);

        const targetPath = path.join(workingDirPath, 'a.txt');
        const symlinkPath = path.join(workingDirPath, 'symlink.txt');
        fs.symlinkSync(targetPath, symlinkPath);
        assert.equal(await git.getFileMode('symlink.txt'), '120000');
      });

      it('returns the file mode for symlink file', async function() {
        const workingDirPath = await cloneRepository('symlinks');
        const git = createTestStrategy(workingDirPath);
        assert.equal(await git.getFileMode('symlink.txt'), 120000);
      });
    });

    describe('merging files', function() {
      describe('mergeFile(oursPath, commonBasePath, theirsPath, resultPath)', function() {
        it('merges ours/base/theirsPaths and writes to resultPath, returning {filePath, resultPath, conflicts}', async function() {
          const workingDirPath = await cloneRepository('three-files');
          const git = createTestStrategy(workingDirPath);

          const aPath = path.join(workingDirPath, 'a.txt');
          const withoutConflictPath = path.join(workingDirPath, 'results-without-conflict.txt');
          const withConflictPath = path.join(workingDirPath, 'results-with-conflict.txt');

          // current and other paths are the same, so no conflicts
          const resultsWithoutConflict = await git.mergeFile('a.txt', 'b.txt', 'a.txt', 'results-without-conflict.txt');
          assert.deepEqual(resultsWithoutConflict, {
            filePath: 'a.txt',
            resultPath: 'results-without-conflict.txt',
            conflict: false,
          });
          assert.equal(fs.readFileSync(withoutConflictPath, 'utf8'), fs.readFileSync(aPath, 'utf8'));

          // contents of current and other paths conflict
          const resultsWithConflict = await git.mergeFile('a.txt', 'b.txt', 'c.txt', 'results-with-conflict.txt');
          assert.deepEqual(resultsWithConflict, {
            filePath: 'a.txt',
            resultPath: 'results-with-conflict.txt',
            conflict: true,
          });
          const contents = fs.readFileSync(withConflictPath, 'utf8');
          assert.isTrue(contents.includes('<<<<<<<'));
          assert.isTrue(contents.includes('>>>>>>>'));
        });

        it('propagates unexpected git errors', async function() {
          const workingDirPath = await cloneRepository('three-files');
          const git = createTestStrategy(workingDirPath);
          sinon.stub(git, 'exec').rejects(new Error('ouch'));

          await assert.isRejected(git.mergeFile('a.txt', 'b.txt', 'c.txt', 'result.txt'), /ouch/);
        });
      });

      describe('updateIndex(filePath, commonBaseSha, oursSha, theirsSha)', function() {
        it('updates the index to have the appropriate shas, retaining the original file mode', async function() {
          const workingDirPath = await cloneRepository('three-files');
          const git = createTestStrategy(workingDirPath);
          const absFilePath = path.join(workingDirPath, 'a.txt');
          fs.writeFileSync(absFilePath, 'qux\nfoo\nbar\n', 'utf8');
          await git.exec(['update-index', '--chmod=+x', 'a.txt']);

          const commonBaseSha = '7f95a814cbd9b366c5dedb6d812536dfef2fffb7';
          const oursSha = '95d4c5b7b96b3eb0853f586576dc8b5ac54837e0';
          const theirsSha = '5da808cc8998a762ec2761f8be2338617f8f12d9';
          await git.writeMergeConflictToIndex('a.txt', commonBaseSha, oursSha, theirsSha);

          const index = await git.exec(['ls-files', '--stage', '--', 'a.txt']);
          assert.equal(index.trim(), dedent`
            100755 ${commonBaseSha} 1\ta.txt
            100755 ${oursSha} 2\ta.txt
            100755 ${theirsSha} 3\ta.txt
          `);
        });

        it('handles the case when oursSha, commonBaseSha, or theirsSha is null', async function() {
          const workingDirPath = await cloneRepository('three-files');
          const git = createTestStrategy(workingDirPath);
          const absFilePath = path.join(workingDirPath, 'a.txt');
          fs.writeFileSync(absFilePath, 'qux\nfoo\nbar\n', 'utf8');
          await git.exec(['update-index', '--chmod=+x', 'a.txt']);

          const commonBaseSha = '7f95a814cbd9b366c5dedb6d812536dfef2fffb7';
          const oursSha = '95d4c5b7b96b3eb0853f586576dc8b5ac54837e0';
          const theirsSha = '5da808cc8998a762ec2761f8be2338617f8f12d9';
          await git.writeMergeConflictToIndex('a.txt', commonBaseSha, null, theirsSha);

          let index = await git.exec(['ls-files', '--stage', '--', 'a.txt']);
          assert.equal(index.trim(), dedent`
            100755 ${commonBaseSha} 1\ta.txt
            100755 ${theirsSha} 3\ta.txt
          `);

          await git.writeMergeConflictToIndex('a.txt', commonBaseSha, oursSha, null);

          index = await git.exec(['ls-files', '--stage', '--', 'a.txt']);
          assert.equal(index.trim(), dedent`
            100755 ${commonBaseSha} 1\ta.txt
            100755 ${oursSha} 2\ta.txt
          `);

          await git.writeMergeConflictToIndex('a.txt', null, oursSha, theirsSha);

          index = await git.exec(['ls-files', '--stage', '--', 'a.txt']);
          assert.equal(index.trim(), dedent`
            100755 ${oursSha} 2\ta.txt
            100755 ${theirsSha} 3\ta.txt
          `);
        });
      });
    });

    describe('executeGitCommand', function() {
      it('shells out in process until WorkerManager instance is ready', async function() {
        if (process.env.ATOM_GITHUB_INLINE_GIT_EXEC) {
          this.skip();
          return;
        }

        const workingDirPath = await cloneRepository('three-files');
        const git = createTestStrategy(workingDirPath);
        const workerManager = WorkerManager.getInstance();
        sinon.stub(workerManager, 'isReady');
        sinon.stub(GitProcess, 'exec');
        sinon.stub(workerManager, 'request');

        workerManager.isReady.returns(false);
        git.executeGitCommand([], {});
        assert.equal(GitProcess.exec.callCount, 1);
        assert.equal(workerManager.request.callCount, 0);

        workerManager.isReady.returns(true);
        git.executeGitCommand([], {});
        assert.equal(GitProcess.exec.callCount, 1);
        assert.equal(workerManager.request.callCount, 1);

        workerManager.isReady.returns(false);
        git.executeGitCommand([], {});
        assert.equal(GitProcess.exec.callCount, 2);
        assert.equal(workerManager.request.callCount, 1);

        workerManager.isReady.returns(true);
        git.executeGitCommand([], {});
        assert.equal(GitProcess.exec.callCount, 2);
        assert.equal(workerManager.request.callCount, 2);
      });
    });

    describe('https authentication', function() {
      const envKeys = ['SSH_ASKPASS', 'GIT_ASKPASS'];
      let preserved;

      beforeEach(function() {
        preserved = {};
        for (let i = 0; i < envKeys.length; i++) {
          const key = envKeys[i];
          preserved[key] = process.env[key];
        }

        process.env.SSH_ASKPASS = '';
        process.env.GIT_ASKPASS = '';
      });

      afterEach(function() {
        for (let i = 0; i < envKeys.length; i++) {
          const key = envKeys[i];
          process.env[key] = preserved[key];
        }
      });

      async function withHttpRemote(options) {
        const workdir = await cloneRepository('three-files');
        const git = createTestStrategy(workdir, options);

        const mockGitServer = hock.createHock();

        const uploadPackAdvertisement = '001e# service=git-upload-pack\n' +
          '0000' +
          '005a66d11860af6d28eb38349ef83de475597cb0e8b4 HEAD\0multi_ack symref=HEAD:refs/heads/master\n' +
          '003f66d11860af6d28eb38349ef83de475597cb0e8b4 refs/heads/master\n' +
          '0000';

        // Accepted auth data:
        // me:open-sesame
        mockGitServer
          .get('/some/repo.git/info/refs?service=git-upload-pack')
          .reply(401, '', {'WWW-Authenticate': 'Basic realm="SomeRealm"'})
          .get('/some/repo.git/info/refs?service=git-upload-pack', {Authorization: 'Basic bWU6b3Blbi1zZXNhbWU='})
          .reply(200, uploadPackAdvertisement, {'Content-Type': 'application/x-git-upload-pack-advertisement'})
          .get('/some/repo.git/info/refs?service=git-upload-pack')
          .reply(400);

        const server = http.createServer(mockGitServer.handler);
        return new Promise(resolve => {
          server.listen(0, '127.0.0.1', async () => {
            const {address, port} = server.address();
            await git.setConfig('remote.mock.url', `http://${address}:${port}/some/repo.git`);
            await git.setConfig('remote.mock.fetch', '+refs/heads/*:refs/remotes/origin/*');

            resolve(git);
          });
        });
      }

      it('prompts for authentication data through Atom', async function() {
        let query = null;
        const git = await withHttpRemote({
          prompt: q => {
            query = q;
            return Promise.resolve({username: 'me', password: 'open-sesame'});
          },
        });

        await git.fetch('mock', 'master');

        assert.match(
          query.prompt,
          /^Please enter your credentials for http:\/\/(::|127\.0\.0\.1):[0-9]{0,5}/,
        );
        assert.isTrue(query.includeUsername);
      });

      it('fails the command on authentication failure', async function() {
        let query = null;
        const git = await withHttpRemote({
          prompt: q => {
            query = q;
            return Promise.resolve({username: 'me', password: 'whoops'});
          },
        });

        await assert.isRejected(git.fetch('mock', 'master'));

        assert.match(
          query.prompt,
          /^Please enter your credentials for http:\/\/(::|127\.0\.0\.1):[0-9]{0,5}/,
        );
        assert.isTrue(query.includeUsername);
      });

      it('fails the command on dialog cancel', async function() {
        if (process.env.ATOM_GITHUB_INLINE_GIT_EXEC) {
          this.skip();
          return;
        }

        let query = null;
        const git = await withHttpRemote({
          prompt: q => {
            query = q;
            return Promise.reject(new Error('nevermind'));
          },
        });

        await git.fetch('mock', 'master');

        assert.match(
          query.prompt,
          /^Please enter your credentials for http:\/\/(::|127\.0\.0\.1):[0-9]{0,5}/,
        );
        assert.isTrue(query.includeUsername);
      });

      it('prefers user-configured credential helpers if present', async function() {
        this.retries(5); // FLAKE

        let query = null;
        const git = await withHttpRemote({
          prompt: q => {
            query = q;
            return Promise.resolve();
          },
        });

        await git.setConfig(
          'credential.helper',
          normalizeGitHelperPath(path.join(__dirname, 'scripts', 'credential-helper-success.sh')),
        );

        await git.fetch('mock', 'master');

        assert.isNull(query);
      });

      it('falls back to Atom credential prompts if credential helpers are present but fail', async function() {
        let query = null;
        const git = await withHttpRemote({
          prompt: q => {
            query = q;
            return Promise.resolve({username: 'me', password: 'open-sesame'});
          },
        });

        await git.setConfig(
          'credential.helper',
          normalizeGitHelperPath(path.join(__dirname, 'scripts', 'credential-helper-notfound.sh')),
        );

        await git.fetch('mock', 'master');

        assert.match(
          query.prompt,
          /^Please enter your credentials for http:\/\/127\.0\.0\.1:[0-9]{0,5}/,
        );
        assert.isTrue(query.includeUsername);
      });

      it('falls back to Atom credential prompts if credential helpers are present but explode', async function() {
        this.retries(5);
        let query = null;
        const git = await withHttpRemote({
          prompt: q => {
            query = q;
            return Promise.resolve({username: 'me', password: 'open-sesame'});
          },
        });

        await git.setConfig(
          'credential.helper',
          normalizeGitHelperPath(path.join(__dirname, 'scripts', 'credential-helper-kaboom.sh')),
        );

        await git.fetch('mock', 'master');

        assert.match(
          query.prompt,
          /^Please enter your credentials for http:\/\/127\.0\.0\.1:[0-9]{0,5}/,
        );
        assert.isTrue(query.includeUsername);
      });
    });

    describe('ssh authentication', function() {
      const envKeys = ['GIT_SSH_COMMAND', 'SSH_AUTH_SOCK', 'SSH_ASKPASS', 'GIT_ASKPASS'];
      let preserved;

      beforeEach(function() {
        preserved = {};
        for (let i = 0; i < envKeys.length; i++) {
          const key = envKeys[i];
          preserved[key] = process.env[key];
        }

        delete process.env.SSH_AUTH_SOCK;
        process.env.SSH_ASKPASS = '';
        process.env.GIT_ASKPASS = '';
      });

      afterEach(function() {
        for (let i = 0; i < envKeys.length; i++) {
          const key = envKeys[i];
          process.env[key] = preserved[key];
        }
      });

      async function withSSHRemote(options) {
        const workdir = await cloneRepository('three-files');
        const git = createTestStrategy(workdir, options);

        await git.setConfig('remote.mock.url', 'git@github.com:atom/nope.git');
        await git.setConfig('remote.mock.fetch', '+refs/heads/*:refs/remotes/origin/*');

        // Append ' #' to ensure the script is run with sh on Windows.
        // https://github.com/git/git/blob/027a3b943b444a3e3a76f9a89803fc10245b858f/run-command.c#L196-L221
        process.env.GIT_SSH_COMMAND = normalizeGitHelperPath(path.join(__dirname, 'scripts', 'ssh-remote.sh')) + ' #';
        process.env.GIT_SSH_VARIANT = 'simple';

        return git;
      }

      it('prompts for an SSH password through Atom', async function() {
        let query = null;
        const git = await withSSHRemote({
          prompt: q => {
            query = q;
            return Promise.resolve({password: 'friend'});
          },
        });

        await git.fetch('mock', 'master');

        assert.equal(query.prompt, 'Speak friend and enter');
        assert.isFalse(query.includeUsername);
      });

      it('fails the command on authentication failure', async function() {
        let query = null;
        const git = await withSSHRemote({
          prompt: q => {
            query = q;
            return Promise.resolve({password: 'let me in damnit'});
          },
        });

        await assert.isRejected(git.fetch('mock', 'master'));

        assert.equal(query.prompt, 'Speak friend and enter');
        assert.isFalse(query.includeUsername);
      });

      it('fails the command on dialog cancel', async function() {
        let query = null;
        const git = await withSSHRemote({
          prompt: q => {
            query = q;
            return Promise.reject(new Error('nah'));
          },
        });

        await git.fetch('mock', 'master').catch(() => {});

        assert.equal(query.prompt, 'Speak friend and enter');
        assert.isFalse(query.includeUsername);
      });

      it('prefers a user-configured SSH_ASKPASS if present', async function() {
        let query = null;
        const git = await withSSHRemote({
          prompt: q => {
            query = q;
            return Promise.resolve({password: 'BZZT'});
          },
        });

        process.env.SSH_ASKPASS = normalizeGitHelperPath(path.join(__dirname, 'scripts', 'askpass-success.sh'));

        await git.fetch('mock', 'master');
        assert.isNull(query);
      });

      it('falls back to Atom credential prompts if SSH_ASKPASS is present but goes boom', async function() {
        let query = null;
        const git = await withSSHRemote({
          prompt: q => {
            query = q;
            return Promise.resolve({password: 'friend'});
          },
        });

        process.env.SSH_ASKPASS = normalizeGitHelperPath(path.join(__dirname, 'scripts', 'askpass-kaboom.sh'));

        await git.fetch('mock', 'master');

        assert.equal(query.prompt, 'Speak friend and enter');
        assert.isFalse(query.includeUsername);
      });
    });
  });
});

function assertGitConfigSetting(args, command, settingName, valuePattern = '.*$') {
  const commandIndex = args.indexOf(command);
  assert.notEqual(commandIndex, -1, `${command} not found in exec arguments ${args.join(' ')}`);

  const settingNamePattern = settingName.replace(/[.\\()[\]{}+*^$]/, '\\$&');

  const valueRx = new RegExp(`^${settingNamePattern}=${valuePattern}`);

  for (let i = 0; i < commandIndex; i++) {
    if (args[i] === '-c' && valueRx.test(args[i + 1] || '')) {
      return;
    }
  }

  assert.fail('', '', `Setting ${settingName} not found in exec arguments ${args.join(' ')}`);
}
