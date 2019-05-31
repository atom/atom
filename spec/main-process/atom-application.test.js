/* globals assert */

const path = require('path');
const { EventEmitter } = require('events');
const temp = require('temp').track();
const fs = require('fs-plus');
const electron = require('electron');
const { sandbox } = require('sinon');

const AtomApplication = require('../../src/main-process/atom-application');
const parseCommandLine = require('../../src/main-process/parse-command-line');
const {
  emitterEventPromise,
  conditionPromise
} = require('../async-spec-helpers');

// These tests use a utility class called LaunchScenario, defined below, to manipulate AtomApplication instances that
// (1) are stubbed to only simulate AtomWindow creation and (2) allow you to use a shorthand notation to assert the
// application state after certain launch actions.
//
// Each scenario instance has access to a small set of directories and files created within a dedicated temporary
// directory. For convenience, you may use short names to refer to any of its contents (their basenames, basically).
// Check `LaunchScenario::init()` to see what directories and files are available.
//
// To create an application and its first window, call `await scenario.launch({})`. "Launch" may open multiple windows,
// so it returns a Promise that resolves to an array of StubWindows. Its options argument may be created by
// `parseCommandLine()` from a simulated argv string, or built by hand to include `{pathsToOpen}` and so on.
//
// To create additional windows, call `await scenario.open({})` with similar arguments. `LaunchScenario::open()` returns
// a Promise that resolves to the opened or re-used StubWindows. The one exception is if `urlsToOpen` are provided in the open
// arguments; then it resolves to an Array of StubWindows, because AtomApplication processes each URL individually.
//
// To ensure that the expected windows have been created, call `await scenario.assert('')` with a string specifying the
// expected window contents. The specification shorthand language is as follows:
//
// * '[_ _]' describes a single window with no project roots and no open editors.
// * '[_ 1.md]' describes a single window with no project roots and a single editor open on the file `./a/1.md` within
//   the LaunchScenario temporary directory.
// * '[a _]' describes a single window with one project root - the directory `./a` within the LaunchScenario temporary
//   directory - and no open editors.
// * '[a,b 1.md,2.md]' describes a single window with two project roots - the directories `./a` and `./b` - and two
//   open editors - `./a/1.md` and `./b/2.md`.
// * '[a _] [b,c 2.md]' describes two windows, one with a project root of `./a` and no open editors, and another with
//   two project roots, `./b` and `./c`, and one open editor on `./b/2.md`. The windows are listed in their expected
//   creation order.

