/* globals assert */

const path = require('path');
const fs = require('fs-plus');
const url = require('url');
const { EventEmitter } = require('events');
const temp = require('temp').track();
const sandbox = require('sinon').createSandbox();
const dedent = require('dedent');

const AtomWindow = require('../../src/main-process/atom-window');
const { emitterEventPromise } = require('../async-spec-helpers');

describe('AtomWindow', function() {
  let sinon, app, service;

  beforeEach(function() {
    sinon = sandbox;
    app = new StubApplication(sinon);
    service = new StubRecoveryService(sinon);
  });

  afterEach(function() {
    sinon.restore();
  });

  describe('creating a real window', function() {
    let resourcePath, windowInitializationScript, atomHome;
    let original;

    this.timeout(10 * 1000);

    beforeEach(async function() {
      original = {
        ATOM_HOME: process.env.ATOM_HOME,
        ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT:
          process.env.ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT
      };

      resourcePath = path.resolve(__dirname, '../..');

      windowInitializationScript = require.resolve(
        path.join(resourcePath, 'src/initialize-application-window')
      );

      atomHome = await new Promise((resolve, reject) => {
        temp.mkdir('launch-', (err, rootPath) => {
          if (err) {
            reject(err);
          } else {
            resolve(rootPath);
          }
        });
      });

      await new Promise((resolve, reject) => {
        const config = dedent`
          '*':
            core:
              automaticallyUpdate: false
              telemetryConsent: "no"
            welcome:
              showOnStartup: false
        `;

        fs.writeFile(
          path.join(atomHome, 'config.cson'),
          config,
          { encoding: 'utf8' },
          err => {
            if (err) {
              reject(err);
            } else {
              resolve();
            }
          }
        );
      });

      process.env.ATOM_HOME = atomHome;
      process.env.ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT = 'true';
    });

    afterEach(async function() {
      process.env.ATOM_HOME = original.ATOM_HOME;
      process.env.ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT =
        original.ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT;
    });

    it('creates a real, properly configured BrowserWindow', async function() {
      const w = new AtomWindow(app, service, {
        resourcePath,
        windowInitializationScript,
        headless: true,
        extra: 'extra-load-setting'
      });
      const { browserWindow } = w;

      assert.isFalse(browserWindow.isVisible());
      assert.isTrue(browserWindow.getTitle().startsWith('Atom'));

      const settings = JSON.parse(browserWindow.loadSettingsJSON);
      assert.strictEqual(settings.userSettings, 'stub-config');
      assert.strictEqual(settings.extra, 'extra-load-setting');
      assert.strictEqual(settings.resourcePath, resourcePath);
      assert.strictEqual(settings.atomHome, atomHome);
      assert.isFalse(settings.devMode);
      assert.isFalse(settings.safeMode);
      assert.isFalse(settings.clearWindowState);

      await emitterEventPromise(browserWindow, 'ready-to-show');

      assert.strictEqual(
        browserWindow.webContents.getURL(),
        url.format({
          protocol: 'file',
          pathname: `${resourcePath.replace(/\\/g, '/')}/static/index.html`,
          slashes: true
        })
      );
    });
  });

  describe('launch behavior', function() {
    if (process.platform === 'darwin') {
      it('sets titleBarStyle to "hidden" for a custom title bar on non-spec windows', function() {
        app.config['core.titleBar'] = 'custom';

        const { browserWindow: w0 } = new AtomWindow(app, service, {
          browserWindowConstructor: StubBrowserWindow
        });
        assert.strictEqual(w0.options.titleBarStyle, 'hidden');

        const { browserWindow: w1 } = new AtomWindow(app, service, {
          browserWindowConstructor: StubBrowserWindow,
          isSpec: true
        });
        assert.isUndefined(w1.options.titleBarStyle);
      });

      it('sets titleBarStyle to "hiddenInset" for a custom inset title bar on non-spec windows', function() {
        app.config['core.titleBar'] = 'custom-inset';

        const { browserWindow: w0 } = new AtomWindow(app, service, {
          browserWindowConstructor: StubBrowserWindow
        });
        assert.strictEqual(w0.options.titleBarStyle, 'hiddenInset');

        const { browserWindow: w1 } = new AtomWindow(app, service, {
          browserWindowConstructor: StubBrowserWindow,
          isSpec: true
        });
        assert.isUndefined(w1.options.titleBarStyle);
      });
      it('sets frame to "false" for a hidden title bar on non-spec windows', function() {
        app.config['core.titleBar'] = 'hidden';

        const { browserWindow: w0 } = new AtomWindow(app, service, {
          browserWindowConstructor: StubBrowserWindow
        });
        assert.isFalse(w0.options.frame);

        const { browserWindow: w1 } = new AtomWindow(app, service, {
          browserWindowConstructor: StubBrowserWindow,
          isSpec: true
        });
        assert.isUndefined(w1.options.frame);
      });
    } else {
      it('sets frame to "false" for a hidden title bar on non-spec windows', function() {
        app.config['core.titleBar'] = 'hidden';

        const { browserWindow: w0 } = new AtomWindow(app, service, {
          browserWindowConstructor: StubBrowserWindow
        });
        assert.isFalse(w0.options.frame);

        const { browserWindow: w1 } = new AtomWindow(app, service, {
          browserWindowConstructor: StubBrowserWindow,
          isSpec: true
        });
        assert.isUndefined(w1.options.frame);
      });
    }

    it('opens initial locations', async function() {
      const locationsToOpen = [
        {
          pathToOpen: 'file.txt',
          initialLine: 1,
          initialColumn: 2,
          isDirectory: false,
          hasWaitSession: false
        },
        {
          pathToOpen: '/directory',
          initialLine: null,
          initialColumn: null,
          isDirectory: true,
          hasWaitSession: false
        }
      ];

      const w = new AtomWindow(app, service, {
        browserWindowConstructor: StubBrowserWindow,
        locationsToOpen
      });
      assert.deepEqual(w.projectRoots, ['/directory']);

      const loadPromise = emitterEventPromise(w, 'window:loaded');
      w.browserWindow.emit('window:loaded');
      await loadPromise;

      assert.deepEqual(w.browserWindow.sent, [
        ['message', 'open-locations', locationsToOpen]
      ]);
    });

    it('does not open an initial null location', async function() {
      const w = new AtomWindow(app, service, {
        browserWindowConstructor: StubBrowserWindow,
        locationsToOpen: [{ pathToOpen: null }]
      });

      const loadPromise = emitterEventPromise(w, 'window:loaded');
      w.browserWindow.emit('window:loaded');
      await loadPromise;

      assert.lengthOf(w.browserWindow.sent, 0);
    });

    it('does not open initial locations in spec mode', async function() {
      const w = new AtomWindow(app, service, {
        browserWindowConstructor: StubBrowserWindow,
        locationsToOpen: [{ pathToOpen: 'file.txt' }],
        isSpec: true
      });

      const loadPromise = emitterEventPromise(w, 'window:loaded');
      w.browserWindow.emit('window:loaded');
      await loadPromise;

      assert.lengthOf(w.browserWindow.sent, 0);
    });

    it('focuses the webView for specs', function() {
      const w = new AtomWindow(app, service, {
        browserWindowConstructor: StubBrowserWindow,
        isSpec: true
      });

      assert.isTrue(w.browserWindow.behavior.focusOnWebView);
    });
  });

  describe('project root tracking', function() {
    it('knows when it has no roots', function() {
      const w = new AtomWindow(app, service, {
        browserWindowConstructor: StubBrowserWindow
      });
      assert.isFalse(w.hasProjectPaths());
    });

    it('is initialized from directories in the initial locationsToOpen', function() {
      const locationsToOpen = [
        { pathToOpen: 'file.txt', exists: true, isFile: true },
        { pathToOpen: 'directory0', exists: true, isDirectory: true },
        { pathToOpen: 'directory1', exists: true, isDirectory: true },
        { pathToOpen: 'new-file.txt' },
        { pathToOpen: null }
      ];

      const w = new AtomWindow(app, service, {
        browserWindowConstructor: StubBrowserWindow,
        locationsToOpen
      });

      assert.deepEqual(w.projectRoots, ['directory0', 'directory1']);
      assert.isTrue(w.loadSettings.hasOpenFiles);
      assert.deepEqual(w.loadSettings.initialProjectRoots, [
        'directory0',
        'directory1'
      ]);
      assert.isTrue(w.hasProjectPaths());
    });

    it('is updated synchronously by openLocations', async function() {
      const locationsToOpen = [
        { pathToOpen: 'file.txt', isFile: true },
        { pathToOpen: 'directory1', isDirectory: true },
        { pathToOpen: 'directory0', isDirectory: true },
        { pathToOpen: 'directory0', isDirectory: true },
        { pathToOpen: 'new-file.txt' }
      ];

      const w = new AtomWindow(app, service, {
        browserWindowConstructor: StubBrowserWindow
      });
      assert.deepEqual(w.projectRoots, []);

      const promise = w.openLocations(locationsToOpen);
      assert.deepEqual(w.projectRoots, ['directory0', 'directory1']);
      w.resolveLoadedPromise();
      await promise;
    });

    it('is updated by setProjectRoots', function() {
      const locationsToOpen = [
        { pathToOpen: 'directory0', exists: true, isDirectory: true }
      ];

      const w = new AtomWindow(app, service, {
        browserWindowConstructor: StubBrowserWindow,
        locationsToOpen
      });
      assert.deepEqual(w.projectRoots, ['directory0']);
      assert.deepEqual(w.loadSettings.initialProjectRoots, ['directory0']);

      w.setProjectRoots(['directory1', 'directory0', 'directory2']);
      assert.deepEqual(w.projectRoots, [
        'directory0',
        'directory1',
        'directory2'
      ]);
      assert.deepEqual(w.loadSettings.initialProjectRoots, [
        'directory0',
        'directory1',
        'directory2'
      ]);
    });

    it('never reports that it owns the empty path', function() {
      const locationsToOpen = [
        { pathToOpen: 'directory0', exists: true, isDirectory: true },
        { pathToOpen: 'directory1', exists: true, isDirectory: true },
        { pathToOpen: null }
      ];

      const w = new AtomWindow(app, service, {
        browserWindowConstructor: StubBrowserWindow,
        locationsToOpen
      });
      assert.isFalse(w.containsLocation({ pathToOpen: null }));
    });

    it('discovers an exact path match', function() {
      const locationsToOpen = [
        { pathToOpen: 'directory0', exists: true, isDirectory: true },
        { pathToOpen: 'directory1', exists: true, isDirectory: true }
      ];
      const w = new AtomWindow(app, service, {
        browserWindowConstructor: StubBrowserWindow,
        locationsToOpen
      });

      assert.isTrue(w.containsLocation({ pathToOpen: 'directory0' }));
      assert.isFalse(w.containsLocation({ pathToOpen: 'directory2' }));
    });

    it('discovers the path of a file within any project root', function() {
      const locationsToOpen = [
        { pathToOpen: 'directory0', exists: true, isDirectory: true },
        { pathToOpen: 'directory1', exists: true, isDirectory: true }
      ];
      const w = new AtomWindow(app, service, {
        browserWindowConstructor: StubBrowserWindow,
        locationsToOpen
      });

      assert.isTrue(
        w.containsLocation({
          pathToOpen: path.join('directory0/file-0.txt'),
          exists: true,
          isFile: true
        })
      );
      assert.isTrue(
        w.containsLocation({
          pathToOpen: path.join('directory0/deep/file-0.txt'),
          exists: true,
          isFile: true
        })
      );
      assert.isFalse(
        w.containsLocation({
          pathToOpen: path.join('directory2/file-9.txt'),
          exists: true,
          isFile: true
        })
      );
      assert.isFalse(
        w.containsLocation({
          pathToOpen: path.join('directory2/deep/file-9.txt'),
          exists: true,
          isFile: true
        })
      );
    });

    it('reports that it owns nonexistent paths within a project root', function() {
      const locationsToOpen = [
        { pathToOpen: 'directory0', exists: true, isDirectory: true },
        { pathToOpen: 'directory1', exists: true, isDirectory: true }
      ];
      const w = new AtomWindow(app, service, {
        browserWindowConstructor: StubBrowserWindow,
        locationsToOpen
      });

      assert.isTrue(
        w.containsLocation({
          pathToOpen: path.join('directory0/file-1.txt'),
          exists: false
        })
      );
      assert.isTrue(
        w.containsLocation({
          pathToOpen: path.join('directory1/subdir/file-0.txt'),
          exists: false
        })
      );
    });

    it('never reports that it owns directories within a project root', function() {
      const locationsToOpen = [
        { pathToOpen: 'directory0', exists: true, isDirectory: true },
        { pathToOpen: 'directory1', exists: true, isDirectory: true }
      ];
      const w = new AtomWindow(app, service, {
        browserWindowConstructor: StubBrowserWindow,
        locationsToOpen
      });

      assert.isFalse(
        w.containsLocation({
          pathToOpen: path.join('directory0/subdir-0'),
          exists: true,
          isDirectory: true
        })
      );
    });

    it('checks a full list of paths and reports if it owns all of them', function() {
      const locationsToOpen = [
        { pathToOpen: 'directory0', exists: true, isDirectory: true },
        { pathToOpen: 'directory1', exists: true, isDirectory: true }
      ];
      const w = new AtomWindow(app, service, {
        browserWindowConstructor: StubBrowserWindow,
        locationsToOpen
      });

      assert.isTrue(
        w.containsLocations([
          { pathToOpen: 'directory0' },
          {
            pathToOpen: path.join('directory1/file-0.txt'),
            exists: true,
            isFile: true
          }
        ])
      );
      assert.isFalse(
        w.containsLocations([
          { pathToOpen: 'directory2' },
          { pathToOpen: 'directory0' }
        ])
      );
      assert.isFalse(
        w.containsLocations([
          { pathToOpen: 'directory2' },
          { pathToOpen: 'directory1' }
        ])
      );
    });
  });
});

class StubApplication {
  constructor(sinon) {
    this.config = {
      'core.titleBar': 'native',
      get: key => this.config[key] || null
    };
    this.configFile = {
      get() {
        return 'stub-config';
      }
    };

    this.removeWindow = sinon.spy();
    this.saveCurrentWindowOptions = sinon.spy();
  }
}

class StubRecoveryService {
  constructor(sinon) {
    this.didCloseWindow = sinon.spy();
    this.didCrashWindow = sinon.spy();
  }
}

class StubBrowserWindow extends EventEmitter {
  constructor(options) {
    super();
    this.options = options;
    this.sent = [];
    this.behavior = {
      focusOnWebView: false
    };

    this.webContents = new EventEmitter();
    this.webContents.send = (...args) => {
      this.sent.push(args);
    };
    this.webContents.setVisualZoomLevelLimits = () => {};
  }

  loadURL() {}

  focusOnWebView() {
    this.behavior.focusOnWebView = true;
  }
}
