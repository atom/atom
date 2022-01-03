const AtomWindow = require('./atom-window');
const ApplicationMenu = require('./application-menu');
const AtomProtocolHandler = require('./atom-protocol-handler');
const AutoUpdateManager = require('./auto-update-manager');
const StorageFolder = require('../storage-folder');
const Config = require('../config');
const ConfigFile = require('../config-file');
const FileRecoveryService = require('./file-recovery-service');
const StartupTime = require('../startup-time');
const ipcHelpers = require('../ipc-helpers');
const {
  BrowserWindow,
  Menu,
  app,
  clipboard,
  dialog,
  ipcMain,
  shell,
  screen
} = require('electron');
const { CompositeDisposable, Disposable } = require('event-kit');
const crypto = require('crypto');
const fs = require('fs-plus');
const path = require('path');
const os = require('os');
const net = require('net');
const url = require('url');
const { promisify } = require('util');
const { EventEmitter } = require('events');
const _ = require('underscore-plus');
let FindParentDir = null;
let Resolve = null;
const ConfigSchema = require('../config-schema');

const LocationSuffixRegExp = /(:\d+)(:\d+)?$/;

// Increment this when changing the serialization format of `${ATOM_HOME}/storage/application.json` used by
// AtomApplication::saveCurrentWindowOptions() and AtomApplication::loadPreviousWindowOptions() in a backward-
// incompatible way.
const APPLICATION_STATE_VERSION = '1';

const getDefaultPath = () => {
  const editor = atom.workspace.getActiveTextEditor();
  if (!editor || !editor.getPath()) {
    return;
  }
  const paths = atom.project.getPaths();
  if (paths) {
    return paths[0];
  }
};

const getSocketSecretPath = atomVersion => {
  const { username } = os.userInfo();
  const atomHome = path.resolve(process.env.ATOM_HOME);

  return path.join(atomHome, `.atom-socket-secret-${username}-${atomVersion}`);
};

const getSocketPath = socketSecret => {
  if (!socketSecret) {
    return null;
  }

  // Hash the secret to create the socket name to not expose it.
  const socketName = crypto
    .createHmac('sha256', socketSecret)
    .update('socketName')
    .digest('hex')
    .substr(0, 12);

  if (process.platform === 'win32') {
    return `\\\\.\\pipe\\atom-${socketName}-sock`;
  } else {
    return path.join(os.tmpdir(), `atom-${socketName}.sock`);
  }
};

const getExistingSocketSecret = atomVersion => {
  const socketSecretPath = getSocketSecretPath(atomVersion);

  if (!fs.existsSync(socketSecretPath)) {
    return null;
  }

  return fs.readFileSync(socketSecretPath, 'utf8');
};

const getRandomBytes = promisify(crypto.randomBytes);
const writeFile = promisify(fs.writeFile);

const createSocketSecret = async atomVersion => {
  const socketSecret = (await getRandomBytes(16)).toString('hex');

  await writeFile(getSocketSecretPath(atomVersion), socketSecret, {
    encoding: 'utf8',
    mode: 0o600
  });

  return socketSecret;
};

const encryptOptions = (options, secret) => {
  const message = JSON.stringify(options);
  const initVector = crypto.randomBytes(16); // AES uses 16 bytes for iV
  const cipher = crypto.createCipheriv('aes-256-gcm', secret, initVector);

  let content = cipher.update(message, 'utf8', 'hex');
  content += cipher.final('hex');

  const authTag = cipher.getAuthTag().toString('hex');

  return JSON.stringify({
    authTag,
    content,
    initVector: initVector.toString('hex')
  });
};

const decryptOptions = (optionsMessage, secret) => {
  const { authTag, content, initVector } = JSON.parse(optionsMessage);

  const decipher = crypto.createDecipheriv(
    'aes-256-gcm',
    secret,
    Buffer.from(initVector, 'hex')
  );
  decipher.setAuthTag(Buffer.from(authTag, 'hex'));

  let message = decipher.update(content, 'hex', 'utf8');
  message += decipher.final('utf8');

  return JSON.parse(message);
};

ipcMain.handle('isDefaultProtocolClient', (_, { protocol, path, args }) => {
  return app.isDefaultProtocolClient(protocol, path, args);
});