describe('AtomApplication', function() {
  let scenario, sinon;

  beforeEach(async function() {
    sinon = sandbox.create();
    scenario = await LaunchScenario.create(sinon);
  });

  afterEach(async function() {
    await scenario.destroy();
    sinon.restore();
  });

  describe('command-line interface behavior', function() {
    describe('with no open windows', function() {
      // This is also the case when a user selects the application from the OS shell
      it('opens an empty window', async function() {
        await scenario.launch(parseCommandLine([]));
        await scenario.assert('[_ _]');
      });

      // This is also the case when a user clicks on a file in their file manager
      it('opens a file', async function() {
        await scenario.open(parseCommandLine(['a/1.md']));
        await scenario.assert('[_ 1.md]');
      });

      // This is also the case when a user clicks on a folder in their file manager
      // (or, on macOS, drags the folder to Atom in their doc)
      it('opens a directory', async function() {
        await scenario.open(parseCommandLine(['a']));
        await scenario.assert('[a _]');
      });

      it('opens a file with --add', async function() {
        await scenario.open(parseCommandLine(['--add', 'a/1.md']));
        await scenario.assert('[_ 1.md]');
      });

      it('opens a directory with --add', async function() {
        await scenario.open(parseCommandLine(['--add', 'a']));
        await scenario.assert('[a _]');
      });

      it('opens a file with --new-window', async function() {
        await scenario.open(parseCommandLine(['--new-window', 'a/1.md']));
        await scenario.assert('[_ 1.md]');
      });

      it('opens a directory with --new-window', async function() {
        await scenario.open(parseCommandLine(['--new-window', 'a']));
        await scenario.assert('[a _]');
      });

      describe('with previous window state', function() {
        let app;

        beforeEach(function() {
          app = scenario.addApplication({
            applicationJson: {
              version: '1',
              windows: [
                { projectRoots: [scenario.convertRootPath('b')] },
                { projectRoots: [scenario.convertRootPath('c')] }
              ]
            }
          });
        });

        describe('with core.restorePreviousWindowsOnStart set to "no"', function() {
          beforeEach(function() {
            app.config.set('core.restorePreviousWindowsOnStart', 'no');
          });

          it("doesn't restore windows when launched with no arguments", async function() {
            await scenario.launch({ app });
            await scenario.assert('[_ _]');
          });

          it("doesn't restore windows when launched with paths to open", async function() {
            await scenario.launch({ app, pathsToOpen: ['a/1.md'] });
            await scenario.assert('[_ 1.md]');
          });

          it("doesn't restore windows when --new-window is provided", async function() {
            await scenario.launch({ app, newWindow: true });
            await scenario.assert('[_ _]');
          });
        });

        describe('with core.restorePreviousWindowsOnStart set to "yes"', function() {
          beforeEach(function() {
            app.config.set('core.restorePreviousWindowsOnStart', 'yes');
          });

          it('restores windows when launched with no arguments', async function() {
            await scenario.launch({ app });
            await scenario.assert('[b _] [c _]');
          });

          it("doesn't restore windows when launched with paths to open", async function() {
            await scenario.launch({ app, pathsToOpen: ['a/1.md'] });
            await scenario.assert('[_ 1.md]');
          });

          it("doesn't restore windows when --new-window is provided", async function() {
            await scenario.launch({ app, newWindow: true });
            await scenario.assert('[_ _]');
          });
        });

        describe('with core.restorePreviousWindowsOnStart set to "always"', function() {
          beforeEach(function() {
            app.config.set('core.restorePreviousWindowsOnStart', 'always');
          });

          it('restores windows when launched with no arguments', async function() {
            await scenario.launch({ app });
            await scenario.assert('[b _] [c _]');
          });

          it('restores windows when launched with a project path to open', async function() {
            await scenario.launch({ app, pathsToOpen: ['a'] });
            await scenario.assert('[b _] [c _] [a _]');
          });

          it('restores windows when launched with a file path to open', async function() {
            await scenario.launch({ app, pathsToOpen: ['a/1.md'] });
            await scenario.assert('[b _] [c 1.md]');
          });

          it('collapses new paths into restored windows when appropriate', async function() {
            await scenario.launch({ app, pathsToOpen: ['b/2.md'] });
            await scenario.assert('[b 2.md] [c _]');
          });

          it("doesn't restore windows when --new-window is provided", async function() {
            await scenario.launch({ app, newWindow: true });
            await scenario.assert('[_ _]');
          });

          it("doesn't restore windows on open, just launch", async function() {
            await scenario.launch({ app, pathsToOpen: ['a'], newWindow: true });
            await scenario.open(parseCommandLine(['b']));
            await scenario.assert('[a _] [b _]');
          });
        });
      });

      describe('with unversioned application state', function() {
        it('reads "initialPaths" as project roots', async function() {
          const app = scenario.addApplication({
            applicationJson: [
              { initialPaths: [scenario.convertRootPath('a')] },
              {
                initialPaths: [
                  scenario.convertRootPath('b'),
                  scenario.convertRootPath('c')
                ]
              }
            ]
          });
          app.config.set('core.restorePreviousWindowsOnStart', 'always');

          await scenario.launch({ app });
          await scenario.assert('[a _] [b,c _]');
        });

        it('filters file paths from project root lists', async function() {
          const app = scenario.addApplication({
            applicationJson: [
              {
                initialPaths: [
                  scenario.convertRootPath('b'),
                  scenario.convertEditorPath('a/1.md')
                ]
              }
            ]
          });
          app.config.set('core.restorePreviousWindowsOnStart', 'always');

          await scenario.launch({ app });
          await scenario.assert('[b _]');
        });
      });
    });

    describe('with one empty window', function() {
      beforeEach(async function() {
        await scenario.preconditions('[_ _]');
      });

      // This is also the case when a user selects the application from the OS shell
      it('opens a new, empty window', async function() {
        await scenario.open(parseCommandLine([]));
        await scenario.assert('[_ _] [_ _]');
      });

      // This is also the case when a user clicks on a file in their file manager
      it('opens a file', async function() {
        await scenario.open(parseCommandLine(['a/1.md']));
        await scenario.assert('[_ 1.md]');
      });

      // This is also the case when a user clicks on a folder in their file manager
      it('opens a directory', async function() {
        await scenario.open(parseCommandLine(['a']));
        await scenario.assert('[a _]');
      });

      it('opens a file with --add', async function() {
        await scenario.open(parseCommandLine(['--add', 'a/1.md']));
        await scenario.assert('[_ 1.md]');
      });

      it('opens a directory with --add', async function() {
        await scenario.open(parseCommandLine(['--add', 'a']));
        await scenario.assert('[a _]');
      });

      it('opens a file with --new-window', async function() {
        await scenario.open(parseCommandLine(['--new-window', 'a/1.md']));
        await scenario.assert('[_ _] [_ 1.md]');
      });

      it('opens a directory with --new-window', async function() {
        await scenario.open(parseCommandLine(['--new-window', 'a']));
        await scenario.assert('[_ _] [a _]');
      });
    });

    describe('with one window that has a project root', function() {
      beforeEach(async function() {
        await scenario.preconditions('[a _]');
      });

      // This is also the case when a user selects the application from the OS shell
      it('opens a new, empty window', async function() {
        await scenario.open(parseCommandLine([]));
        await scenario.assert('[a _] [_ _]');
      });

      // This is also the case when a user clicks on a file within the project root in their file manager
      it('opens a file within the project root', async function() {
        await scenario.open(parseCommandLine(['a/1.md']));
        await scenario.assert('[a 1.md]');
      });

      // This is also the case when a user clicks on a project root folder in their file manager
      it('opens a directory that matches the project root', async function() {
        await scenario.open(parseCommandLine(['a']));
        await scenario.assert('[a _]');
      });

      // This is also the case when a user clicks on a file outside the project root in their file manager
      it('opens a file outside the project root', async function() {
        await scenario.open(parseCommandLine(['b/2.md']));
        await scenario.assert('[a 2.md]');
      });

      // This is also the case when a user clicks on a new folder in their file manager
      it('opens a directory other than the project root', async function() {
        await scenario.open(parseCommandLine(['b']));
        await scenario.assert('[a _] [b _]');
      });

      it('opens a file within the project root with --add', async function() {
        await scenario.open(parseCommandLine(['--add', 'a/1.md']));
        await scenario.assert('[a 1.md]');
      });

      it('opens a directory that matches the project root with --add', async function() {
        await scenario.open(parseCommandLine(['--add', 'a']));
        await scenario.assert('[a _]');
      });

      it('opens a file outside the project root with --add', async function() {
        await scenario.open(parseCommandLine(['--add', 'b/2.md']));
        await scenario.assert('[a 2.md]');
      });

      it('opens a directory other than the project root with --add', async function() {
        await scenario.open(parseCommandLine(['--add', 'b']));
        await scenario.assert('[a,b _]');
      });

      it('opens a file within the project root with --new-window', async function() {
        await scenario.open(parseCommandLine(['--new-window', 'a/1.md']));
        await scenario.assert('[a _] [_ 1.md]');
      });

      it('opens a directory that matches the project root with --new-window', async function() {
        await scenario.open(parseCommandLine(['--new-window', 'a']));
        await scenario.assert('[a _] [a _]');
      });

      it('opens a file outside the project root with --new-window', async function() {
        await scenario.open(parseCommandLine(['--new-window', 'b/2.md']));
        await scenario.assert('[a _] [_ 2.md]');
      });

      it('opens a directory other than the project root with --new-window', async function() {
        await scenario.open(parseCommandLine(['--new-window', 'b']));
        await scenario.assert('[a _] [b _]');
      });
    });

    describe('with two windows, one with a project root and one empty', function() {
      beforeEach(async function() {
        await scenario.preconditions('[a _] [_ _]');
      });

      // This is also the case when a user selects the application from the OS shell
      it('opens a new, empty window', async function() {
        await scenario.open(parseCommandLine([]));
        await scenario.assert('[a _] [_ _] [_ _]');
      });

      // This is also the case when a user clicks on a file within the project root in their file manager
      it('opens a file within the project root', async function() {
        await scenario.open(parseCommandLine(['a/1.md']));
        await scenario.assert('[a 1.md] [_ _]');
      });

      // This is also the case when a user clicks on a project root folder in their file manager
      it('opens a directory that matches the project root', async function() {
        await scenario.open(parseCommandLine(['a']));
        await scenario.assert('[a _] [_ _]');
      });

      // This is also the case when a user clicks on a file outside the project root in their file manager
      it('opens a file outside the project root', async function() {
        await scenario.open(parseCommandLine(['b/2.md']));
        await scenario.assert('[a _] [_ 2.md]');
      });

      // This is also the case when a user clicks on a new folder in their file manager
      it('opens a directory other than the project root', async function() {
        await scenario.open(parseCommandLine(['b']));
        await scenario.assert('[a _] [b _]');
      });

      it('opens a file within the project root with --add', async function() {
        await scenario.open(parseCommandLine(['--add', 'a/1.md']));
        await scenario.assert('[a 1.md] [_ _]');
      });

      it('opens a directory that matches the project root with --add', async function() {
        await scenario.open(parseCommandLine(['--add', 'a']));
        await scenario.assert('[a _] [_ _]');
      });

      it('opens a file outside the project root with --add', async function() {
        await scenario.open(parseCommandLine(['--add', 'b/2.md']));
        await scenario.assert('[a _] [_ 2.md]');
      });

      it('opens a directory other than the project root with --add', async function() {
        await scenario.open(parseCommandLine(['--add', 'b']));
        await scenario.assert('[a _] [b _]');
      });

      it('opens a file within the project root with --new-window', async function() {
        await scenario.open(parseCommandLine(['--new-window', 'a/1.md']));
        await scenario.assert('[a _] [_ _] [_ 1.md]');
      });

      it('opens a directory that matches the project root with --new-window', async function() {
        await scenario.open(parseCommandLine(['--new-window', 'a']));
        await scenario.assert('[a _] [_ _] [a _]');
      });

      it('opens a file outside the project root with --new-window', async function() {
        await scenario.open(parseCommandLine(['--new-window', 'b/2.md']));
        await scenario.assert('[a _] [_ _] [_ 2.md]');
      });

      it('opens a directory other than the project root with --new-window', async function() {
        await scenario.open(parseCommandLine(['--new-window', 'b']));
        await scenario.assert('[a _] [_ _] [b _]');
      });
    });

    describe('with two windows, one empty and one with a project root', function() {
      beforeEach(async function() {
        await scenario.preconditions('[_ _] [a _]');
      });

      // This is also the case when a user selects the application from the OS shell
      it('opens a new, empty window', async function() {
        await scenario.open(parseCommandLine([]));
        await scenario.assert('[_ _] [a _] [_ _]');
      });

      // This is also the case when a user clicks on a file within the project root in their file manager
      it('opens a file within the project root', async function() {
        await scenario.open(parseCommandLine(['a/1.md']));
        await scenario.assert('[_ _] [a 1.md]');
      });

      // This is also the case when a user clicks on a project root folder in their file manager
      it('opens a directory that matches the project root', async function() {
        await scenario.open(parseCommandLine(['a']));
        await scenario.assert('[_ _] [a _]');
      });

      // This is also the case when a user clicks on a file outside the project root in their file manager
      it('opens a file outside the project root', async function() {
        await scenario.open(parseCommandLine(['b/2.md']));
        await scenario.assert('[_ 2.md] [a _]');
      });

      // This is also the case when a user clicks on a new folder in their file manager
      it('opens a directory other than the project root', async function() {
        await scenario.open(parseCommandLine(['b']));
        await scenario.assert('[b _] [a _]');
      });

      it('opens a file within the project root with --add', async function() {
        await scenario.open(parseCommandLine(['--add', 'a/1.md']));
        await scenario.assert('[_ _] [a 1.md]');
      });

      it('opens a directory that matches the project root with --add', async function() {
        await scenario.open(parseCommandLine(['--add', 'a']));
        await scenario.assert('[_ _] [a _]');
      });

      it('opens a file outside the project root with --add', async function() {
        await scenario.open(parseCommandLine(['--add', 'b/2.md']));
        await scenario.assert('[_ _] [a 2.md]');
      });

      it('opens a directory other than the project root with --add', async function() {
        await scenario.open(parseCommandLine(['--add', 'b']));
        await scenario.assert('[_ _] [a,b _]');
      });

      it('opens a file within the project root with --new-window', async function() {
        await scenario.open(parseCommandLine(['--new-window', 'a/1.md']));
        await scenario.assert('[_ _] [a _] [_ 1.md]');
      });

      it('opens a directory that matches the project root with --new-window', async function() {
        await scenario.open(parseCommandLine(['--new-window', 'a']));
        await scenario.assert('[_ _] [a _] [a _]');
      });

      it('opens a file outside the project root with --new-window', async function() {
        await scenario.open(parseCommandLine(['--new-window', 'b/2.md']));
        await scenario.assert('[_ _] [a _] [_ 2.md]');
      });

      it('opens a directory other than the project root with --new-window', async function() {
        await scenario.open(parseCommandLine(['--new-window', 'b']));
        await scenario.assert('[_ _] [a _] [b _]');
      });
    });

    describe('--wait', function() {
      it('kills the specified pid after a newly-opened window is closed', async function() {
        const [w0] = await scenario.launch(
          parseCommandLine(['--new-window', '--wait', '--pid', '101'])
        );
        const w1 = await scenario.open(
          parseCommandLine(['--new-window', '--wait', '--pid', '202'])
        );

        assert.lengthOf(scenario.killedPids, 0);

        w0.browserWindow.emit('closed');
        assert.deepEqual(scenario.killedPids, [101]);

        w1.browserWindow.emit('closed');
        assert.deepEqual(scenario.killedPids, [101, 202]);
      });

      it('kills the specified pid after all newly-opened files in an existing window are closed', async function() {
        const [w] = await scenario.launch(
          parseCommandLine(['--new-window', 'a'])
        );
        await scenario.open(
          parseCommandLine([
            '--add',
            '--wait',
            '--pid',
            '303',
            'a/1.md',
            'b/2.md'
          ])
        );
        await scenario.assert('[a 1.md,2.md]');

        assert.lengthOf(scenario.killedPids, 0);

        scenario
          .getApplication(0)
          .windowDidClosePathWithWaitSession(
            w,
            scenario.convertEditorPath('b/2.md')
          );
        assert.lengthOf(scenario.killedPids, 0);
        scenario
          .getApplication(0)
          .windowDidClosePathWithWaitSession(
            w,
            scenario.convertEditorPath('a/1.md')
          );
        assert.deepEqual(scenario.killedPids, [303]);
      });

      it('kills the specified pid after a newly-opened directory in an existing window is closed', async function() {
        const [w] = await scenario.launch(
          parseCommandLine(['--new-window', 'a'])
        );
        await scenario.open(
          parseCommandLine(['--add', '--wait', '--pid', '404', 'b'])
        );
        await scenario.assert('[a,b _]');

        assert.lengthOf(scenario.killedPids, 0);

        scenario
          .getApplication(0)
          .windowDidClosePathWithWaitSession(w, scenario.convertRootPath('b'));
        assert.deepEqual(scenario.killedPids, [404]);
      });
    });

    describe('atom:// URLs', function() {
      describe('with a package-name host', function() {
        it("loads the package's urlMain in a new window", async function() {
          await scenario.launch({});

          const app = scenario.getApplication(0);
          app.packages = {
            getAvailablePackageMetadata: () => [
              { name: 'package-with-url-main', urlMain: 'some/url-main' }
            ],
            resolvePackagePath: () =>
              path.resolve('dot-atom/package-with-url-main')
          };

          const [w1, w2] = await scenario.open(
            parseCommandLine([
              'atom://package-with-url-main/test1',
              'atom://package-with-url-main/test2'
            ])
          );

          assert.strictEqual(
            w1.loadSettings.windowInitializationScript,
            path.resolve('dot-atom/package-with-url-main/some/url-main')
          );
          assert.strictEqual(
            w1.loadSettings.urlToOpen,
            'atom://package-with-url-main/test1'
          );

          assert.strictEqual(
            w2.loadSettings.windowInitializationScript,
            path.resolve('dot-atom/package-with-url-main/some/url-main')
          );
          assert.strictEqual(
            w2.loadSettings.urlToOpen,
            'atom://package-with-url-main/test2'
          );
        });

        it('sends a URI message to the most recently focused non-spec window', async function() {
          const [w0] = await scenario.launch({});
          const w1 = await scenario.open(parseCommandLine(['--new-window']));
          const w2 = await scenario.open(parseCommandLine(['--new-window']));
          const w3 = await scenario.open(
            parseCommandLine(['--test', 'a/1.md'])
          );

          const app = scenario.getApplication(0);
          app.packages = {
            getAvailablePackageMetadata: () => []
          };

          const [uw] = await scenario.open(
            parseCommandLine(['atom://package-without-url-main/test'])
          );
          assert.strictEqual(uw, w2);

          assert.isTrue(
            w2.sendURIMessage.calledWith('atom://package-without-url-main/test')
          );
          assert.strictEqual(w2.focus.callCount, 2);

          for (const other of [w0, w1, w3]) {
            assert.isFalse(other.sendURIMessage.called);
          }
        });

        it('creates a new window and sends a URI message to it once it loads', async function() {
          const [w0] = await scenario.launch(
            parseCommandLine(['--test', 'a/1.md'])
          );

          const app = scenario.getApplication(0);
          app.packages = {
            getAvailablePackageMetadata: () => []
          };

          const [uw] = await scenario.open(
            parseCommandLine(['atom://package-without-url-main/test'])
          );
          assert.notStrictEqual(uw, w0);
          assert.strictEqual(
            uw.loadSettings.windowInitializationScript,
            path.resolve(
              __dirname,
              '../../src/initialize-application-window.js'
            )
          );

          uw.emit('window:loaded');
          assert.isTrue(
            uw.sendURIMessage.calledWith('atom://package-without-url-main/test')
          );
        });
      });

      describe('with a "core" host', function() {
        it('sends a URI message to the most recently focused non-spec window that owns the open locations', async function() {
          const [w0] = await scenario.launch(parseCommandLine(['a']));
          const w1 = await scenario.open(
            parseCommandLine(['--new-window', 'a'])
          );
          const w2 = await scenario.open(
            parseCommandLine(['--new-window', 'b'])
          );

          const uri = `atom://core/open/file?filename=${encodeURIComponent(
            scenario.convertEditorPath('a/1.md')
          )}`;
          const [uw] = await scenario.open(parseCommandLine([uri]));
          assert.strictEqual(uw, w1);
          assert.isTrue(w1.sendURIMessage.calledWith(uri));

          for (const other of [w0, w2]) {
            assert.isFalse(other.sendURIMessage.called);
          }
        });

        it('creates a new window and sends a URI message to it once it loads', async function() {
          const [w0] = await scenario.launch(
            parseCommandLine(['--test', 'a/1.md'])
          );

          const uri = `atom://core/open/file?filename=${encodeURIComponent(
            scenario.convertEditorPath('b/2.md')
          )}`;
          const [uw] = await scenario.open(parseCommandLine([uri]));
          assert.notStrictEqual(uw, w0);

          uw.emit('window:loaded');
          assert.isTrue(uw.sendURIMessage.calledWith(uri));
        });
      });
    });

    it('opens a file to a specific line number', async function() {
      await scenario.open(parseCommandLine(['a/1.md:10']));
      await scenario.assert('[_ 1.md]');

      const w = scenario.getWindow(0);
      assert.lengthOf(w._locations, 1);
      assert.strictEqual(w._locations[0].initialLine, 9);
      assert.isNull(w._locations[0].initialColumn);
    });

    it('opens a file to a specific line number and column', async function() {
      await scenario.open(parseCommandLine('b/2.md:12:5'));
      await scenario.assert('[_ 2.md]');

      const w = scenario.getWindow(0);
      assert.lengthOf(w._locations, 1);
      assert.strictEqual(w._locations[0].initialLine, 11);
      assert.strictEqual(w._locations[0].initialColumn, 4);
    });

    it('opens a directory with a non-file protocol', async function() {
      await scenario.open(
        parseCommandLine(['remote://server:3437/some/directory/path'])
      );

      const w = scenario.getWindow(0);
      assert.lengthOf(w._locations, 1);
      assert.strictEqual(
        w._locations[0].pathToOpen,
        'remote://server:3437/some/directory/path'
      );
      assert.isFalse(w._locations[0].exists);
      assert.isFalse(w._locations[0].isDirectory);
      assert.isFalse(w._locations[0].isFile);
    });

    it('truncates trailing whitespace and colons', async function() {
      await scenario.open(parseCommandLine('b/2.md::  '));
      await scenario.assert('[_ 2.md]');

      const w = scenario.getWindow(0);
      assert.lengthOf(w._locations, 1);
      assert.isNull(w._locations[0].initialLine);
      assert.isNull(w._locations[0].initialColumn);
    });

    it('disregards test and benchmark windows', async function() {
      await scenario.launch(parseCommandLine(['--test', 'b']));
      await scenario.open(parseCommandLine(['--new-window']));
      await scenario.open(parseCommandLine(['--test', 'c']));
      await scenario.open(parseCommandLine(['--benchmark', 'b']));

      await scenario.open(parseCommandLine(['a/1.md']));

      // Test and benchmark StubWindows are visible as empty editor windows here
      await scenario.assert('[_ _] [_ 1.md] [_ _] [_ _]');
    });
  });

  if (process.platform === 'darwin' || process.platform === 'win32') {
    it('positions new windows at an offset from the previous window', async function() {
      const [w0] = await scenario.launch(parseCommandLine(['a']));
      w0.setSize(400, 400);
      const d0 = w0.getDimensions();

      const w1 = await scenario.open(parseCommandLine(['b']));
      const d1 = w1.getDimensions();

      assert.isAbove(d1.x, d0.x);
      assert.isAbove(d1.y, d0.y);
    });
  }

  if (process.platform === 'darwin') {
    describe('with no windows open', function() {
      let app;

      beforeEach(async function() {
        const [w] = await scenario.launch(parseCommandLine([]));

        app = scenario.getApplication(0);
        app.removeWindow(w);
        sinon.stub(app, 'promptForPathToOpen');
      });

      it('opens a new file', function() {
        app.emit('application:open-file');
        assert.isTrue(
          app.promptForPathToOpen.calledWith('file', {
            devMode: false,
            safeMode: false,
            window: null
          })
        );
      });

      it('opens a new directory', function() {
        app.emit('application:open-folder');
        assert.isTrue(
          app.promptForPathToOpen.calledWith('folder', {
            devMode: false,
            safeMode: false,
            window: null
          })
        );
      });

      it('opens a new file or directory', function() {
        app.emit('application:open');
        assert.isTrue(
          app.promptForPathToOpen.calledWith('all', {
            devMode: false,
            safeMode: false,
            window: null
          })
        );
      });

      it('reopens a project in a new window', async function() {
        const paths = scenario.convertPaths(['a', 'b']);
        app.emit('application:reopen-project', { paths });

        await conditionPromise(() => app.getAllWindows().length > 0);

        assert.deepEqual(
          app.getAllWindows().map(w => Array.from(w._rootPaths)),
          [paths]
        );
      });
    });
  }

  describe('existing application re-use', function() {
    let createApplication;

    const version = electron.app.getVersion();

    beforeEach(function() {
      createApplication = async options => {
        options.version = version;

        const app = scenario.addApplication(options);
        await app.listenForArgumentsFromNewProcess(options);
        await app.launch(options);
        return app;
      };
    });

    it('creates a new application when no socket is present', async function() {
      const app0 = await AtomApplication.open({ createApplication, version });
      await app0.deleteSocketSecretFile();

      const app1 = await AtomApplication.open({ createApplication, version });
      assert.isNotNull(app1);
      assert.notStrictEqual(app0, app1);
    });

    it('creates a new application for spec windows', async function() {
      const app0 = await AtomApplication.open({ createApplication, version });

      const app1 = await AtomApplication.open({
        createApplication,
        version,
        ...parseCommandLine(['--test', 'a'])
      });
      assert.isNotNull(app1);
      assert.notStrictEqual(app0, app1);
    });

    it('sends a request to an existing application when a socket is present', async function() {
      const app0 = await AtomApplication.open({ createApplication, version });
      assert.lengthOf(app0.getAllWindows(), 1);

      const app1 = await AtomApplication.open({
        createApplication,
        version,
        ...parseCommandLine(['--new-window'])
      });
      assert.isNull(app1);
      assert.isTrue(electron.app.quit.called);

      await conditionPromise(() => app0.getAllWindows().length === 2);
      await scenario.assert('[_ _] [_ _]');
    });
  });

  describe('IPC handling', function() {
    let w0, w1, w2, app;

    beforeEach(async function() {
      w0 = (await scenario.launch(parseCommandLine(['a'])))[0];
      w1 = await scenario.open(parseCommandLine(['--new-window']));
      w2 = await scenario.open(parseCommandLine(['--new-window', 'b']));

      app = scenario.getApplication(0);
      sinon.spy(app, 'openPaths');
      sinon.stub(app, 'promptForPath', (_type, callback, defaultPath) =>
        callback([defaultPath])
      );
    });

    // This is the IPC message used to handle:
    // * application:reopen-project
    // * choosing "open in new window" when adding a folder that has previously saved state
    // * drag and drop
    // * deprecated call links in deprecation-cop
    // * other direct callers of `atom.open()`
    it('"open" opens a fixed path by the standard opening rules', async function() {
      sinon.stub(app, 'atomWindowForEvent', () => w1);

      electron.ipcMain.emit(
        'open',
        {},
        { pathsToOpen: [scenario.convertEditorPath('a/1.md')] }
      );
      await app.openPaths.lastCall.returnValue;
      await scenario.assert('[a 1.md] [_ _] [b _]');

      electron.ipcMain.emit(
        'open',
        {},
        { pathsToOpen: [scenario.convertRootPath('c')] }
      );
      await app.openPaths.lastCall.returnValue;
      await scenario.assert('[a 1.md] [c _] [b _]');

      electron.ipcMain.emit(
        'open',
        {},
        { pathsToOpen: [scenario.convertRootPath('d')], here: true }
      );
      await app.openPaths.lastCall.returnValue;
      await scenario.assert('[a 1.md] [c,d _] [b _]');
    });

    it('"open" without any option open the prompt for selecting a path', async function() {
      sinon.stub(app, 'atomWindowForEvent', () => w1);

      electron.ipcMain.emit('open', {});
      assert.strictEqual(app.promptForPath.lastCall.args[0], 'all');
    });

    it('"open-chosen-any" opens a file in the sending window', async function() {
      sinon.stub(app, 'atomWindowForEvent', () => w2);

      electron.ipcMain.emit(
        'open-chosen-any',
        {},
        scenario.convertEditorPath('a/1.md')
      );
      await conditionPromise(() => app.openPaths.called);
      await app.openPaths.lastCall.returnValue;
      await scenario.assert('[a _] [_ _] [b 1.md]');

      assert.isTrue(app.promptForPath.called);
      assert.strictEqual(app.promptForPath.lastCall.args[0], 'all');
    });

    it('"open-chosen-any" opens a directory by the standard opening rules', async function() {
      sinon.stub(app, 'atomWindowForEvent', () => w1);

      // Open unrecognized directory in empty window
      electron.ipcMain.emit(
        'open-chosen-any',
        {},
        scenario.convertRootPath('c')
      );
      await conditionPromise(() => app.openPaths.callCount > 0);
      await app.openPaths.lastCall.returnValue;
      await scenario.assert('[a _] [c _] [b _]');

      assert.strictEqual(app.promptForPath.callCount, 1);
      assert.strictEqual(app.promptForPath.lastCall.args[0], 'all');

      // Open unrecognized directory in new window
      electron.ipcMain.emit(
        'open-chosen-any',
        {},
        scenario.convertRootPath('d')
      );
      await conditionPromise(() => app.openPaths.callCount > 1);
      await app.openPaths.lastCall.returnValue;
      await scenario.assert('[a _] [c _] [b _] [d _]');

      assert.strictEqual(app.promptForPath.callCount, 2);
      assert.strictEqual(app.promptForPath.lastCall.args[0], 'all');

      // Open recognized directory in existing window
      electron.ipcMain.emit(
        'open-chosen-any',
        {},
        scenario.convertRootPath('a')
      );
      await conditionPromise(() => app.openPaths.callCount > 2);
      await app.openPaths.lastCall.returnValue;
      await scenario.assert('[a _] [c _] [b _] [d _]');

      assert.strictEqual(app.promptForPath.callCount, 3);
      assert.strictEqual(app.promptForPath.lastCall.args[0], 'all');
    });

    it('"open-chosen-file" opens a file chooser and opens the chosen file in the sending window', async function() {
      sinon.stub(app, 'atomWindowForEvent', () => w0);

      electron.ipcMain.emit(
        'open-chosen-file',
        {},
        scenario.convertEditorPath('b/2.md')
      );
      await app.openPaths.lastCall.returnValue;
      await scenario.assert('[a 2.md] [_ _] [b _]');

      assert.isTrue(app.promptForPath.called);
      assert.strictEqual(app.promptForPath.lastCall.args[0], 'file');
    });

    it('"open-chosen-folder" opens a directory chooser and opens the chosen directory', async function() {
      sinon.stub(app, 'atomWindowForEvent', () => w0);

      electron.ipcMain.emit(
        'open-chosen-folder',
        {},
        scenario.convertRootPath('c')
      );
      await app.openPaths.lastCall.returnValue;
      await scenario.assert('[a _] [c _] [b _]');

      assert.isTrue(app.promptForPath.called);
      assert.strictEqual(app.promptForPath.lastCall.args[0], 'folder');
    });
  });

  describe('window state serialization', function() {
    it('occurs immediately when adding a window', async function() {
      await scenario.launch(parseCommandLine(['a']));

      const promise = emitterEventPromise(
        scenario.getApplication(0),
        'application:did-save-state'
      );
      await scenario.open(parseCommandLine(['c', 'b']));
      await promise;

      assert.isTrue(
        scenario
          .getApplication(0)
          .storageFolder.store.calledWith('application.json', {
            version: '1',
            windows: [
              { projectRoots: [scenario.convertRootPath('a')] },
              {
                projectRoots: [
                  scenario.convertRootPath('b'),
                  scenario.convertRootPath('c')
                ]
              }
            ]
          })
      );
    });

    it('occurs immediately when removing a window', async function() {
      await scenario.launch(parseCommandLine(['a']));
      const w = await scenario.open(parseCommandLine(['b']));

      const promise = emitterEventPromise(
        scenario.getApplication(0),
        'application:did-save-state'
      );
      scenario.getApplication(0).removeWindow(w);
      await promise;

      assert.isTrue(
        scenario
          .getApplication(0)
          .storageFolder.store.calledWith('application.json', {
            version: '1',
            windows: [{ projectRoots: [scenario.convertRootPath('a')] }]
          })
      );
    });

    it('occurs when the window is blurred', async function() {
      const [w] = await scenario.launch(parseCommandLine(['a']));
      const promise = emitterEventPromise(
        scenario.getApplication(0),
        'application:did-save-state'
      );
      w.browserWindow.emit('blur');
      await promise;
    });
  });

  describe('when closing the last window', function() {
    if (process.platform === 'linux' || process.platform === 'win32') {
      it('quits the application', async function() {
        const [w] = await scenario.launch(parseCommandLine(['a']));
        scenario.getApplication(0).removeWindow(w);
        assert.isTrue(electron.app.quit.called);
      });
    } else if (process.platform === 'darwin') {
      it('leaves the application open', async function() {
        const [w] = await scenario.launch(parseCommandLine(['a']));
        scenario.getApplication(0).removeWindow(w);
        assert.isFalse(electron.app.quit.called);
      });
    }
  });

  describe('quitting', function() {
    it('waits until all windows have saved their state before quitting', async function() {
      const [w0] = await scenario.launch(parseCommandLine(['a']));
      const w1 = await scenario.open(parseCommandLine(['b']));
      assert.notStrictEqual(w0, w1);

      sinon.spy(w0, 'close');
      let resolveUnload0;
      w0.prepareToUnload = () =>
        new Promise(resolve => {
          resolveUnload0 = resolve;
        });

      sinon.spy(w1, 'close');
      let resolveUnload1;
      w1.prepareToUnload = () =>
        new Promise(resolve => {
          resolveUnload1 = resolve;
        });

      const evt = { preventDefault: sinon.spy() };
      electron.app.emit('before-quit', evt);
      await new Promise(process.nextTick);
      assert.isTrue(evt.preventDefault.called);
      assert.isFalse(electron.app.quit.called);

      resolveUnload1(true);
      await new Promise(process.nextTick);
      assert.isFalse(electron.app.quit.called);

      resolveUnload0(true);
      await scenario.getApplication(0).lastBeforeQuitPromise;
      assert.isTrue(electron.app.quit.called);

      assert.isTrue(w0.close.called);
      assert.isTrue(w1.close.called);
    });

    it('prevents a quit if a user cancels when prompted to save', async function() {
      const [w] = await scenario.launch(parseCommandLine(['a']));
      let resolveUnload;
      w.prepareToUnload = () =>
        new Promise(resolve => {
          resolveUnload = resolve;
        });

      const evt = { preventDefault: sinon.spy() };
      electron.app.emit('before-quit', evt);
      await new Promise(process.nextTick);
      assert.isTrue(evt.preventDefault.called);

      resolveUnload(false);
      await scenario.getApplication(0).lastBeforeQuitPromise;

      assert.isFalse(electron.app.quit.called);
    });

    it('closes successfully unloaded windows', async function() {
      const [w0] = await scenario.launch(parseCommandLine(['a']));
      const w1 = await scenario.open(parseCommandLine(['b']));

      sinon.spy(w0, 'close');
      let resolveUnload0;
      w0.prepareToUnload = () =>
        new Promise(resolve => {
          resolveUnload0 = resolve;
        });

      sinon.spy(w1, 'close');
      let resolveUnload1;
      w1.prepareToUnload = () =>
        new Promise(resolve => {
          resolveUnload1 = resolve;
        });

      const evt = { preventDefault() {} };
      electron.app.emit('before-quit', evt);

      resolveUnload0(false);
      resolveUnload1(true);

      await scenario.getApplication(0).lastBeforeQuitPromise;

      assert.isFalse(electron.app.quit.called);
      assert.isFalse(w0.close.called);
      assert.isTrue(w1.close.called);
    });
  });
});

