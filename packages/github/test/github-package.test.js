import fs from 'fs-extra';
import path from 'path';
import temp from 'temp';
import until from 'test-until';

import {cloneRepository, disableFilesystemWatchers} from './helpers';
import {fileExists, getTempDir} from '../lib/helpers';
import GithubPackage from '../lib/github-package';

describe('GithubPackage', function() {

  async function buildAtomEnvironmentAndGithubPackage(buildAtomEnvironment, options = {}) {
    const atomEnv = global.buildAtomEnvironment();
    await disableFilesystemWatchers(atomEnv);

    const packageOptions = {
      workspace: atomEnv.workspace,
      project: atomEnv.project,
      commands: atomEnv.commands,
      deserializers: atomEnv.deserializers,
      notificationManager: atomEnv.notifications,
      tooltips: atomEnv.tooltips,
      config: atomEnv.config,
      keymaps: atomEnv.keymaps,
      confirm: atomEnv.confirm.bind(atomEnv),
      styles: atomEnv.styles,
      grammars: atomEnv.grammars,
      getLoadSettings: atomEnv.getLoadSettings.bind(atomEnv),
      currentWindow: atomEnv.getCurrentWindow(),
      configDirPath: path.join(__dirname, 'fixtures', 'atomenv-config'),
      renderFn: sinon.stub().callsFake((component, element, callback) => {
        if (callback) {
          process.nextTick(callback);
        }
      }),
      ...options,
    };

    const githubPackage = new GithubPackage(packageOptions);

    const contextPool = githubPackage.getContextPool();

    return {
      atomEnv,
      ...packageOptions,
      githubPackage,
      contextPool,
    };
  }

  async function contextUpdateAfter(githubPackage, chunk) {
    const updatePromise = githubPackage.getSwitchboard().getFinishActiveContextUpdatePromise();
    await chunk();
    return updatePromise;
  }

  describe('construction', function() {
    let atomEnv;
    beforeEach(async function() {
      atomEnv = global.buildAtomEnvironment();
      await disableFilesystemWatchers(atomEnv);
    });

    afterEach(function() {
      atomEnv.destroy();
    });

    async function constructWith(projectPaths, initialPaths) {
      const realProjectPaths = await Promise.all(
        projectPaths.map(projectPath => getTempDir({prefix: projectPath})),
      );

      const {
        workspace, project, commands, notificationManager, tooltips,
        deserializers, config, keymaps, styles, grammars,
      } = atomEnv;

      const confirm = atomEnv.confirm.bind(atomEnv);
      const currentWindow = atomEnv.getCurrentWindow();
      const configDirPath = path.join(__dirname, 'fixtures/atomenv-config');
      const getLoadSettings = () => ({initialPaths});

      project.setPaths(realProjectPaths);

      return new GithubPackage({
        workspace, project, commands, notificationManager, tooltips,
        styles, grammars, keymaps, config, deserializers, confirm,
        getLoadSettings, currentWindow, configDirPath,
      });
    }

    function assertAbsentLike(githubPackage) {
      const repository = githubPackage.getActiveRepository();
      assert.isTrue(repository.isUndetermined());
      assert.isFalse(repository.showGitTabLoading());
      assert.isTrue(repository.showGitTabInit());
    }

    function assertLoadingLike(githubPackage) {
      const repository = githubPackage.getActiveRepository();
      assert.isTrue(repository.isUndetermined());
      assert.isTrue(repository.showGitTabLoading());
      assert.isFalse(repository.showGitTabInit());
    }

    it('with no projects or initial paths begins with an absent-like undetermined context', async function() {
      const githubPackage = await constructWith([], []);
      assertAbsentLike(githubPackage);
    });

    it('with one existing project begins with a loading-like undetermined context', async function() {
      const githubPackage = await constructWith(['one'], []);
      assertLoadingLike(githubPackage);
    });

    it('with several existing projects begins with an absent-like undetermined context', async function() {
      const githubPackage = await constructWith(['one', 'two'], []);
      assertAbsentLike(githubPackage);
    });

    it('with no projects but one initial path begins with a loading-like undetermined context', async function() {
      const githubPackage = await constructWith([], ['one']);
      assertLoadingLike(githubPackage);
    });

    it('with no projects and several initial paths begins with an absent-like undetermined context', async function() {
      const githubPackage = await constructWith([], ['one', 'two']);
      assertAbsentLike(githubPackage);
    });

    it('with one project and initial paths begins with a loading-like undetermined context', async function() {
      const githubPackage = await constructWith(['one'], ['two', 'three']);
      assertLoadingLike(githubPackage);
    });

    it('with several projects and an initial path begins with an absent-like undetermined context', async function() {
      const githubPackage = await constructWith(['one', 'two'], ['three']);
      assertAbsentLike(githubPackage);
    });
  });

  describe('activate()', function() {
    let atomEnv, githubPackage;
    let project, config, configDirPath, contextPool;

    beforeEach(async function() {
      ({
        atomEnv, githubPackage,
        project, config, configDirPath, contextPool,
      } = await buildAtomEnvironmentAndGithubPackage(global.buildAtomEnvironmentAndGithubPackage));
    });

    afterEach(async function() {
      await githubPackage.deactivate();

      atomEnv.destroy();
    });

    describe('with no projects or state', function() {
      beforeEach(async function() {
        await contextUpdateAfter(githubPackage, () => githubPackage.activate());
      });

      it('uses an undetermined repository context', function() {
        assert.isTrue(githubPackage.getActiveRepository().isUndetermined());
      });
    });

    describe('with only 1 project', function() {
      let workdirPath, context;
      beforeEach(async function() {
        workdirPath = await cloneRepository('three-files');
        project.setPaths([workdirPath]);

        await contextUpdateAfter(githubPackage, () => githubPackage.activate());
        context = contextPool.getContext(workdirPath);
      });

      it('uses the project\'s context', function() {
        assert.isTrue(context.isPresent());
        assert.strictEqual(githubPackage.getActiveWorkdir(), workdirPath);
        assert.strictEqual(context.getRepository(), githubPackage.getActiveRepository());
        assert.strictEqual(context.getResolutionProgress(), githubPackage.getActiveResolutionProgress());
      });
    });

    describe('with only projects', function() {
      let workdirPath1, workdirPath2, nonRepositoryPath, context1;
      beforeEach(async function() {
        ([workdirPath1, workdirPath2, nonRepositoryPath] = await Promise.all([
          cloneRepository('three-files'),
          cloneRepository('three-files'),
          getTempDir(),
        ]));
        project.setPaths([workdirPath1, workdirPath2, nonRepositoryPath]);

        await contextUpdateAfter(githubPackage, () => githubPackage.activate());

        context1 = contextPool.getContext(workdirPath1);
      });

      it('uses the first project\'s context', function() {
        assert.isTrue(context1.isPresent());
        assert.strictEqual(githubPackage.getActiveWorkdir(), workdirPath1);
        assert.strictEqual(context1.getRepository(), githubPackage.getActiveRepository());
        assert.strictEqual(context1.getResolutionProgress(), githubPackage.getActiveResolutionProgress());
      });

      it('creates contexts from preexisting projects', function() {
        assert.isTrue(contextPool.getContext(workdirPath1).isPresent());
        assert.isTrue(contextPool.getContext(workdirPath2).isPresent());
        assert.isTrue(contextPool.getContext(nonRepositoryPath).isPresent());
      });
    });

    describe('with projects and state', function() {
      let workdirPath1, workdirPath2, workdirPath3;
      beforeEach(async function() {
        ([workdirPath1, workdirPath2, workdirPath3] = await Promise.all([
          cloneRepository('three-files'),
          cloneRepository('three-files'),
          cloneRepository('three-files'),
        ]));
        project.setPaths([workdirPath1, workdirPath2, workdirPath3]);

        await contextUpdateAfter(githubPackage, () => githubPackage.activate({
          activeRepositoryPath: workdirPath2,
        }));
      });

      it('uses the serialized state\'s context', function() {
        const context = contextPool.getContext(workdirPath2);
        assert.isTrue(context.isPresent());
        assert.strictEqual(context.getRepository(), githubPackage.getActiveRepository());
        assert.strictEqual(context.getResolutionProgress(), githubPackage.getActiveResolutionProgress());
        assert.strictEqual(githubPackage.getActiveWorkdir(), workdirPath2);
      });
    });

    describe('with 1 project and absent state', function() {
      let workdirPath1, workdirPath2, context1;
      beforeEach(async function() {
        ([workdirPath1, workdirPath2] = await Promise.all([
          cloneRepository('three-files'),
          cloneRepository('three-files'),
        ]));
        project.setPaths([workdirPath1]);

        await contextUpdateAfter(githubPackage, () => githubPackage.activate({
          activeRepositoryPath: workdirPath2,
        }));
        context1 = contextPool.getContext(workdirPath1);
      });

      it('uses the project\'s context', function() {
        assert.isTrue(context1.isPresent());
        assert.strictEqual(githubPackage.getActiveWorkdir(), workdirPath1);
        assert.strictEqual(context1.getRepository(), githubPackage.getActiveRepository());
        assert.strictEqual(context1.getResolutionProgress(), githubPackage.getActiveResolutionProgress());
      });
    });

    describe('with showOnStartup and no config file', function() {
      let confFile;
      beforeEach(async function() {
        confFile = path.join(configDirPath, 'github.cson');
        await fs.remove(confFile);

        config.set('welcome.showOnStartup', true);
        await githubPackage.activate();
      });

      it('renders with startOpen', function() {
        assert.isTrue(githubPackage.startOpen);
      });

      it('renders without startRevealed', function() {
        assert.isFalse(githubPackage.startRevealed);
      });

      it('writes a config', async function() {
        assert.isTrue(await fileExists(confFile));
      });
    });

    describe('without showOnStartup and no config file', function() {
      let confFile;
      beforeEach(async function() {
        confFile = path.join(configDirPath, 'github.cson');
        await fs.remove(confFile);

        config.set('welcome.showOnStartup', false);
        await githubPackage.activate();
      });

      it('renders with startOpen', function() {
        assert.isTrue(githubPackage.startOpen);
      });

      it('renders with startRevealed', function() {
        assert.isTrue(githubPackage.startRevealed);
      });

      it('writes a config', async function() {
        assert.isTrue(await fileExists(confFile));
      });
    });

    describe('when it\'s not the first run for new projects', function() {
      let confFile;
      beforeEach(async function() {
        confFile = path.join(configDirPath, 'github.cson');
        await fs.writeFile(confFile, '', {encoding: 'utf8'});
        await githubPackage.activate();
      });

      it('renders with startOpen', function() {
        assert.isTrue(githubPackage.startOpen);
      });

      it('renders without startRevealed', function() {
        assert.isFalse(githubPackage.startRevealed);
      });

      it('has a config', async function() {
        assert.isTrue(await fileExists(confFile));
      });
    });

    describe('when it\'s not the first run for existing projects', function() {
      let confFile;
      beforeEach(async function() {
        confFile = path.join(configDirPath, 'github.cson');
        await fs.writeFile(confFile, '', {encoding: 'utf8'});
        await githubPackage.activate({newProject: false});
      });

      it('renders without startOpen', function() {
        assert.isFalse(githubPackage.startOpen);
      });

      it('renders without startRevealed', function() {
        assert.isFalse(githubPackage.startRevealed);
      });

      it('has a config', async function() {
        assert.isTrue(await fileExists(confFile));
      });
    });
  });

  describe('scheduleActiveContextUpdate()', function() {
    let atomEnv, githubPackage;
    let project, contextPool;

    beforeEach(async function() {
      ({
        atomEnv, githubPackage,
        project, contextPool,
      } = await buildAtomEnvironmentAndGithubPackage(global.buildAtomEnvironmentAndGithubPackage));
    });

    afterEach(async function() {
      await githubPackage.deactivate();

      atomEnv.destroy();
    });

    describe('with no projects', function() {
      beforeEach(async function() {
        await contextUpdateAfter(githubPackage, () => githubPackage.activate());
      });

      it('uses an absent guess repository', function() {
        assert.isTrue(githubPackage.getActiveRepository().isAbsentGuess());
      });
    });

    describe('with existing projects', function() {
      let workdirPath1, workdirPath2, workdirPath3;
      beforeEach(async function() {
        ([workdirPath1, workdirPath2, workdirPath3] = await Promise.all([
          cloneRepository('three-files'),
          cloneRepository('three-files'),
          cloneRepository('three-files'),
        ]));
        project.setPaths([workdirPath1, workdirPath2]);

        await contextUpdateAfter(githubPackage, () => githubPackage.activate());
      });

      it('uses the first project\'s context', function() {
        const context1 = contextPool.getContext(workdirPath1);
        assert.isTrue(context1.isPresent());
        assert.strictEqual(githubPackage.getActiveWorkdir(), workdirPath1);
        assert.strictEqual(context1.getRepository(), githubPackage.getActiveRepository());
        assert.strictEqual(context1.getResolutionProgress(), githubPackage.getActiveResolutionProgress());
      });

      it('has no contexts for projects that are not open', function() {
        assert.isFalse(contextPool.getContext(workdirPath3).isPresent());
      });

      describe('when opening a new project', function() {
        beforeEach(async function() {
          await contextUpdateAfter(githubPackage, () => project.setPaths([workdirPath1, workdirPath2, workdirPath3]));
        });

        it('creates a new context', function() {
          assert.isTrue(contextPool.getContext(workdirPath3).isPresent());
        });
      });

      describe('when removing a project', function() {
        it('removes the project\'s context', async function() {
          await contextUpdateAfter(githubPackage, () => project.setPaths([workdirPath1]));

          assert.isFalse(contextPool.getContext(workdirPath2).isPresent());
          assert.strictEqual(githubPackage.getActiveWorkdir(), workdirPath1);
        });

        it('does nothing if the context is locked', async function() {
          await githubPackage.scheduleActiveContextUpdate({
            usePath: workdirPath2,
            lock: true,
          });

          await contextUpdateAfter(githubPackage, () => project.setPaths([workdirPath1]));

          assert.isTrue(contextPool.getContext(workdirPath2).isPresent());
          assert.strictEqual(githubPackage.getActiveWorkdir(), workdirPath2);
        });
      });

      describe('when removing all projects', function() {
        beforeEach(async function() {
          await contextUpdateAfter(githubPackage, () => project.setPaths([]));
        });

        it('removes the projects\' context', function() {
          assert.isFalse(contextPool.getContext(workdirPath1).isPresent());
        });

        it('uses an absent repo', function() {
          assert.isTrue(githubPackage.getActiveRepository().isAbsent());
        });
      });

      describe('when changing the active pane item', function() {
        it('follows the active pane item', async function() {
          const itemPath2 = path.join(workdirPath2, 'b.txt');

          assert.strictEqual(githubPackage.getActiveWorkdir(), workdirPath1);
          await contextUpdateAfter(githubPackage, () => atomEnv.workspace.open(itemPath2));
          assert.strictEqual(githubPackage.getActiveWorkdir(), workdirPath2);
        });

        it('does nothing if the context is locked', async function() {
          const itemPath2 = path.join(workdirPath2, 'c.txt');

          await githubPackage.scheduleActiveContextUpdate({
            usePath: workdirPath1,
            lock: true,
          });

          assert.strictEqual(githubPackage.getActiveWorkdir(), workdirPath1);
          await contextUpdateAfter(githubPackage, () => atomEnv.workspace.open(itemPath2));
          assert.strictEqual(githubPackage.getActiveWorkdir(), workdirPath1);
        });
      });

      describe('with a locked context', function() {
        it('preserves the locked context in the pool', async function() {
          await githubPackage.scheduleActiveContextUpdate({
            usePath: workdirPath1,
            lock: true,
          });

          await contextUpdateAfter(githubPackage, () => project.setPaths([workdirPath2]));

          assert.isTrue(contextPool.getContext(workdirPath1).isPresent());
          assert.isTrue(contextPool.getContext(workdirPath2).isPresent());

          assert.strictEqual(githubPackage.getActiveWorkdir(), workdirPath1);
        });

        it('may be unlocked', async function() {
          const itemPath1a = path.join(workdirPath1, 'a.txt');
          const itemPath1b = path.join(workdirPath2, 'b.txt');

          await githubPackage.scheduleActiveContextUpdate({
            usePath: workdirPath2,
            lock: true,
          });

          await contextUpdateAfter(githubPackage, () => atomEnv.workspace.open(itemPath1a));
          assert.strictEqual(githubPackage.getActiveWorkdir(), workdirPath2);

          await githubPackage.scheduleActiveContextUpdate({
            usePath: workdirPath1,
            lock: false,
          });

          await contextUpdateAfter(githubPackage, () => atomEnv.workspace.open(itemPath1b));
          assert.strictEqual(githubPackage.getActiveWorkdir(), workdirPath1);
        });

        it('triggers a re-render when the context is unchanged', async function() {
          sinon.stub(githubPackage, 'rerender');

          assert.strictEqual(githubPackage.getActiveWorkdir(), workdirPath1);
          await githubPackage.scheduleActiveContextUpdate({
            usePath: workdirPath1,
            lock: true,
          });

          assert.strictEqual(githubPackage.getActiveWorkdir(), workdirPath1);
          assert.isTrue(githubPackage.rerender.called);
          githubPackage.rerender.resetHistory();

          await githubPackage.scheduleActiveContextUpdate({
            usePath: workdirPath1,
            lock: false,
          });

          assert.strictEqual(githubPackage.getActiveWorkdir(), workdirPath1);
          assert.isTrue(githubPackage.rerender.called);
        });
      });

      it('does nothing when the workspace is destroyed', async function() {
        sinon.stub(githubPackage, 'rerender');
        atomEnv.destroy();

        await githubPackage.scheduleActiveContextUpdate({
          usePath: workdirPath2,
        });

        assert.isFalse(githubPackage.rerender.called);
        assert.strictEqual(githubPackage.getActiveWorkdir(), workdirPath1);
      });
    });

    describe('with non-repository, no-conflict, and in-progress merge-conflict projects', function() {
      let nonRepositoryPath, workdirNoConflict, workdirMergeConflict;
      const remainingMarkerCount = 3;

      beforeEach(async function() {
        workdirMergeConflict = await cloneRepository('merge-conflict');
        workdirNoConflict = await cloneRepository('three-files');
        nonRepositoryPath = await fs.realpath(temp.mkdirSync());
        fs.writeFileSync(path.join(nonRepositoryPath, 'c.txt'));
        project.setPaths([workdirMergeConflict, workdirNoConflict, nonRepositoryPath]);
        await contextUpdateAfter(githubPackage, () => githubPackage.activate());
        const resolutionMergeConflict = contextPool.getContext(workdirMergeConflict).getResolutionProgress();
        resolutionMergeConflict.reportMarkerCount('modified-on-both-ours.txt', remainingMarkerCount);
      });

      describe('when selecting an in-progress merge-conflict project', function() {
        let resolutionMergeConflict;
        beforeEach(async function() {
          await githubPackage.scheduleActiveContextUpdate({
            usePath: workdirMergeConflict,
          });
          resolutionMergeConflict = contextPool.getContext(workdirMergeConflict).getResolutionProgress();
        });

        it('uses the project\'s resolution progress', function() {
          assert.strictEqual(githubPackage.getActiveResolutionProgress(), resolutionMergeConflict);
        });

        it('has active resolution progress', function() {
          assert.isFalse(githubPackage.getActiveResolutionProgress().isEmpty());
        });

        it('has the correct number of remaining markers', function() {
          assert.strictEqual(githubPackage.getActiveResolutionProgress().getRemaining('modified-on-both-ours.txt'), remainingMarkerCount);
        });
      });

      describe('when opening a no-conflict repository project', function() {
        let resolutionNoConflict;
        beforeEach(async function() {
          await githubPackage.scheduleActiveContextUpdate({
            usePath: workdirNoConflict,
          });
          resolutionNoConflict = contextPool.getContext(workdirNoConflict).getResolutionProgress();
        });

        it('uses the project\'s resolution progress', function() {
          assert.strictEqual(githubPackage.getActiveResolutionProgress(), resolutionNoConflict);
        });

        it('has no active resolution progress', function() {
          assert.isTrue(githubPackage.getActiveResolutionProgress().isEmpty());
        });
      });

      describe('when opening a non-repository project', function() {
        beforeEach(async function() {
          await githubPackage.scheduleActiveContextUpdate({
            usePath: nonRepositoryPath,
          });
        });

        it('has no active resolution progress', function() {
          assert.isTrue(githubPackage.getActiveResolutionProgress().isEmpty());
        });
      });
    });

    describe('with projects and absent state', function() {
      let workdirPath1, workdirPath2, workdirPath3, context1;
      beforeEach(async function() {
        ([workdirPath1, workdirPath2, workdirPath3] = await Promise.all([
          cloneRepository('three-files'),
          cloneRepository('three-files'),
          cloneRepository('three-files'),
        ]));
        project.setPaths([workdirPath1, workdirPath2]);

        await githubPackage.scheduleActiveContextUpdate({
          usePath: workdirPath3,
        });
        context1 = contextPool.getContext(workdirPath1);
      });

      it('uses the first project\'s context', function() {
        assert.isTrue(context1.isPresent());
        assert.strictEqual(context1.getRepository(), githubPackage.getActiveRepository());
        assert.strictEqual(context1.getResolutionProgress(), githubPackage.getActiveResolutionProgress());
        assert.strictEqual(githubPackage.getActiveWorkdir(), workdirPath1);
      });
    });

    describe('with 1 project and state', function() {
      let workdirPath1, workdirPath2, context1;
      beforeEach(async function() {
        ([workdirPath1, workdirPath2] = await Promise.all([
          cloneRepository('three-files'),
          cloneRepository('three-files'),
        ]));
        project.setPaths([workdirPath1]);

        await githubPackage.scheduleActiveContextUpdate({
          usePath: workdirPath2,
        });
        context1 = contextPool.getContext(workdirPath1);
      });

      it('uses the project\'s context', function() {
        assert.isTrue(context1.isPresent());
        assert.strictEqual(githubPackage.getActiveWorkdir(), workdirPath1);
        assert.strictEqual(context1.getRepository(), githubPackage.getActiveRepository());
        assert.strictEqual(context1.getResolutionProgress(), githubPackage.getActiveResolutionProgress());
      });
    });

    describe('with projects and state', function() {
      let workdirPath1, workdirPath2;
      beforeEach(async function() {
        ([workdirPath1, workdirPath2] = await Promise.all([
          cloneRepository('three-files'),
          cloneRepository('three-files'),
        ]));
        project.setPaths([workdirPath1, workdirPath2]);

        await githubPackage.scheduleActiveContextUpdate({
          usePath: workdirPath2,
        });
      });

      it('uses the state\'s context', function() {
        assert.strictEqual(githubPackage.getActiveWorkdir(), workdirPath2);
      });
    });

    describe('with a non-repository project', function() {
      let nonRepositoryPath;
      beforeEach(async function() {
        nonRepositoryPath = await getTempDir();
        project.setPaths([nonRepositoryPath]);

        await githubPackage.scheduleActiveContextUpdate();
        await githubPackage.getActiveRepository().getLoadPromise();
      });

      it('creates a context for the project', function() {
        assert.isTrue(contextPool.getContext(nonRepositoryPath).isPresent());
      });

      it('is not cached', async function() {
        assert.isNull(await githubPackage.workdirCache.find(nonRepositoryPath));
      });

      it('uses an empty repository', function() {
        assert.isTrue(githubPackage.getActiveRepository().isEmpty());
      });

      it('does not use an absent repository', function() {
        assert.isFalse(githubPackage.getActiveRepository().isAbsent());
      });
    });

    describe('with a repository project\'s subdirectory', function() {
      let workdirPath;
      beforeEach(async function() {
        workdirPath = await cloneRepository('three-files');
        const projectPath = path.join(workdirPath, 'subdir-1');
        project.setPaths([projectPath]);

        await githubPackage.scheduleActiveContextUpdate();
      });

      it('uses the repository\'s project context', function() {
        assert.strictEqual(githubPackage.getActiveWorkdir(), workdirPath);
      });
    });

    describe('with a repository project', function() {
      let workdirPath;
      beforeEach(async function() {
        workdirPath = await cloneRepository('three-files');
        project.setPaths([workdirPath]);

        await githubPackage.scheduleActiveContextUpdate();
      });

      it('creates a context for the project', function() {
        assert.isTrue(contextPool.getContext(workdirPath).isPresent());
      });

      describe('when the repository is destroyed', function() {
        beforeEach(function() {
          const repository = contextPool.getContext(workdirPath).getRepository();
          repository.destroy();
        });

        it('uses an absent repository', function() {
          assert.isTrue(githubPackage.getActiveRepository().isAbsent());
        });
      });
    });

    describe('with a symlinked repository project', function() {
      beforeEach(async function() {
        if (process.platform === 'win32') {
          this.skip();
        }
        const workdirPath = await cloneRepository('three-files');
        const symlinkPath = (await fs.realpath(temp.mkdirSync())) + '-symlink';
        fs.symlinkSync(workdirPath, symlinkPath);
        project.setPaths([symlinkPath]);

        await githubPackage.scheduleActiveContextUpdate();
      });

      it('uses a repository', async function() {
        await assert.async.isOk(githubPackage.getActiveRepository());
      });
    });
  });

  describe('initialize()', function() {
    let atomEnv, githubPackage;
    let project, contextPool;

    beforeEach(async function() {
      ({
        atomEnv, githubPackage,
        project, contextPool,
      } = await buildAtomEnvironmentAndGithubPackage(global.buildAtomEnvironmentAndGithubPackage));
    });

    afterEach(async function() {
      await githubPackage.deactivate();

      atomEnv.destroy();
    });

    describe('with a non-repository project', function() {
      let nonRepositoryPath;
      beforeEach(async function() {
        nonRepositoryPath = await getTempDir();
        project.setPaths([nonRepositoryPath]);

        await contextUpdateAfter(githubPackage, () => githubPackage.activate());
        await githubPackage.getActiveRepository().getLoadPromise();

        await githubPackage.initialize(nonRepositoryPath);
      });

      it('creates a repository for the project', function() {
        assert.isTrue(githubPackage.getActiveRepository().isPresent());
      });

      it('uses the newly created repository for the project', async function() {
        assert.strictEqual(
          githubPackage.getActiveRepository(),
          await contextPool.getContext(nonRepositoryPath).getRepository(),
        );
      });
    });
  });

  describe('clone()', function() {
    let atomEnv, githubPackage;
    let project;

    beforeEach(async function() {
      ({
        atomEnv, githubPackage,
        project,
      } = await buildAtomEnvironmentAndGithubPackage(global.buildAtomEnvironmentAndGithubPackage));
    });

    afterEach(async function() {
      await githubPackage.deactivate();

      atomEnv.destroy();
    });

    describe('with an existing project', function() {
      let existingPath, sourcePath;

      // Setup files and the GitHub Package
      beforeEach(async function() {
        sourcePath = await cloneRepository();
        existingPath = await getTempDir();
        project.setPaths([existingPath]);

        await contextUpdateAfter(githubPackage, () => githubPackage.activate());
        const repository = githubPackage.getActiveRepository();
        await repository.getLoadPromise();
      });

      // Clone
      beforeEach(async function() {
        await githubPackage.clone(sourcePath, existingPath);
      });

      it('clones into the existing project', async function() {
        assert.strictEqual(await githubPackage.workdirCache.find(existingPath), existingPath);
      });
    });

    describe('with no projects', function() {
      let newPath, sourcePath, originalRepo;

      // Setup files and the GitHub Package
      beforeEach(async function() {
        sourcePath = await cloneRepository();
        newPath = await getTempDir();

        await contextUpdateAfter(githubPackage, () => githubPackage.activate());
        originalRepo = githubPackage.getActiveRepository();
        await originalRepo.getLoadPromise();
      });

      // Clone and Update context
      beforeEach(async function() {
        await contextUpdateAfter(githubPackage, () => githubPackage.clone(sourcePath, newPath));
      });

      it('creates a new project', function() {
        assert.deepEqual(project.getPaths(), [newPath]);
      });

      it('clones into a new project', function() {
        const replaced = githubPackage.getActiveRepository();
        assert.notStrictEqual(originalRepo, replaced);
      });
    });
  });

  describe('createCommitPreviewStub()', function() {
    let atomEnv, githubPackage;

    beforeEach(async function() {
      ({
        atomEnv, githubPackage,
      } = await buildAtomEnvironmentAndGithubPackage(global.buildAtomEnvironmentAndGithubPackage));

      sinon.spy(githubPackage, 'rerender');
    });

    afterEach(async function() {
      await githubPackage.deactivate();

      atomEnv.destroy();
    });

    describe('when called before the initial render', function() {
      let item;
      beforeEach(function() {
        item = githubPackage.createCommitPreviewStub({uri: 'atom-github://commit-preview'});
      });

      it('does not call rerender', function() {
        assert.isFalse(githubPackage.rerender.called);
      });

      it('creates a stub item for a commit preview item', function() {
        assert.strictEqual(item.getTitle(), 'Commit preview');
        assert.strictEqual(item.getURI(), 'atom-github://commit-preview');
      });
    });

    describe('when called after the initial render', function() {
      let item;
      beforeEach(function() {
        githubPackage.controller = Symbol('controller');
        item = githubPackage.createCommitPreviewStub({uri: 'atom-github://commit-preview'});
      });

      it('calls rerender', function() {
        assert.isTrue(githubPackage.rerender.called);
      });

      it('creates a stub item for a commit preview item', function() {
        assert.strictEqual(item.getTitle(), 'Commit preview');
        assert.strictEqual(item.getURI(), 'atom-github://commit-preview');
      });
    });
  });

  describe('createCommitDetailStub()', function() {
    let atomEnv, githubPackage;

    beforeEach(async function() {
      ({
        atomEnv, githubPackage,
      } = await buildAtomEnvironmentAndGithubPackage(global.buildAtomEnvironmentAndGithubPackage));

      sinon.spy(githubPackage, 'rerender');
    });

    afterEach(async function() {
      await githubPackage.deactivate();

      atomEnv.destroy();
    });

    describe('when called before the initial render', function() {
      let item;
      beforeEach(function() {
        item = githubPackage.createCommitDetailStub({uri: 'atom-github://commit-detail?workdir=/home&sha=1234'});
      });

      it('does not call rerender', function() {
        assert.isFalse(githubPackage.rerender.called);
      });

      it('creates a stub item for a commit detail item', function() {
        assert.strictEqual(item.getTitle(), 'Commit');
        assert.strictEqual(item.getURI(), 'atom-github://commit-detail?workdir=/home&sha=1234');
      });
    });

    describe('when called after the initial render', function() {
      let item;
      beforeEach(function() {
        githubPackage.controller = Symbol('controller');
        item = githubPackage.createCommitDetailStub({uri: 'atom-github://commit-detail?workdir=/home&sha=1234'});
      });

      it('calls rerender', function() {
        assert.isTrue(githubPackage.rerender.called);
      });

      it('creates a stub item for a commit detail item', function() {
        assert.strictEqual(item.getTitle(), 'Commit');
        assert.strictEqual(item.getURI(), 'atom-github://commit-detail?workdir=/home&sha=1234');
      });
    });
  });

  describe('with repository projects', function() {
    let atomEnv, githubPackage;
    let project, contextPool;

    // Build Atom Environment and create the GitHub Package
    beforeEach(async function() {
      ({
        atomEnv, githubPackage,
        project, contextPool,
      } = await buildAtomEnvironmentAndGithubPackage(global.buildAtomEnvironmentAndGithubPackage));
    });

    let workdirPath1, atomGitRepository1, repository1;
    let workdirPath2, atomGitRepository2, repository2;

    // Setup file system.
    beforeEach(async function() {
      [workdirPath1, workdirPath2] = await Promise.all([
        cloneRepository('three-files'),
        cloneRepository('three-files'),
      ]);

      fs.writeFileSync(path.join(workdirPath1, 'c.txt'), 'ch-ch-ch-changes', 'utf8');
      fs.writeFileSync(path.join(workdirPath2, 'c.txt'), 'ch-ch-ch-changes', 'utf8');
    });

    // Setup up GitHub Package and file watchers
    beforeEach(async function() {
      project.setPaths([workdirPath1, workdirPath2]);
      await githubPackage.activate();

      const watcherPromises = [
        until(() => contextPool.getContext(workdirPath1).getChangeObserver().isStarted()),
        until(() => contextPool.getContext(workdirPath2).getChangeObserver().isStarted()),
      ];

      if (project.getWatcherPromise) {
        watcherPromises.push(project.getWatcherPromise(workdirPath1));
        watcherPromises.push(project.getWatcherPromise(workdirPath2));
      }

      await Promise.all(watcherPromises);
    });

    // Stub the repositories functions and spy on rerender
    beforeEach(function() {
      [atomGitRepository1, atomGitRepository2] = githubPackage.project.getRepositories();
      sinon.stub(atomGitRepository1, 'refreshStatus');
      sinon.stub(atomGitRepository2, 'refreshStatus');

      repository1 = contextPool.getContext(workdirPath1).getRepository();
      repository2 = contextPool.getContext(workdirPath2).getRepository();
      sinon.stub(repository1, 'observeFilesystemChange');
      sinon.stub(repository2, 'observeFilesystemChange');
    });

    // Destroy Atom Environment and the GitHub Package
    afterEach(async function() {
      await githubPackage.deactivate();

      atomEnv.destroy();
    });

    describe('when a file change is made outside Atom in workspace 1', function() {
      beforeEach(function() {
        if (process.platform === 'linux') {
          this.skip();
        }

        fs.writeFileSync(path.join(workdirPath1, 'a.txt'), 'some changes', 'utf8');
      });

      it('refreshes the corresponding repository', async function() {
        await assert.async.isTrue(repository1.observeFilesystemChange.called);
      });

      it('refreshes the corresponding Atom GitRepository', async function() {
        await assert.async.isTrue(atomGitRepository1.refreshStatus.called);
      });
    });

    describe('when a file change is made outside Atom in workspace 2', function() {
      beforeEach(function() {
        if (process.platform === 'linux') {
          this.skip();
        }

        fs.writeFileSync(path.join(workdirPath2, 'b.txt'), 'other changes', 'utf8');
      });

      it('refreshes the corresponding repository', async function() {
        await assert.async.isTrue(repository2.observeFilesystemChange.called);
      });

      it('refreshes the corresponding Atom GitRepository', async function() {
        await assert.async.isTrue(atomGitRepository2.refreshStatus.called);
      });
    });

    describe('when a commit is made outside Atom in workspace 1', function() {
      beforeEach(async function() {
        await repository1.git.exec(['commit', '-am', 'commit in repository1']);
      });

      it('refreshes the corresponding repository', async function() {
        await assert.async.isTrue(repository1.observeFilesystemChange.called);
      });

      it('refreshes the corresponding Atom GitRepository', async function() {
        await assert.async.isTrue(atomGitRepository1.refreshStatus.called);
      });
    });

    describe('when a commit is made outside Atom in workspace 2', function() {
      beforeEach(async function() {
        await repository2.git.exec(['commit', '-am', 'commit in repository2']);
      });

      it('refreshes the corresponding repository', async function() {
        await assert.async.isTrue(repository2.observeFilesystemChange.called);
      });

      it('refreshes the corresponding Atom GitRepository', async function() {
        await assert.async.isTrue(atomGitRepository2.refreshStatus.called);
      });
    });
  });
});