ipcMain.handle('setAsDefaultProtocolClient', (_, { protocol, path, args }) => {
  return app.setAsDefaultProtocolClient(protocol, path, args);
});
// The application's singleton class.
//
// It's the entry point into the Atom application and maintains the global state
// of the application.
//
module.exports = class AtomApplication extends EventEmitter {
  // Public: The entry point into the Atom application.
  static open(options) {
    StartupTime.addMarker('main-process:atom-application:open');

    const socketSecret = getExistingSocketSecret(options.version);
    const socketPath = getSocketPath(socketSecret);
    const createApplication =
      options.createApplication ||
      (async () => {
        const app = new AtomApplication(options);
        await app.initialize(options);
        return app;
      });

    // FIXME: Sometimes when socketPath doesn't exist, net.connect would strangely
    // take a few seconds to trigger 'error' event, it could be a bug of node
    // or electron, before it's fixed we check the existence of socketPath to
    // speedup startup.
    if (
      !socketPath ||
      options.test ||
      options.benchmark ||
      options.benchmarkTest ||
      (process.platform !== 'win32' && !fs.existsSync(socketPath))
    ) {
      return createApplication(options);
    }

    return new Promise(resolve => {
      const client = net.connect({ path: socketPath }, () => {
        client.write(encryptOptions(options, socketSecret), () => {
          client.end();
          app.quit();
          resolve(null);
        });
      });

      client.on('error', () => resolve(createApplication(options)));
    });
  }

  exit(status) {
    app.exit(status);
  }

  constructor(options) {
    StartupTime.addMarker('main-process:atom-application:constructor:start');

    super();
    this.quitting = false;
    this.quittingForUpdate = false;
    this.getAllWindows = this.getAllWindows.bind(this);
    this.getLastFocusedWindow = this.getLastFocusedWindow.bind(this);
    this.resourcePath = options.resourcePath;
    this.devResourcePath = options.devResourcePath;
    this.version = options.version;
    this.devMode = options.devMode;
    this.safeMode = options.safeMode;
    this.logFile = options.logFile;
    this.userDataDir = options.userDataDir;
    this._killProcess = options.killProcess || process.kill.bind(process);
    this.waitSessionsByWindow = new Map();
    this.windowStack = new WindowStack();

    this.initializeAtomHome(process.env.ATOM_HOME);

    const configFilePath = fs.existsSync(
      path.join(process.env.ATOM_HOME, 'config.json')
    )
      ? path.join(process.env.ATOM_HOME, 'config.json')
      : path.join(process.env.ATOM_HOME, 'config.cson');

    this.configFile = ConfigFile.at(configFilePath);
    this.config = new Config({
      saveCallback: settings => {
        if (!this.quitting) {
          return this.configFile.update(settings);
        }
      }
    });
    this.config.setSchema(null, {
      type: 'object',
      properties: _.clone(ConfigSchema)
    });

    this.fileRecoveryService = new FileRecoveryService(
      path.join(process.env.ATOM_HOME, 'recovery')
    );
    this.storageFolder = new StorageFolder(process.env.ATOM_HOME);
    this.autoUpdateManager = new AutoUpdateManager(
      this.version,
      options.test || options.benchmark || options.benchmarkTest,
      this.config
    );

    this.disposable = new CompositeDisposable();
    this.handleEvents();

    StartupTime.addMarker('main-process:atom-application:constructor:end');
  }

  // This stuff was previously done in the constructor, but we want to be able to construct this object
  // for testing purposes without booting up the world. As you add tests, feel free to move instantiation
  // of these various sub-objects into the constructor, but you'll need to remove the side-effects they
  // perform during their construction, adding an initialize method that you call here.
  async initialize(options) {
    StartupTime.addMarker('main-process:atom-application:initialize:start');

    global.atomApplication = this;

    this.applicationMenu = new ApplicationMenu(
      this.version,
      this.autoUpdateManager
    );
    this.atomProtocolHandler = new AtomProtocolHandler(
      this.resourcePath,
      this.safeMode
    );

    let socketServerPromise;
    if (options.test || options.benchmark || options.benchmarkTest) {
      socketServerPromise = Promise.resolve();
    } else {
      socketServerPromise = this.listenForArgumentsFromNewProcess();
    }

    await socketServerPromise;
    this.setupDockMenu();

    const result = await this.launch(options);
    this.autoUpdateManager.initialize();

    StartupTime.addMarker('main-process:atom-application:initialize:end');

    return result;
  }

  async destroy() {
    const windowsClosePromises = this.getAllWindows().map(window => {
      window.close();
      return window.closedPromise;
    });
    await Promise.all(windowsClosePromises);
    this.disposable.dispose();
  }

  async launch(options) {
    if (!this.configFilePromise) {
      this.configFilePromise = this.configFile.watch().then(disposable => {
        this.disposable.add(disposable);
        this.config.onDidChange('core.titleBar', () => this.promptForRestart());
        this.config.onDidChange('core.colorProfile', () =>
          this.promptForRestart()
        );
      });
      await this.configFilePromise;
    }

    let optionsForWindowsToOpen = [];
    let shouldReopenPreviousWindows = false;

    if (options.test || options.benchmark || options.benchmarkTest) {
      optionsForWindowsToOpen.push(options);
    } else if (options.newWindow) {
      shouldReopenPreviousWindows = false;
    } else if (
      (options.pathsToOpen && options.pathsToOpen.length > 0) ||
      (options.urlsToOpen && options.urlsToOpen.length > 0)
    ) {
      optionsForWindowsToOpen.push(options);
      shouldReopenPreviousWindows =
        this.config.get('core.restorePreviousWindowsOnStart') === 'always';
    } else {
      shouldReopenPreviousWindows =
        this.config.get('core.restorePreviousWindowsOnStart') !== 'no';
    }

    if (shouldReopenPreviousWindows) {
      optionsForWindowsToOpen = [
        ...(await this.loadPreviousWindowOptions()),
        ...optionsForWindowsToOpen
      ];
    }

    if (optionsForWindowsToOpen.length === 0) {
      optionsForWindowsToOpen.push(options);
    }

    // Preserve window opening order
    const windows = [];
    for (const options of optionsForWindowsToOpen) {
      windows.push(await this.openWithOptions(options));
    }
    return windows;
  }

  openWithOptions(options) {
    const {
      pathsToOpen,
      executedFrom,
      foldersToOpen,
      urlsToOpen,
      benchmark,
      benchmarkTest,
      test,
      pidToKillWhenClosed,
      devMode,
      safeMode,
      newWindow,
      logFile,
      profileStartup,
      timeout,
      clearWindowState,
      addToLastWindow,
      preserveFocus,
      env
    } = options;

    if (!preserveFocus) {
      app.focus();
    }

    if (test) {
      return this.runTests({
        headless: true,
        devMode,
        resourcePath: this.resourcePath,
        executedFrom,
        pathsToOpen,
        logFile,
        timeout,
        env
      });
    } else if (benchmark || benchmarkTest) {
      return this.runBenchmarks({
        headless: true,
        test: benchmarkTest,
        resourcePath: this.resourcePath,
        executedFrom,
        pathsToOpen,
        timeout,
        env
      });
    } else if (
      (pathsToOpen && pathsToOpen.length > 0) ||
      (foldersToOpen && foldersToOpen.length > 0)
    ) {
      return this.openPaths({
        pathsToOpen,
        foldersToOpen,
        executedFrom,
        pidToKillWhenClosed,
        newWindow,
        devMode,
        safeMode,
        profileStartup,
        clearWindowState,
        addToLastWindow,
        env
      });
    } else if (urlsToOpen && urlsToOpen.length > 0) {
      return Promise.all(
        urlsToOpen.map(urlToOpen =>
          this.openUrl({ urlToOpen, devMode, safeMode, env })
        )
      );
    } else {
      // Always open an editor window if this is the first instance of Atom.
      return this.openPath({
        pathToOpen: null,
        pidToKillWhenClosed,
        newWindow,
        devMode,
        safeMode,
        profileStartup,
        clearWindowState,
        addToLastWindow,
        env
      });
    }
  }

  // Public: Create a new {AtomWindow} bound to this application.
  createWindow(settings) {
    return new AtomWindow(this, this.fileRecoveryService, settings);
  }

  // Public: Removes the {AtomWindow} from the global window list.
  removeWindow(window) {
    this.windowStack.removeWindow(window);
    if (this.getAllWindows().length === 0 && process.platform !== 'darwin') {
      app.quit();
      return;
    }
    if (!window.isSpec) this.saveCurrentWindowOptions(true);
  }

  // Public: Adds the {AtomWindow} to the global window list.
  addWindow(window) {
    this.windowStack.addWindow(window);
    if (this.applicationMenu)
      this.applicationMenu.addWindow(window.browserWindow);

    window.once('window:loaded', () => {
      this.autoUpdateManager &&
        this.autoUpdateManager.emitUpdateAvailableEvent(window);
    });

    if (!window.isSpec) {
      const focusHandler = () => this.windowStack.touch(window);
      const blurHandler = () => this.saveCurrentWindowOptions(false);
      window.browserWindow.on('focus', focusHandler);
      window.browserWindow.on('blur', blurHandler);
      window.browserWindow.once('closed', () => {
        this.windowStack.removeWindow(window);
        window.browserWindow.removeListener('focus', focusHandler);
        window.browserWindow.removeListener('blur', blurHandler);
      });
      window.browserWindow.webContents.once('did-finish-load', blurHandler);
      this.saveCurrentWindowOptions(false);
    }
  }

  getAllWindows() {
    return this.windowStack.all().slice();
  }

  getLastFocusedWindow(predicate) {
    return this.windowStack.getLastFocusedWindow(predicate);
  }

  // Creates server to listen for additional atom application launches.
  //
  // You can run the atom command multiple times, but after the first launch
  // the other launches will just pass their information to this server and then
  // close immediately.
  async listenForArgumentsFromNewProcess() {
    this.socketSecretPromise = createSocketSecret(this.version);
    this.socketSecret = await this.socketSecretPromise;
    this.socketPath = getSocketPath(this.socketSecret);

    await this.deleteSocketFile();

    const server = net.createServer(connection => {
      let data = '';
      connection.on('data', chunk => {
        data += chunk;
      });
      connection.on('end', () => {
        try {
          const options = decryptOptions(data, this.socketSecret);
          this.openWithOptions(options);
        } catch (e) {
          // Error while parsing/decrypting the options passed by the client.
          // We cannot trust the client, aborting.
        }
      });
    });

    return new Promise(resolve => {
      server.listen(this.socketPath, resolve);
      server.on('error', error =>
        console.error('Application server failed', error)
      );
    });
  }

  async deleteSocketFile() {
    if (process.platform === 'win32') return;

    if (!this.socketSecretPromise) {
      return;
    }
    await this.socketSecretPromise;

    if (fs.existsSync(this.socketPath)) {
      try {
        fs.unlinkSync(this.socketPath);
      } catch (error) {
        // Ignore ENOENT errors in case the file was deleted between the exists
        // check and the call to unlink sync. This occurred occasionally on CI
        // which is why this check is here.
        if (error.code !== 'ENOENT') throw error;
      }
    }
  }

  async deleteSocketSecretFile() {
    if (!this.socketSecretPromise) {
      return;
    }
    await this.socketSecretPromise;

    const socketSecretPath = getSocketSecretPath(this.version);

    if (fs.existsSync(socketSecretPath)) {
      try {
        fs.unlinkSync(socketSecretPath);
      } catch (error) {
        // Ignore ENOENT errors in case the file was deleted between the exists
        // check and the call to unlink sync.
        if (error.code !== 'ENOENT') throw error;
      }
    }
  }

  // Registers basic application commands, non-idempotent.
  handleEvents() {
    const createOpenSettings = ({ event, sameWindow }) => {
      const targetWindow = event
        ? this.atomWindowForEvent(event)
        : this.focusedWindow();
      return {
        devMode: targetWindow ? targetWindow.devMode : false,
        safeMode: targetWindow ? targetWindow.safeMode : false,
        window: sameWindow && targetWindow ? targetWindow : null
      };
    };

    this.on('application:quit', () => app.quit());
    this.on('application:new-window', () =>
      this.openPath(createOpenSettings({}))
    );
    this.on('application:new-file', () =>
      (this.focusedWindow() || this).openPath()
    );
    this.on('application:open-dev', () =>
      this.promptForPathToOpen('all', { devMode: true })
    );
    this.on('application:open-safe', () =>
      this.promptForPathToOpen('all', { safeMode: true })
    );
    this.on('application:inspect', ({ x, y, atomWindow }) => {
      if (!atomWindow) atomWindow = this.focusedWindow();
      if (atomWindow) atomWindow.browserWindow.inspectElement(x, y);
    });

    this.on('application:open-documentation', () =>
      shell.openExternal('http://flight-manual.atom.io')
    );
    this.on('application:open-discussions', () =>
      shell.openExternal('https://github.com/atom/atom/discussions')
    );
    this.on('application:open-faq', () =>
      shell.openExternal('https://atom.io/faq')
    );
    this.on('application:open-terms-of-use', () =>
      shell.openExternal('https://atom.io/terms')
    );
    this.on('application:report-issue', () =>
      shell.openExternal(
        'https://github.com/atom/atom/blob/master/CONTRIBUTING.md#reporting-bugs'
      )
    );
    this.on('application:search-issues', () =>
      shell.openExternal('https://github.com/search?q=+is%3Aissue+user%3Aatom')
    );

    this.on('application:install-update', () => {
      this.quitting = true;
      this.quittingForUpdate = true;
      this.autoUpdateManager.install();
    });

    this.on('application:check-for-update', () =>
      this.autoUpdateManager.check()
    );

    if (process.platform === 'darwin') {
      this.on('application:reopen-project', ({ paths }) => {
        const focusedWindow = this.focusedWindow();
        if (focusedWindow) {
          const { safeMode, devMode } = focusedWindow;
          this.openPaths({ pathsToOpen: paths, safeMode, devMode });
          return;
        }
        this.openPaths({ pathsToOpen: paths });
      });

      this.on('application:open', () => {
        this.promptForPathToOpen(
          'all',
          createOpenSettings({ sameWindow: true }),
          getDefaultPath()
        );
      });
      this.on('application:open-file', () => {
        this.promptForPathToOpen(
          'file',
          createOpenSettings({ sameWindow: true }),
          getDefaultPath()
        );
      });
      this.on('application:open-folder', () => {
        this.promptForPathToOpen(
          'folder',
          createOpenSettings({ sameWindow: true }),
          getDefaultPath()
        );
      });

      this.on('application:bring-all-windows-to-front', () =>
        Menu.sendActionToFirstResponder('arrangeInFront:')
      );
      this.on('application:hide', () =>
        Menu.sendActionToFirstResponder('hide:')
      );
      this.on('application:hide-other-applications', () =>
        Menu.sendActionToFirstResponder('hideOtherApplications:')
      );
      this.on('application:minimize', () =>
        Menu.sendActionToFirstResponder('performMiniaturize:')
      );
      this.on('application:unhide-all-applications', () =>
        Menu.sendActionToFirstResponder('unhideAllApplications:')
      );
      this.on('application:zoom', () =>
        Menu.sendActionToFirstResponder('zoom:')
      );
    } else {
      this.on('application:minimize', () => {
        const window = this.focusedWindow();
        if (window) window.minimize();
      });
      this.on('application:zoom', function() {
        const window = this.focusedWindow();
        if (window) window.maximize();
      });
    }

    this.openPathOnEvent('application:about', 'atom://about');
    this.openPathOnEvent('application:show-settings', 'atom://config');
    this.openPathOnEvent('application:open-your-config', 'atom://.atom/config');
    this.openPathOnEvent(
      'application:open-your-init-script',
      'atom://.atom/init-script'
    );
    this.openPathOnEvent('application:open-your-keymap', 'atom://.atom/keymap');
    this.openPathOnEvent(
      'application:open-your-snippets',
      'atom://.atom/snippets'
    );
    this.openPathOnEvent(
      'application:open-your-stylesheet',
      'atom://.atom/stylesheet'
    );
    this.openPathOnEvent(
      'application:open-license',
      path.join(process.resourcesPath, 'LICENSE.md')
    );

    this.configFile.onDidChange(settings => {
      for (let window of this.getAllWindows()) {
        window.didChangeUserSettings(settings);
      }
      this.config.resetUserSettings(settings);
    });

    this.configFile.onDidError(message => {
      const window = this.focusedWindow() || this.getLastFocusedWindow();
      if (window) {
        window.didFailToReadUserSettings(message);
      } else {
        console.error(message);
      }
    });

    this.disposable.add(
      ipcHelpers.on(app, 'before-quit', async event => {
        let resolveBeforeQuitPromise;
        this.lastBeforeQuitPromise = new Promise(resolve => {
          resolveBeforeQuitPromise = resolve;
        });

        if (!this.quitting) {
          this.quitting = true;
          event.preventDefault();
          const windowUnloadPromises = this.getAllWindows().map(
            async window => {
              const unloaded = await window.prepareToUnload();
              if (unloaded) {
                window.close();
                await window.closedPromise;
              }
              return unloaded;
            }
          );
          const windowUnloadedResults = await Promise.all(windowUnloadPromises);
          if (windowUnloadedResults.every(Boolean)) {
            app.quit();
          } else {
            this.quitting = false;
          }
        }

        resolveBeforeQuitPromise();
      })
    );

    this.disposable.add(
      ipcHelpers.on(app, 'will-quit', () => {
        this.killAllProcesses();

        return Promise.all([
          this.deleteSocketFile(),
          this.deleteSocketSecretFile()
        ]);
      })
    );

    // See: https://www.electronjs.org/docs/api/app#event-window-all-closed
    this.disposable.add(
      ipcHelpers.on(app, 'window-all-closed', () => {
        if (this.applicationMenu != null) {
          this.applicationMenu.enableWindowSpecificItems(false);
        }
        // Don't quit when the last window is closed on macOS.
        if (process.platform !== 'darwin') {
          app.quit();
        }
      })
    );

    // Triggered by the 'open-file' event from Electron:
    // https://electronjs.org/docs/api/app#event-open-file-macos
    // For example, this is fired when a file is dragged and dropped onto the Atom application icon in the dock.
    this.disposable.add(
      ipcHelpers.on(app, 'open-file', (event, pathToOpen) => {
        event.preventDefault();
        this.openPath({ pathToOpen });
      })
    );

    this.disposable.add(
      ipcHelpers.on(app, 'open-url', (event, urlToOpen) => {
        event.preventDefault();
        this.openUrl({
          urlToOpen,
          devMode: this.devMode,
          safeMode: this.safeMode
        });
      })
    );

    this.disposable.add(
      ipcHelpers.on(app, 'activate', (event, hasVisibleWindows) => {
        if (hasVisibleWindows) return;
        if (event) event.preventDefault();
        this.emit('application:new-window');
      })
    );

    this.disposable.add(
      ipcHelpers.on(ipcMain, 'restart-application', () => {
        this.restart();
      })
    );

    this.disposable.add(
      ipcHelpers.on(ipcMain, 'resolve-proxy', async (event, requestId, url) => {
        const proxy = await event.sender.session.resolveProxy(url);
        if (!event.sender.isDestroyed())
          event.sender.send('did-resolve-proxy', requestId, proxy);
      })
    );

    this.disposable.add(
      ipcHelpers.on(ipcMain, 'did-change-history-manager', event => {
        for (let atomWindow of this.getAllWindows()) {
          const { webContents } = atomWindow.browserWindow;
          if (webContents !== event.sender)
            webContents.send('did-change-history-manager');
        }
      })
    );

    // A request from the associated render process to open a set of paths using the standard window location logic.
    // Used for application:reopen-project.
    this.disposable.add(
      ipcHelpers.on(ipcMain, 'open', (event, options) => {
        if (options) {
          if (typeof options.pathsToOpen === 'string') {
            options.pathsToOpen = [options.pathsToOpen];
          }

          if (options.here) {
            options.window = this.atomWindowForEvent(event);
          }

          if (options.pathsToOpen && options.pathsToOpen.length > 0) {
            this.openPaths(options);
          } else {
            this.addWindow(this.createWindow(options));
          }
        } else {
          this.promptForPathToOpen('all', {});
        }
      })
    );

    // Prompt for a file, folder, or either, then open the chosen paths. Files will be opened in the originating
    // window; folders will be opened in a new window unless an existing window exactly contains all of them.
    this.disposable.add(
      ipcHelpers.on(ipcMain, 'open-chosen-any', (event, defaultPath) => {
        this.promptForPathToOpen(
          'all',
          createOpenSettings({ event, sameWindow: true }),
          defaultPath
        );
      })
    );
    this.disposable.add(
      ipcHelpers.on(ipcMain, 'open-chosen-file', (event, defaultPath) => {
        this.promptForPathToOpen(
          'file',
          createOpenSettings({ event, sameWindow: true }),
          defaultPath
        );
      })
    );
    this.disposable.add(
      ipcHelpers.on(ipcMain, 'open-chosen-folder', (event, defaultPath) => {
        this.promptForPathToOpen(
          'folder',
          createOpenSettings({ event }),
          defaultPath
        );
      })
    );

    this.disposable.add(
      ipcHelpers.on(
        ipcMain,
        'update-application-menu',
        (event, template, menu) => {
          const window = BrowserWindow.fromWebContents(event.sender);
          if (this.applicationMenu)
            this.applicationMenu.update(window, template, menu);
        }
      )
    );

    this.disposable.add(
      ipcHelpers.on(
        ipcMain,
        'run-package-specs',
        (event, packageSpecPath, options = {}) => {
          this.runTests(
            Object.assign(
              {
                resourcePath: this.devResourcePath,
                pathsToOpen: [packageSpecPath],
                headless: false
              },
              options
            )
          );
        }
      )
    );

    this.disposable.add(
      ipcHelpers.on(ipcMain, 'run-benchmarks', (event, benchmarksPath) => {
        this.runBenchmarks({
          resourcePath: this.devResourcePath,
          pathsToOpen: [benchmarksPath],
          headless: false,
          test: false
        });
      })
    );

    this.disposable.add(
      ipcHelpers.on(ipcMain, 'command', (event, command) => {
        this.emit(command);
      })
    );

    this.disposable.add(
      ipcHelpers.on(ipcMain, 'window-command', (event, command, ...args) => {
        const window = BrowserWindow.fromWebContents(event.sender);
        return window && window.emit(command, ...args);
      })
    );

    this.disposable.add(
      ipcHelpers.respondTo(
        'window-method',
        (browserWindow, method, ...args) => {
          const window = this.atomWindowForBrowserWindow(browserWindow);
          if (window) window[method](...args);
        }
      )
    );

    this.disposable.add(
      ipcHelpers.on(ipcMain, 'pick-folder', (event, responseChannel) => {
        this.promptForPath('folder', paths =>
          event.sender.send(responseChannel, paths)
        );
      })
    );

    this.disposable.add(
      ipcHelpers.respondTo('set-window-size', (window, width, height) => {
        window.setSize(width, height);
      })
    );

    this.disposable.add(
      ipcHelpers.respondTo('set-window-position', (window, x, y) => {
        window.setPosition(x, y);
      })
    );

    this.disposable.add(
      ipcHelpers.respondTo(
        'set-user-settings',
        (window, settings, filePath) => {
          if (!this.quitting) {
            return ConfigFile.at(filePath || this.configFilePath).update(
              JSON.parse(settings)
            );
          }
        }
      )
    );

    this.disposable.add(
      ipcHelpers.respondTo('center-window', window => window.center())
    );
    this.disposable.add(
      ipcHelpers.respondTo('focus-window', window => window.focus())
    );
    this.disposable.add(
      ipcHelpers.respondTo('show-window', window => window.show())
    );
    this.disposable.add(
      ipcHelpers.respondTo('hide-window', window => window.hide())
    );
    this.disposable.add(
      ipcHelpers.respondTo(
        'get-temporary-window-state',
        window => window.temporaryState
      )
    );

    this.disposable.add(
      ipcHelpers.respondTo('set-temporary-window-state', (win, state) => {
        win.temporaryState = state;
      })
    );

    this.disposable.add(
      ipcHelpers.on(
        ipcMain,
        'write-text-to-selection-clipboard',
        (event, text) => clipboard.writeText(text, 'selection')
      )
    );

    this.disposable.add(
      ipcHelpers.on(ipcMain, 'write-to-stdout', (event, output) =>
        process.stdout.write(output)
      )
    );

    this.disposable.add(
      ipcHelpers.on(ipcMain, 'write-to-stderr', (event, output) =>
        process.stderr.write(output)
      )
    );

    this.disposable.add(
      ipcHelpers.on(ipcMain, 'add-recent-document', (event, filename) =>
        app.addRecentDocument(filename)
      )
    );

    this.disposable.add(
      ipcHelpers.on(
        ipcMain,
        'execute-javascript-in-dev-tools',
        (event, code) =>
          event.sender.devToolsWebContents &&
          event.sender.devToolsWebContents.executeJavaScript(code)
      )
    );

    this.disposable.add(
      ipcHelpers.on(ipcMain, 'get-auto-update-manager-state', event => {
        event.returnValue = this.autoUpdateManager.getState();
      })
    );

    this.disposable.add(
      ipcHelpers.on(ipcMain, 'get-auto-update-manager-error', event => {
        event.returnValue = this.autoUpdateManager.getErrorMessage();
      })
    );

    this.disposable.add(
      ipcHelpers.respondTo('will-save-path', (window, path) =>
        this.fileRecoveryService.willSavePath(window, path)
      )
    );

    this.disposable.add(
      ipcHelpers.respondTo('did-save-path', (window, path) =>
        this.fileRecoveryService.didSavePath(window, path)
      )
    );

    this.disposable.add(this.disableZoomOnDisplayChange());
  }

  setupDockMenu() {
    if (process.platform === 'darwin') {
      return app.dock.setMenu(
        Menu.buildFromTemplate([
          {
            label: 'New Window',
            click: () => this.emit('application:new-window')
          }
        ])
      );
    }
  }

  initializeAtomHome(configDirPath) {
    if (!fs.existsSync(configDirPath)) {
      const templateConfigDirPath = fs.resolve(this.resourcePath, 'dot-atom');
      fs.copySync(templateConfigDirPath, configDirPath);
    }
  }

  // Public: Executes the given command.
  //
  // If it isn't handled globally, delegate to the currently focused window.
  //
  // command - The string representing the command.
  // args - The optional arguments to pass along.
  sendCommand(command, ...args) {
    if (!this.emit(command, ...args)) {
      const focusedWindow = this.focusedWindow();
      if (focusedWindow) {
        return focusedWindow.sendCommand(command, ...args);
      } else {
        return this.sendCommandToFirstResponder(command);
      }
    }
  }

  // Public: Executes the given command on the given window.
  //
  // command - The string representing the command.
  // atomWindow - The {AtomWindow} to send the command to.
  // args - The optional arguments to pass along.
  sendCommandToWindow(command, atomWindow, ...args) {
    if (!this.emit(command, ...args)) {
      if (atomWindow) {
        return atomWindow.sendCommand(command, ...args);
      } else {
        return this.sendCommandToFirstResponder(command);
      }
    }
  }

  // Translates the command into macOS action and sends it to application's first
  // responder.
  sendCommandToFirstResponder(command) {
    if (process.platform !== 'darwin') return false;

    switch (command) {
      case 'core:undo':
        Menu.sendActionToFirstResponder('undo:');
        break;
      case 'core:redo':
        Menu.sendActionToFirstResponder('redo:');
        break;
      case 'core:copy':
        Menu.sendActionToFirstResponder('copy:');
        break;
      case 'core:cut':
        Menu.sendActionToFirstResponder('cut:');
        break;
      case 'core:paste':
        Menu.sendActionToFirstResponder('paste:');
        break;
      case 'core:select-all':
        Menu.sendActionToFirstResponder('selectAll:');
        break;
      default:
        return false;
    }
    return true;
  }

  // Public: Open the given path in the focused window when the event is
  // triggered.
  //
  // A new window will be created if there is no currently focused window.
  //
  // eventName - The event to listen for.
  // pathToOpen - The path to open when the event is triggered.
  openPathOnEvent(eventName, pathToOpen) {
    this.on(eventName, () => {
      const window = this.focusedWindow();
      if (window) {
        return window.openPath(pathToOpen);
      } else {
        return this.openPath({ pathToOpen });
      }
    });
  }

  // Returns the {AtomWindow} for the given locations.
  windowForLocations(locationsToOpen, devMode, safeMode) {
    return this.getLastFocusedWindow(
      window =>
        !window.isSpec &&
        window.devMode === devMode &&
        window.safeMode === safeMode &&
        window.containsLocations(locationsToOpen)
    );
  }

  // Returns the {AtomWindow} for the given ipcMain event.
  atomWindowForEvent({ sender }) {
    return this.atomWindowForBrowserWindow(
      BrowserWindow.fromWebContents(sender)
    );
  }

  atomWindowForBrowserWindow(browserWindow) {
    return this.getAllWindows().find(
      atomWindow => atomWindow.browserWindow === browserWindow
    );
  }

  // Public: Returns the currently focused {AtomWindow} or undefined if none.
  focusedWindow() {
    return this.getAllWindows().find(window => window.isFocused());
  }

  // Get the platform-specific window offset for new windows.
  getWindowOffsetForCurrentPlatform() {
    const offsetByPlatform = {
      darwin: 22,
      win32: 26
    };
    return offsetByPlatform[process.platform] || 0;
  }

  // Get the dimensions for opening a new window by cascading as appropriate to
  // the platform.
  getDimensionsForNewWindow() {
    const window = this.focusedWindow() || this.getLastFocusedWindow();
    if (!window || window.isMaximized()) return;
    const dimensions = window.getDimensions();
    if (dimensions) {
      const offset = this.getWindowOffsetForCurrentPlatform();
      dimensions.x += offset;
      dimensions.y += offset;
      return dimensions;
    }
  }

  // Public: Opens a single path, in an existing window if possible.
  //
  // options -
  //   :pathToOpen - The file path to open
  //   :pidToKillWhenClosed - The integer of the pid to kill
  //   :newWindow - Boolean of whether this should be opened in a new window.
  //   :devMode - Boolean to control the opened window's dev mode.
  //   :safeMode - Boolean to control the opened window's safe mode.
  //   :profileStartup - Boolean to control creating a profile of the startup time.
  //   :window - {AtomWindow} to open file paths in.
  //   :addToLastWindow - Boolean of whether this should be opened in last focused window.
  openPath({
    pathToOpen,
    pidToKillWhenClosed,
    newWindow,
    devMode,
    safeMode,
    profileStartup,
    window,
    clearWindowState,
    addToLastWindow,
    env
  } = {}) {
    return this.openPaths({
      pathsToOpen: [pathToOpen],
      pidToKillWhenClosed,
      newWindow,
      devMode,
      safeMode,
      profileStartup,
      window,
      clearWindowState,
      addToLastWindow,
      env
    });
  }

  // Public: Opens multiple paths, in existing windows if possible.
  //
  // options -
  //   :pathsToOpen - The array of file paths to open
  //   :foldersToOpen - An array of additional paths to open that must be existing directories
  //   :pidToKillWhenClosed - The integer of the pid to kill
  //   :newWindow - Boolean of whether this should be opened in a new window.
  //   :devMode - Boolean to control the opened window's dev mode.
  //   :safeMode - Boolean to control the opened window's safe mode.
  //   :windowDimensions - Object with height and width keys.
  //   :window - {AtomWindow} to open file paths in.
  //   :addToLastWindow - Boolean of whether this should be opened in last focused window.
  async openPaths({
    pathsToOpen,
    foldersToOpen,
    executedFrom,
    pidToKillWhenClosed,
    newWindow,
    devMode,
    safeMode,
    windowDimensions,
    profileStartup,
    window,
    clearWindowState,
    addToLastWindow,
    env
  } = {}) {
    if (!env) env = process.env;
    if (!pathsToOpen) pathsToOpen = [];
    if (!foldersToOpen) foldersToOpen = [];

    devMode = Boolean(devMode);
    safeMode = Boolean(safeMode);
    clearWindowState = Boolean(clearWindowState);

    const locationsToOpen = await Promise.all(
      pathsToOpen.map(pathToOpen =>
        this.parsePathToOpen(pathToOpen, executedFrom, {
          hasWaitSession: pidToKillWhenClosed != null
        })
      )
    );

    for (const folderToOpen of foldersToOpen) {
      locationsToOpen.push({
        pathToOpen: folderToOpen,
        initialLine: null,
        initialColumn: null,
        exists: true,
        isDirectory: true,
        hasWaitSession: pidToKillWhenClosed != null
      });
    }

    if (locationsToOpen.length === 0) {
      return;
    }

    const hasNonEmptyPath = locationsToOpen.some(
      location => location.pathToOpen
    );
    const createNewWindow = newWindow || !hasNonEmptyPath;

    let existingWindow;

    if (!createNewWindow) {
      // An explicitly provided AtomWindow has precedence.
      existingWindow = window;

      // If no window is specified and at least one path is provided, locate an existing window that contains all
      // provided paths.
      if (!existingWindow && hasNonEmptyPath) {
        existingWindow = this.windowForLocations(
          locationsToOpen,
          devMode,
          safeMode
        );
      }

      // No window specified, no existing window found, and addition to the last window requested. Find the last
      // focused window that matches the requested dev and safe modes.
      if (!existingWindow && addToLastWindow) {
        existingWindow = this.getLastFocusedWindow(win => {
          return (
            !win.isSpec && win.devMode === devMode && win.safeMode === safeMode
          );
        });
      }

      // Fall back to the last focused window that has no project roots.
      if (!existingWindow) {
        existingWindow = this.getLastFocusedWindow(
          win => !win.isSpec && !win.hasProjectPaths()
        );
      }

      // One last case: if *no* paths are directories, add to the last focused window.
      if (!existingWindow) {
        const noDirectories = locationsToOpen.every(
          location => !location.isDirectory
        );
        if (noDirectories) {
          existingWindow = this.getLastFocusedWindow(win => {
            return (
              !win.isSpec &&
              win.devMode === devMode &&
              win.safeMode === safeMode
            );
          });
        }
      }
    }

    let openedWindow;
    if (existingWindow) {
      openedWindow = existingWindow;
      StartupTime.addMarker('main-process:atom-application:open-in-existing');
      openedWindow.openLocations(locationsToOpen);
      if (openedWindow.isMinimized()) {
        openedWindow.restore();
      } else {
        openedWindow.focus();
      }
      openedWindow.replaceEnvironment(env);
    } else {
      let resourcePath, windowInitializationScript;
      if (devMode) {
        try {
          windowInitializationScript = require.resolve(
            path.join(
              this.devResourcePath,
              'src',
              'initialize-application-window'
            )
          );
          resourcePath = this.devResourcePath;
        } catch (error) {}
      }

      if (!windowInitializationScript) {
        windowInitializationScript = require.resolve(
          '../initialize-application-window'
        );
      }
      if (!resourcePath) resourcePath = this.resourcePath;
      if (!windowDimensions)
        windowDimensions = this.getDimensionsForNewWindow();

      StartupTime.addMarker('main-process:atom-application:create-window');
      openedWindow = this.createWindow({
        locationsToOpen,
        windowInitializationScript,
        resourcePath,
        devMode,
        safeMode,
        windowDimensions,
        profileStartup,
        clearWindowState,
        env
      });
      this.addWindow(openedWindow);
      openedWindow.focus();
    }

    if (pidToKillWhenClosed != null) {
      if (!this.waitSessionsByWindow.has(openedWindow)) {
        this.waitSessionsByWindow.set(openedWindow, []);
      }
      this.waitSessionsByWindow.get(openedWindow).push({
        pid: pidToKillWhenClosed,
        remainingPaths: new Set(
          locationsToOpen.map(location => location.pathToOpen).filter(Boolean)
        )
      });
    }

    openedWindow.browserWindow.once('closed', () =>
      this.killProcessesForWindow(openedWindow)
    );
    return openedWindow;
  }

  // Kill all processes associated with opened windows.
  killAllProcesses() {
    for (let window of this.waitSessionsByWindow.keys()) {
      this.killProcessesForWindow(window);
    }
  }

  killProcessesForWindow(window) {
    const sessions = this.waitSessionsByWindow.get(window);
    if (!sessions) return;
    for (const session of sessions) {
      this.killProcess(session.pid);
    }
    this.waitSessionsByWindow.delete(window);
  }

  windowDidClosePathWithWaitSession(window, initialPath) {
    const waitSessions = this.waitSessionsByWindow.get(window);
    if (!waitSessions) return;
    for (let i = waitSessions.length - 1; i >= 0; i--) {
      const session = waitSessions[i];
      session.remainingPaths.delete(initialPath);
      if (session.remainingPaths.size === 0) {
        this.killProcess(session.pid);
        waitSessions.splice(i, 1);
      }
    }
  }

  // Kill the process with the given pid.
  killProcess(pid) {
    try {
      const parsedPid = parseInt(pid);
      if (isFinite(parsedPid)) this._killProcess(parsedPid);
    } catch (error) {
      if (error.code !== 'ESRCH') {
        console.log(
          `Killing process ${pid} failed: ${
            error.code != null ? error.code : error.message
          }`
        );
      }
    }
  }

  async saveCurrentWindowOptions(allowEmpty = false) {
    if (this.quitting) return;

    const windows = this.getAllWindows();
    const hasASpecWindow = windows.some(window => window.isSpec);

    if (windows.length === 1 && hasASpecWindow) return;

    const state = {
      version: APPLICATION_STATE_VERSION,
      windows: windows
        .filter(window => !window.isSpec)
        .map(window => ({ projectRoots: window.projectRoots }))
    };
    state.windows.reverse();

    if (state.windows.length > 0 || allowEmpty) {
      await this.storageFolder.store('application.json', state);
      this.emit('application:did-save-state');
    }
  }

  async loadPreviousWindowOptions() {
    const state = await this.storageFolder.load('application.json');
    if (!state) {
      return [];
    }

    if (state.version === APPLICATION_STATE_VERSION) {
      // Atom >=1.36.1
      // Schema: {version: '1', windows: [{projectRoots: ['<root-dir>', ...]}, ...]}
      return state.windows.map(each => ({
        foldersToOpen: each.projectRoots,
        devMode: this.devMode,
        safeMode: this.safeMode,
        newWindow: true
      }));
    } else if (state.version === undefined) {
      // Atom <= 1.36.0
      // Schema: [{initialPaths: ['<root-dir>', ...]}, ...]
      return Promise.all(
        state.map(async windowState => {
          // Classify each window's initialPaths as directories or non-directories
          const classifiedPaths = await Promise.all(
            windowState.initialPaths.map(
              initialPath =>
                new Promise(resolve => {
                  fs.isDirectory(initialPath, isDir =>
                    resolve({ initialPath, isDir })
                  );
                })
            )
          );

          // Only accept initialPaths that are existing directories
          return {
            foldersToOpen: classifiedPaths
              .filter(({ isDir }) => isDir)
              .map(({ initialPath }) => initialPath),
            devMode: this.devMode,
            safeMode: this.safeMode,
            newWindow: true
          };
        })
      );
    } else {
      // Unrecognized version (from a newer Atom?)
      return [];
    }
  }

  // Open an atom:// url.
  //
  // The host of the URL being opened is assumed to be the package name
  // responsible for opening the URL.  A new window will be created with
  // that package's `urlMain` as the bootstrap script.
  //
  // options -
  //   :urlToOpen - The atom:// url to open.
  //   :devMode - Boolean to control the opened window's dev mode.
  //   :safeMode - Boolean to control the opened window's safe mode.
  openUrl({ urlToOpen, devMode, safeMode, env }) {
    const parsedUrl = url.parse(urlToOpen, true);
    if (parsedUrl.protocol !== 'atom:') return;

    const pack = this.findPackageWithName(parsedUrl.host, devMode);
    if (pack && pack.urlMain) {
      return this.openPackageUrlMain(
        parsedUrl.host,
        pack.urlMain,
        urlToOpen,
        devMode,
        safeMode,
        env
      );
    } else {
      return this.openPackageUriHandler(
        urlToOpen,
        parsedUrl,
        devMode,
        safeMode,
        env
      );
    }
  }

  openPackageUriHandler(url, parsedUrl, devMode, safeMode, env) {
    let bestWindow;

    if (parsedUrl.host === 'core') {
      const predicate = require('../core-uri-handlers').windowPredicate(
        parsedUrl
      );
      bestWindow = this.getLastFocusedWindow(
        win => !win.isSpecWindow() && predicate(win)
      );
    }

    if (!bestWindow)
      bestWindow = this.getLastFocusedWindow(win => !win.isSpecWindow());

    if (bestWindow) {
      bestWindow.sendURIMessage(url);
      bestWindow.focus();
      return bestWindow;
    } else {
      let windowInitializationScript;
      let { resourcePath } = this;
      if (devMode) {
        try {
          windowInitializationScript = require.resolve(
            path.join(
              this.devResourcePath,
              'src',
              'initialize-application-window'
            )
          );
          resourcePath = this.devResourcePath;
        } catch (error) {}
      }

      if (!windowInitializationScript) {
        windowInitializationScript = require.resolve(
          '../initialize-application-window'
        );
      }

      const windowDimensions = this.getDimensionsForNewWindow();
      const window = this.createWindow({
        resourcePath,
        windowInitializationScript,
        devMode,
        safeMode,
        windowDimensions,
        env
      });
      this.addWindow(window);
      window.on('window:loaded', () => window.sendURIMessage(url));
      return window;
    }
  }

  findPackageWithName(packageName, devMode) {
    return this.getPackageManager(devMode)
      .getAvailablePackageMetadata()
      .find(({ name }) => name === packageName);
  }

  openPackageUrlMain(
    packageName,
    packageUrlMain,
    urlToOpen,
    devMode,
    safeMode,
    env
  ) {
    const packagePath = this.getPackageManager(devMode).resolvePackagePath(
      packageName
    );
    const windowInitializationScript = path.resolve(
      packagePath,
      packageUrlMain
    );
    const windowDimensions = this.getDimensionsForNewWindow();
    const window = this.createWindow({
      windowInitializationScript,
      resourcePath: this.resourcePath,
      devMode,
      safeMode,
      urlToOpen,
      windowDimensions,
      env
    });
    this.addWindow(window);
    return window;
  }

  getPackageManager(devMode) {
    if (this.packages == null) {
      const PackageManager = require('../package-manager');
      this.packages = new PackageManager({});
      this.packages.initialize({
        configDirPath: process.env.ATOM_HOME,
        devMode,
        resourcePath: this.resourcePath
      });
    }

    return this.packages;
  }

  // Opens up a new {AtomWindow} to run specs within.
  //
  // options -
  //   :headless - A Boolean that, if true, will close the window upon
  //                   completion.
  //   :resourcePath - The path to include specs from.
  //   :specPath - The directory to load specs from.
  //   :safeMode - A Boolean that, if true, won't run specs from ~/.atom/packages
  //               and ~/.atom/dev/packages, defaults to false.
  runTests({
    headless,
    resourcePath,
    executedFrom,
    pathsToOpen,
    logFile,
    safeMode,
    timeout,
    env
  }) {
    let windowInitializationScript;
    if (resourcePath !== this.resourcePath && !fs.existsSync(resourcePath)) {
      ({ resourcePath } = this);
    }

    const timeoutInSeconds = Number.parseFloat(timeout);
    if (!Number.isNaN(timeoutInSeconds)) {
      const timeoutHandler = function() {
        console.log(
          `The test suite has timed out because it has been running for more than ${timeoutInSeconds} seconds.`
        );
        return process.exit(124); // Use the same exit code as the UNIX timeout util.
      };
      setTimeout(timeoutHandler, timeoutInSeconds * 1000);
    }

    try {
      windowInitializationScript = require.resolve(
        path.resolve(this.devResourcePath, 'src', 'initialize-test-window')
      );
    } catch (error) {
      windowInitializationScript = require.resolve(
        path.resolve(__dirname, '..', '..', 'src', 'initialize-test-window')
      );
    }

    const testPaths = [];
    if (pathsToOpen != null) {
      for (let pathToOpen of pathsToOpen) {
        testPaths.push(path.resolve(executedFrom, fs.normalize(pathToOpen)));
      }
    }

    if (testPaths.length === 0) {
      process.stderr.write('Error: Specify at least one test path\n\n');
      process.exit(1);
    }

    const legacyTestRunnerPath = this.resolveLegacyTestRunnerPath();
    const testRunnerPath = this.resolveTestRunnerPath(testPaths[0]);
    const devMode = true;
    const isSpec = true;
    if (safeMode == null) {
      safeMode = false;
    }
    const window = this.createWindow({
      windowInitializationScript,
      resourcePath,
      headless,
      isSpec,
      devMode,
      testRunnerPath,
      legacyTestRunnerPath,
      testPaths,
      logFile,
      safeMode,
      env
    });
    this.addWindow(window);
    if (env) window.replaceEnvironment(env);
    return window;
  }

  runBenchmarks({
    headless,
    test,
    resourcePath,
    executedFrom,
    pathsToOpen,
    env
  }) {
    let windowInitializationScript;
    if (resourcePath !== this.resourcePath && !fs.existsSync(resourcePath)) {
      ({ resourcePath } = this);
    }

    try {
      windowInitializationScript = require.resolve(
        path.resolve(this.devResourcePath, 'src', 'initialize-benchmark-window')
      );
    } catch (error) {
      windowInitializationScript = require.resolve(
        path.resolve(
          __dirname,
          '..',
          '..',
          'src',
          'initialize-benchmark-window'
        )
      );
    }

    const benchmarkPaths = [];
    if (pathsToOpen != null) {
      for (let pathToOpen of pathsToOpen) {
        benchmarkPaths.push(
          path.resolve(executedFrom, fs.normalize(pathToOpen))
        );
      }
    }

    if (benchmarkPaths.length === 0) {
      process.stderr.write('Error: Specify at least one benchmark path.\n\n');
      process.exit(1);
    }

    const devMode = true;
    const isSpec = true;
    const safeMode = false;
    const window = this.createWindow({
      windowInitializationScript,
      resourcePath,
      headless,
      test,
      isSpec,
      devMode,
      benchmarkPaths,
      safeMode,
      env
    });
    this.addWindow(window);
    return window;
  }

  resolveTestRunnerPath(testPath) {
    let packageRoot;
    if (FindParentDir == null) {
      FindParentDir = require('find-parent-dir');
    }

    if ((packageRoot = FindParentDir.sync(testPath, 'package.json'))) {
      const packageMetadata = require(path.join(packageRoot, 'package.json'));
      if (packageMetadata.atomTestRunner) {
        let testRunnerPath;
        if (Resolve == null) {
          Resolve = require('resolve');
        }
        if (
          (testRunnerPath = Resolve.sync(packageMetadata.atomTestRunner, {
            basedir: packageRoot,
            extensions: Object.keys(require.extensions)
          }))
        ) {
          return testRunnerPath;
        } else {
          process.stderr.write(
            `Error: Could not resolve test runner path '${
              packageMetadata.atomTestRunner
            }'`
          );
          process.exit(1);
        }
      }
    }

    return this.resolveLegacyTestRunnerPath();
  }

  resolveLegacyTestRunnerPath() {
    try {
      return require.resolve(
        path.resolve(this.devResourcePath, 'spec', 'jasmine-test-runner')
      );
    } catch (error) {
      return require.resolve(
        path.resolve(__dirname, '..', '..', 'spec', 'jasmine-test-runner')
      );
    }
  }

  async parsePathToOpen(pathToOpen, executedFrom, extra) {
    const result = Object.assign(
      {
        pathToOpen,
        initialColumn: null,
        initialLine: null,
        exists: false,
        isDirectory: false,
        isFile: false
      },
      extra
    );

    if (!pathToOpen) {
      return result;
    }

    result.pathToOpen = result.pathToOpen.replace(/[:\s]+$/, '');
    const match = result.pathToOpen.match(LocationSuffixRegExp);

    if (match != null) {
      result.pathToOpen = result.pathToOpen.slice(0, -match[0].length);
      if (match[1]) {
        result.initialLine = Math.max(0, parseInt(match[1].slice(1), 10) - 1);
      }
      if (match[2]) {
        result.initialColumn = Math.max(0, parseInt(match[2].slice(1), 10) - 1);
      }
    }

    const normalizedPath = path.normalize(
      path.resolve(executedFrom, fs.normalize(result.pathToOpen))
    );
    if (!url.parse(pathToOpen).protocol) {
      result.pathToOpen = normalizedPath;
    }

    await new Promise((resolve, reject) => {
      fs.stat(result.pathToOpen, (err, st) => {
        if (err) {
          if (err.code === 'ENOENT' || err.code === 'EACCES') {
            result.exists = false;
            resolve();
          } else {
            reject(err);
          }
          return;
        }

        result.exists = true;
        result.isFile = st.isFile();
        result.isDirectory = st.isDirectory();
        resolve();
      });
    });

    return result;
  }

  // Opens a native dialog to prompt the user for a path.
  //
  // Once paths are selected, they're opened in a new or existing {AtomWindow}s.
  //
  // options -
  //   :type - A String which specifies the type of the dialog, could be 'file',
  //           'folder' or 'all'. The 'all' is only available on macOS.
  //   :devMode - A Boolean which controls whether any newly opened windows
  //              should be in dev mode or not.
  //   :safeMode - A Boolean which controls whether any newly opened windows
  //               should be in safe mode or not.
  //   :window - An {AtomWindow} to use for opening selected file paths as long as
  //             all are files.
  //   :path - An optional String which controls the default path to which the
  //           file dialog opens.
  promptForPathToOpen(type, { devMode, safeMode, window }, path = null) {
    return this.promptForPath(
      type,
      async pathsToOpen => {
        let targetWindow;

        // Open in :window as long as no chosen paths are folders. If any chosen path is a folder, open in a
        // new window instead.
        if (type === 'folder') {
          targetWindow = null;
        } else if (type === 'file') {
          targetWindow = window;
        } else if (type === 'all') {
          const areDirectories = await Promise.all(
            pathsToOpen.map(
              pathToOpen =>
                new Promise(resolve => fs.isDirectory(pathToOpen, resolve))
            )
          );
          if (!areDirectories.some(Boolean)) {
            targetWindow = window;
          }
        }

        return this.openPaths({
          pathsToOpen,
          devMode,
          safeMode,
          window: targetWindow
        });
      },
      path
    );
  }

  promptForPath(type, callback, path) {
    const properties = (() => {
      switch (type) {
        case 'file':
          return ['openFile'];
        case 'folder':
          return ['openDirectory'];
        case 'all':
          return ['openFile', 'openDirectory'];
        default:
          throw new Error(`${type} is an invalid type for promptForPath`);
      }
    })();

    // Show the open dialog as child window on Windows and Linux, and as an independent dialog on macOS. This matches
    // most native apps.
    const parentWindow =
      process.platform === 'darwin' ? null : BrowserWindow.getFocusedWindow();

    const openOptions = {
      properties: properties.concat(['multiSelections', 'createDirectory']),
      title: (() => {
        switch (type) {
          case 'file':
            return 'Open File';
          case 'folder':
            return 'Open Folder';
          default:
            return 'Open';
        }
      })()
    };

    // File dialog defaults to project directory of currently active editor
    if (path) openOptions.defaultPath = path;
    dialog
      .showOpenDialog(parentWindow, openOptions)
      .then(({ filePaths, bookmarks }) => {
        if (typeof callback === 'function') {
          callback(filePaths, bookmarks);
        }
      });
  }

  async promptForRestart() {
    const result = await dialog.showMessageBox(
      BrowserWindow.getFocusedWindow(),
      {
        type: 'warning',
        title: 'Restart required',
        message:
          'You will need to restart Atom for this change to take effect.',
        buttons: ['Restart Atom', 'Cancel']
      }
    );
    if (result.response === 0) this.restart();
  }

  restart() {
    const args = [];
    if (this.safeMode) args.push('--safe');
    if (this.logFile != null) args.push(`--log-file=${this.logFile}`);
    if (this.userDataDir != null)
      args.push(`--user-data-dir=${this.userDataDir}`);
    if (this.devMode) {
      args.push('--dev');
      args.push(`--resource-path=${this.resourcePath}`);
    }
    app.relaunch({ args });
    app.quit();
  }

  disableZoomOnDisplayChange() {
    const callback = () => {
      this.getAllWindows().map(window => window.disableZoom());
    };

    // Set the limits every time a display is added or removed, otherwise the
    // configuration gets reset to the default, which allows zooming the
    // webframe.
    screen.on('display-added', callback);
    screen.on('display-removed', callback);
    return new Disposable(() => {
      screen.removeListener('display-added', callback);
      screen.removeListener('display-removed', callback);
    });
  }
};

class WindowStack {
  constructor(windows = []) {
    this.addWindow = this.addWindow.bind(this);
    this.touch = this.touch.bind(this);
    this.removeWindow = this.removeWindow.bind(this);
    this.getLastFocusedWindow = this.getLastFocusedWindow.bind(this);
    this.all = this.all.bind(this);
    this.windows = windows;
  }

  addWindow(window) {
    this.removeWindow(window);
    return this.windows.unshift(window);
  }

  touch(window) {
    return this.addWindow(window);
  }

  removeWindow(window) {
    const currentIndex = this.windows.indexOf(window);
    if (currentIndex > -1) {
      return this.windows.splice(currentIndex, 1);
    }
  }

  getLastFocusedWindow(predicate) {
    if (predicate == null) {
      predicate = win => true;
    }
    return this.windows.find(predicate);
  }

  all() {
    return this.windows;
  }
}