class StubWindow extends EventEmitter {
  constructor(sinon, loadSettings, options) {
    super();

    this.loadSettings = loadSettings;

    this._dimensions = Object.assign({}, loadSettings.windowDimensions) || {
      x: 100,
      y: 100
    };
    this._position = { x: 0, y: 0 };
    this._locations = [];
    this._rootPaths = new Set();
    this._editorPaths = new Set();

    let resolveClosePromise;
    this.closedPromise = new Promise(resolve => {
      resolveClosePromise = resolve;
    });

    this.minimize = sinon.spy();
    this.maximize = sinon.spy();
    this.center = sinon.spy();
    this.focus = sinon.spy();
    this.show = sinon.spy();
    this.hide = sinon.spy();
    this.prepareToUnload = sinon.spy();
    this.close = resolveClosePromise;

    this.replaceEnvironment = sinon.spy();
    this.disableZoom = sinon.spy();

    this.isFocused = sinon
      .stub()
      .returns(options.isFocused !== undefined ? options.isFocused : false);
    this.isMinimized = sinon
      .stub()
      .returns(options.isMinimized !== undefined ? options.isMinimized : false);
    this.isMaximized = sinon
      .stub()
      .returns(options.isMaximized !== undefined ? options.isMaximized : false);

    this.sendURIMessage = sinon.spy();
    this.didChangeUserSettings = sinon.spy();
    this.didFailToReadUserSettings = sinon.spy();

    this.isSpec =
      loadSettings.isSpec !== undefined ? loadSettings.isSpec : false;
    this.devMode =
      loadSettings.devMode !== undefined ? loadSettings.devMode : false;
    this.safeMode =
      loadSettings.safeMode !== undefined ? loadSettings.safeMode : false;

    this.browserWindow = new EventEmitter();
    this.browserWindow.webContents = new EventEmitter();

    const locationsToOpen = this.loadSettings.locationsToOpen || [];
    if (
      !(
        locationsToOpen.length === 1 && locationsToOpen[0].pathToOpen == null
      ) &&
      !this.isSpec
    ) {
      this.openLocations(locationsToOpen);
    }
  }

  openPath(pathToOpen, initialLine, initialColumn) {
    return this.openLocations([{ pathToOpen, initialLine, initialColumn }]);
  }

  openLocations(locations) {
    this._locations.push(...locations);
    for (const location of locations) {
      if (location.pathToOpen) {
        if (location.isDirectory) {
          this._rootPaths.add(location.pathToOpen);
        } else if (location.isFile) {
          this._editorPaths.add(location.pathToOpen);
        }
      }
    }

    this.projectRoots = Array.from(this._rootPaths);
    this.projectRoots.sort();

    this.emit('window:locations-opened');
  }

  setSize(x, y) {
    this._dimensions = { x, y };
  }

  setPosition(x, y) {
    this._position = { x, y };
  }

  isSpecWindow() {
    return this.isSpec;
  }

  hasProjectPaths() {
    return this._rootPaths.size > 0;
  }

  containsLocations(locations) {
    return locations.every(location => this.containsLocation(location));
  }

  containsLocation(location) {
    if (!location.pathToOpen) return false;

    return Array.from(this._rootPaths).some(projectPath => {
      if (location.pathToOpen === projectPath) return true;
      if (location.pathToOpen.startsWith(path.join(projectPath, path.sep))) {
        if (!location.exists) return true;
        if (!location.isDirectory) return true;
      }
      return false;
    });
  }

  getDimensions() {
    return Object.assign({}, this._dimensions);
  }
}

class LaunchScenario {
  static async create(sandbox) {
    const scenario = new this(sandbox);
    await scenario.init();
    return scenario;
  }

  constructor(sandbox) {
    this.sinon = sandbox;

    this.applications = new Set();
    this.windows = new Set();
    this.root = null;
    this.atomHome = null;
    this.projectRootPool = new Map();
    this.filePathPool = new Map();

    this.killedPids = [];
    this.originalAtomHome = null;
  }

  async init() {
    if (this.root !== null) {
      return this.root;
    }

    this.root = await new Promise((resolve, reject) => {
      temp.mkdir('launch-', (err, rootPath) => {
        if (err) {
          reject(err);
        } else {
          resolve(rootPath);
        }
      });
    });

    this.atomHome = path.join(this.root, '.atom');
    await new Promise((resolve, reject) => {
      fs.makeTree(this.atomHome, err => {
        if (err) {
          reject(err);
        } else {
          resolve();
        }
      });
    });
    this.originalAtomHome = process.env.ATOM_HOME;
    process.env.ATOM_HOME = this.atomHome;

    await Promise.all(
      ['a', 'b', 'c', 'd'].map(
        dirPath =>
          new Promise((resolve, reject) => {
            const fullDirPath = path.join(this.root, dirPath);
            fs.makeTree(fullDirPath, err => {
              if (err) {
                reject(err);
              } else {
                this.projectRootPool.set(dirPath, fullDirPath);
                resolve();
              }
            });
          })
      )
    );

    await Promise.all(
      ['a/1.md', 'b/2.md'].map(
        filePath =>
          new Promise((resolve, reject) => {
            const fullFilePath = path.join(this.root, filePath);
            fs.writeFile(
              fullFilePath,
              `file: ${filePath}\n`,
              { encoding: 'utf8' },
              err => {
                if (err) {
                  reject(err);
                } else {
                  this.filePathPool.set(filePath, fullFilePath);
                  this.filePathPool.set(path.basename(filePath), fullFilePath);
                  resolve();
                }
              }
            );
          })
      )
    );

    this.sinon.stub(electron.app, 'quit');
  }

  async preconditions(source) {
    const app = this.addApplication();
    const windowPromises = [];

    for (const windowSpec of this.parseWindowSpecs(source)) {
      if (windowSpec.editors.length === 0) {
        windowSpec.editors.push(null);
      }

      windowPromises.push(
        ((theApp, foldersToOpen, pathsToOpen) => {
          return theApp.openPaths({
            newWindow: true,
            foldersToOpen,
            pathsToOpen
          });
        })(app, windowSpec.roots, windowSpec.editors)
      );
    }
    await Promise.all(windowPromises);
  }

  launch(options) {
    const app = options.app || this.addApplication();
    delete options.app;

    if (options.pathsToOpen) {
      options.pathsToOpen = this.convertPaths(options.pathsToOpen);
    }

    return app.launch(options);
  }

  open(options) {
    if (this.applications.size === 0) {
      return this.launch(options);
    }

    let app = options.app;
    if (!app) {
      const apps = Array.from(this.applications);
      app = apps[apps.length - 1];
    } else {
      delete options.app;
    }

    if (options.pathsToOpen) {
      options.pathsToOpen = this.convertPaths(options.pathsToOpen);
    }
    options.preserveFocus = true;

    return app.openWithOptions(options);
  }

  async assert(source) {
    const windowSpecs = this.parseWindowSpecs(source);
    let specIndex = 0;

    const windowPromises = [];
    for (const window of this.windows) {
      windowPromises.push(
        (async (theWindow, theSpec) => {
          const {
            _rootPaths: rootPaths,
            _editorPaths: editorPaths
          } = theWindow;

          const comparison = {
            ok: true,
            extraWindow: false,
            missingWindow: false,
            extraRoots: [],
            missingRoots: [],
            extraEditors: [],
            missingEditors: [],
            roots: rootPaths,
            editors: editorPaths
          };

          if (!theSpec) {
            comparison.ok = false;
            comparison.extraWindow = true;
            comparison.extraRoots = rootPaths;
            comparison.extraEditors = editorPaths;
          } else {
            const [missingRoots, extraRoots] = this.compareSets(
              theSpec.roots,
              rootPaths
            );
            const [missingEditors, extraEditors] = this.compareSets(
              theSpec.editors,
              editorPaths
            );

            comparison.ok =
              missingRoots.length === 0 &&
              extraRoots.length === 0 &&
              missingEditors.length === 0 &&
              extraEditors.length === 0;
            comparison.extraRoots = extraRoots;
            comparison.missingRoots = missingRoots;
            comparison.extraEditors = extraEditors;
            comparison.missingEditors = missingEditors;
          }

          return comparison;
        })(window, windowSpecs[specIndex++])
      );
    }

    const comparisons = await Promise.all(windowPromises);
    for (; specIndex < windowSpecs.length; specIndex++) {
      const spec = windowSpecs[specIndex];
      comparisons.push({
        ok: false,
        extraWindow: false,
        missingWindow: true,
        extraRoots: [],
        missingRoots: spec.roots,
        extraEditors: [],
        missingEditors: spec.editors,
        roots: null,
        editors: null
      });
    }

    const shorthandParts = [];
    const descriptionParts = [];
    for (const comparison of comparisons) {
      if (comparison.roots !== null && comparison.editors !== null) {
        const shortRoots = Array.from(comparison.roots, r =>
          path.basename(r)
        ).join(',');
        const shortPaths = Array.from(comparison.editors, e =>
          path.basename(e)
        ).join(',');
        shorthandParts.push(`[${shortRoots} ${shortPaths}]`);
      }

      if (comparison.ok) {
        continue;
      }

      let parts = [];
      if (comparison.extraWindow) {
        parts.push('extra window\n');
      } else if (comparison.missingWindow) {
        parts.push('missing window\n');
      } else {
        parts.push('incorrect window\n');
      }

      const shorten = fullPaths =>
        fullPaths.map(fullPath => path.basename(fullPath)).join(', ');

      if (comparison.extraRoots.length > 0) {
        parts.push(`* extra roots ${shorten(comparison.extraRoots)}\n`);
      }
      if (comparison.missingRoots.length > 0) {
        parts.push(`* missing roots ${shorten(comparison.missingRoots)}\n`);
      }
      if (comparison.extraEditors.length > 0) {
        parts.push(`* extra editors ${shorten(comparison.extraEditors)}\n`);
      }
      if (comparison.missingEditors.length > 0) {
        parts.push(`* missing editors ${shorten(comparison.missingEditors)}\n`);
      }

      descriptionParts.push(parts.join(''));
    }

    if (descriptionParts.length !== 0) {
      descriptionParts.unshift(shorthandParts.join(' ') + '\n');
      descriptionParts.unshift('Launched windows did not match spec\n');
    }

    assert.isTrue(descriptionParts.length === 0, descriptionParts.join(''));
  }

  async destroy() {
    await Promise.all(Array.from(this.applications, app => app.destroy()));

    if (this.originalAtomHome) {
      process.env.ATOM_HOME = this.originalAtomHome;
    }
  }

  addApplication(options = {}) {
    const app = new AtomApplication({
      resourcePath: path.resolve(__dirname, '../..'),
      atomHomeDirPath: this.atomHome,
      preserveFocus: true,
      killProcess: pid => {
        this.killedPids.push(pid);
      },
      ...options
    });
    this.sinon.stub(app, 'createWindow', loadSettings => {
      const newWindow = new StubWindow(this.sinon, loadSettings, options);
      this.windows.add(newWindow);
      return newWindow;
    });
    this.sinon.stub(app.storageFolder, 'load', () =>
      Promise.resolve(options.applicationJson || { version: '1', windows: [] })
    );
    this.sinon.stub(app.storageFolder, 'store', () => Promise.resolve());
    this.applications.add(app);
    return app;
  }

  getApplication(index) {
    const app = Array.from(this.applications)[index];
    if (!app) {
      throw new Error(`Application ${index} does not exist`);
    }
    return app;
  }

  getWindow(index) {
    const window = Array.from(this.windows)[index];
    if (!window) {
      throw new Error(`Window ${index} does not exist`);
    }
    return window;
  }

  compareSets(expected, actual) {
    const expectedItems = new Set(expected);
    const extra = [];
    const missing = [];

    for (const actualItem of actual) {
      if (!expectedItems.delete(actualItem)) {
        // actualItem was present, but not expected
        extra.push(actualItem);
      }
    }
    for (const remainingItem of expectedItems) {
      // remainingItem was expected, but not present
      missing.push(remainingItem);
    }
    return [missing, extra];
  }

  convertRootPath(shortRootPath) {
    if (
      shortRootPath.startsWith('atom://') ||
      shortRootPath.startsWith('remote://')
    ) {
      return shortRootPath;
    }

    const fullRootPath = this.projectRootPool.get(shortRootPath);
    if (!fullRootPath) {
      throw new Error(`Unexpected short project root path: ${shortRootPath}`);
    }
    return fullRootPath;
  }

  convertEditorPath(shortEditorPath) {
    const [truncatedPath, ...suffix] = shortEditorPath.split(/(?=:)/);
    const fullEditorPath = this.filePathPool.get(truncatedPath);
    if (!fullEditorPath) {
      throw new Error(`Unexpected short editor path: ${shortEditorPath}`);
    }
    return fullEditorPath + suffix.join('');
  }

  convertPaths(paths) {
    return paths.map(shortPath => {
      if (
        shortPath.startsWith('atom://') ||
        shortPath.startsWith('remote://')
      ) {
        return shortPath;
      }

      const fullRoot = this.projectRootPool.get(shortPath);
      if (fullRoot) {
        return fullRoot;
      }

      const [truncatedPath, ...suffix] = shortPath.split(/(?=:)/);
      const fullEditor = this.filePathPool.get(truncatedPath);
      if (fullEditor) {
        return fullEditor + suffix.join('');
      }

      throw new Error(`Unexpected short path: ${shortPath}`);
    });
  }

  parseWindowSpecs(source) {
    const specs = [];

    const rx = /\s*\[(?:_|(\S+)) (?:_|(\S+))\]/g;
    let match = rx.exec(source);

    while (match) {
      const roots = match[1]
        ? match[1].split(',').map(shortPath => this.convertRootPath(shortPath))
        : [];
      const editors = match[2]
        ? match[2]
            .split(',')
            .map(shortPath => this.convertEditorPath(shortPath))
        : [];
      specs.push({ roots, editors });

      match = rx.exec(source);
    }

    return specs;
  }
}
