const path = require('path');
const asyncEach = require('async/each');
const CSON = require('season');
const fs = require('fs-plus');
const { Emitter, CompositeDisposable } = require('event-kit');
const dedent = require('dedent');

const CompileCache = require('./compile-cache');
const ModuleCache = require('./module-cache');
const BufferedProcess = require('./buffered-process');
const { requireModule } = require('./module-utils');

// Extended: Loads and activates a package's main module and resources such as
// stylesheets, keymaps, grammar, editor properties, and menus.
module.exports = class Package {
  /*
  Section: Construction
  */

  constructor(params) {
    this.config = params.config;
    this.packageManager = params.packageManager;
    this.styleManager = params.styleManager;
    this.commandRegistry = params.commandRegistry;
    this.keymapManager = params.keymapManager;
    this.notificationManager = params.notificationManager;
    this.grammarRegistry = params.grammarRegistry;
    this.themeManager = params.themeManager;
    this.menuManager = params.menuManager;
    this.contextMenuManager = params.contextMenuManager;
    this.deserializerManager = params.deserializerManager;
    this.viewRegistry = params.viewRegistry;
    this.emitter = new Emitter();

    this.mainModule = null;
    this.path = params.path;
    this.preloadedPackage = params.preloadedPackage;
    this.metadata =
      params.metadata || this.packageManager.loadPackageMetadata(this.path);
    this.bundledPackage =
      params.bundledPackage != null
        ? params.bundledPackage
        : this.packageManager.isBundledPackagePath(this.path);
    this.name =
      (this.metadata && this.metadata.name) ||
      params.name ||
      path.basename(this.path);
    this.reset();
  }

  /*
  Section: Event Subscription
  */

  // Essential: Invoke the given callback when all packages have been activated.
  //
  // * `callback` {Function}
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDeactivate(callback) {
    return this.emitter.on('did-deactivate', callback);
  }

  /*
  Section: Instance Methods
  */

  enable() {
    return this.config.removeAtKeyPath('core.disabledPackages', this.name);
  }

  disable() {
    return this.config.pushAtKeyPath('core.disabledPackages', this.name);
  }

  isTheme() {
    return this.metadata && this.metadata.theme;
  }

  measure(key, fn) {
    const startTime = window.performance.now();
    const value = fn();
    this[key] = Math.round(window.performance.now() - startTime);
    return value;
  }

  getType() {
    return 'atom';
  }

  getStyleSheetPriority() {
    return 0;
  }

  preload() {
    this.loadKeymaps();
    this.loadMenus();
    this.registerDeserializerMethods();
    this.activateCoreStartupServices();
    this.registerURIHandler();
    this.configSchemaRegisteredOnLoad = this.registerConfigSchemaFromMetadata();
    this.requireMainModule();
    this.settingsPromise = this.loadSettings();

    this.activationDisposables = new CompositeDisposable();
    this.activateKeymaps();
    this.activateMenus();
    for (let settings of this.settings) {
      settings.activate(this.config);
    }
    this.settingsActivated = true;
  }

  finishLoading() {
    this.measure('loadTime', () => {
      this.path = path.join(this.packageManager.resourcePath, this.path);
      ModuleCache.add(this.path, this.metadata);

      this.loadStylesheets();
      // Unfortunately some packages are accessing `@mainModulePath`, so we need
      // to compute that variable eagerly also for preloaded packages.
      this.getMainModulePath();
    });
  }

  load() {
    this.measure('loadTime', () => {
      try {
        ModuleCache.add(this.path, this.metadata);

        this.loadKeymaps();
        this.loadMenus();
        this.loadStylesheets();
        this.registerDeserializerMethods();
        this.activateCoreStartupServices();
        this.registerURIHandler();
        this.registerTranspilerConfig();
        this.configSchemaRegisteredOnLoad = this.registerConfigSchemaFromMetadata();
        this.settingsPromise = this.loadSettings();
        if (this.shouldRequireMainModuleOnLoad() && this.mainModule == null) {
          this.requireMainModule();
        }
      } catch (error) {
        this.handleError(`Failed to load the ${this.name} package`, error);
      }
    });
    return this;
  }

  unload() {
    this.unregisterTranspilerConfig();
  }

  shouldRequireMainModuleOnLoad() {
    return !(
      this.metadata.deserializers ||
      this.metadata.viewProviders ||
      this.metadata.configSchema ||
      this.activationShouldBeDeferred() ||
      localStorage.getItem(this.getCanDeferMainModuleRequireStorageKey()) ===
        'true'
    );
  }

  reset() {
    this.stylesheets = [];
    this.keymaps = [];
    this.menus = [];
    this.grammars = [];
    this.settings = [];
    this.mainInitialized = false;
    this.mainActivated = false;
    this.deserialized = false;
  }

  initializeIfNeeded() {
    if (this.mainInitialized) return;
    this.measure('initializeTime', () => {
      try {
        // The main module's `initialize()` method is guaranteed to be called
        // before its `activate()`. This gives you a chance to handle the
        // serialized package state before the package's derserializers and view
        // providers are used.
        if (!this.mainModule) this.requireMainModule();
        if (typeof this.mainModule.initialize === 'function') {
          this.mainModule.initialize(
            this.packageManager.getPackageState(this.name) || {}
          );
        }
        this.mainInitialized = true;
      } catch (error) {
        this.handleError(
          `Failed to initialize the ${this.name} package`,
          error
        );
      }
    });
  }

  activate() {
    if (!this.grammarsPromise) this.grammarsPromise = this.loadGrammars();
    if (!this.activationPromise) {
      this.activationPromise = new Promise((resolve, reject) => {
        this.resolveActivationPromise = resolve;
        this.measure('activateTime', () => {
          try {
            this.activateResources();
            if (this.activationShouldBeDeferred()) {
              return this.subscribeToDeferredActivation();
            } else {
              return this.activateNow();
            }
          } catch (error) {
            return this.handleError(
              `Failed to activate the ${this.name} package`,
              error
            );
          }
        });
      });
    }

    return Promise.all([
      this.grammarsPromise,
      this.settingsPromise,
      this.activationPromise
    ]);
  }

  activateNow() {
    try {
      if (!this.mainModule) this.requireMainModule();
      this.configSchemaRegisteredOnActivate = this.registerConfigSchemaFromMainModule();
      this.registerViewProviders();
      this.activateStylesheets();
      if (this.mainModule && !this.mainActivated) {
        this.initializeIfNeeded();
        if (typeof this.mainModule.activateConfig === 'function') {
          this.mainModule.activateConfig();
        }
        if (typeof this.mainModule.activate === 'function') {
          this.mainModule.activate(
            this.packageManager.getPackageState(this.name) || {}
          );
        }
        this.mainActivated = true;
        this.activateServices();
      }
      if (this.activationCommandSubscriptions)
        this.activationCommandSubscriptions.dispose();
      if (this.activationHookSubscriptions)
        this.activationHookSubscriptions.dispose();
      if (this.workspaceOpenerSubscriptions)
        this.workspaceOpenerSubscriptions.dispose();
    } catch (error) {
      this.handleError(`Failed to activate the ${this.name} package`, error);
    }

    if (typeof this.resolveActivationPromise === 'function')
      this.resolveActivationPromise();
  }

  registerConfigSchemaFromMetadata() {
    const configSchema = this.metadata.configSchema;
    if (configSchema) {
      this.config.setSchema(this.name, {
        type: 'object',
        properties: configSchema
      });
      return true;
    } else {
      return false;
    }
  }

  registerConfigSchemaFromMainModule() {
    if (this.mainModule && !this.configSchemaRegisteredOnLoad) {
      if (typeof this.mainModule.config === 'object') {
        this.config.setSchema(this.name, {
          type: 'object',
          properties: this.mainModule.config
        });
        return true;
      }
    }
    return false;
  }

  // TODO: Remove. Settings view calls this method currently.
  activateConfig() {
    if (this.configSchemaRegisteredOnLoad) return;
    this.requireMainModule();
    this.registerConfigSchemaFromMainModule();
  }

  activateStylesheets() {
    if (this.stylesheetsActivated) return;

    this.stylesheetDisposables = new CompositeDisposable();

    const priority = this.getStyleSheetPriority();
    for (let [sourcePath, source] of this.stylesheets) {
      const match = path.basename(sourcePath).match(/[^.]*\.([^.]*)\./);

      let context;
      if (match) {
        context = match[1];
      } else if (this.metadata.theme === 'syntax') {
        context = 'atom-text-editor';
      }

      this.stylesheetDisposables.add(
        this.styleManager.addStyleSheet(source, {
          sourcePath,
          priority,
          context,
          skipDeprecatedSelectorsTransformation: this.bundledPackage
        })
      );
    }

    this.stylesheetsActivated = true;
  }

  activateResources() {
    if (!this.activationDisposables)
      this.activationDisposables = new CompositeDisposable();

    const packagesWithKeymapsDisabled = this.config.get(
      'core.packagesWithKeymapsDisabled'
    );
    if (
      packagesWithKeymapsDisabled &&
      packagesWithKeymapsDisabled.includes(this.name)
    ) {
      this.deactivateKeymaps();
    } else if (!this.keymapActivated) {
      this.activateKeymaps();
    }

    if (!this.menusActivated) {
      this.activateMenus();
    }

    if (!this.grammarsActivated) {
      for (let grammar of this.grammars) {
        grammar.activate();
      }
      this.grammarsActivated = true;
    }

    if (!this.settingsActivated) {
      for (let settings of this.settings) {
        settings.activate(this.config);
      }
      this.settingsActivated = true;
    }
  }

  activateKeymaps() {
    if (this.keymapActivated) return;

    this.keymapDisposables = new CompositeDisposable();

    const validateSelectors = !this.preloadedPackage;
    for (let [keymapPath, map] of this.keymaps) {
      this.keymapDisposables.add(
        this.keymapManager.add(keymapPath, map, 0, validateSelectors)
      );
    }
    this.menuManager.update();

    this.keymapActivated = true;
  }

  deactivateKeymaps() {
    if (!this.keymapActivated) return;
    if (this.keymapDisposables) {
      this.keymapDisposables.dispose();
    }
    this.menuManager.update();
    this.keymapActivated = false;
  }

  hasKeymaps() {
    for (let [, map] of this.keymaps) {
      if (map.length > 0) return true;
    }
    return false;
  }

  activateMenus() {
    const validateSelectors = !this.preloadedPackage;
    for (const [menuPath, map] of this.menus) {
      if (map['context-menu']) {
        try {
          const itemsBySelector = map['context-menu'];
          this.activationDisposables.add(
            this.contextMenuManager.add(itemsBySelector, validateSelectors)
          );
        } catch (error) {
          if (error.code === 'EBADSELECTOR') {
            error.message += ` in ${menuPath}`;
            error.stack += `\n  at ${menuPath}:1:1`;
          }
          throw error;
        }
      }
    }

    for (const [, map] of this.menus) {
      if (map.menu)
        this.activationDisposables.add(this.menuManager.add(map.menu));
    }

    this.menusActivated = true;
  }

  activateServices() {
    let methodName, version, versions;
    for (var name in this.metadata.providedServices) {
      ({ versions } = this.metadata.providedServices[name]);
      const servicesByVersion = {};
      for (version in versions) {
        methodName = versions[version];
        if (typeof this.mainModule[methodName] === 'function') {
          servicesByVersion[version] = this.mainModule[methodName]();
        }
      }
      this.activationDisposables.add(
        this.packageManager.serviceHub.provide(name, servicesByVersion)
      );
    }

    for (name in this.metadata.consumedServices) {
      ({ versions } = this.metadata.consumedServices[name]);
      for (version in versions) {
        methodName = versions[version];
        if (typeof this.mainModule[methodName] === 'function') {
          this.activationDisposables.add(
            this.packageManager.serviceHub.consume(
              name,
              version,
              this.mainModule[methodName].bind(this.mainModule)
            )
          );
        }
      }
    }
  }

  registerURIHandler() {
    const handlerConfig = this.getURIHandler();
    const methodName = handlerConfig && handlerConfig.method;
    if (methodName) {
      this.uriHandlerSubscription = this.packageManager.registerURIHandlerForPackage(
        this.name,
        (...args) => this.handleURI(methodName, args)
      );
    }
  }

  unregisterURIHandler() {
    if (this.uriHandlerSubscription) this.uriHandlerSubscription.dispose();
  }

  handleURI(methodName, args) {
    this.activate().then(() => {
      if (this.mainModule[methodName])
        this.mainModule[methodName].apply(this.mainModule, args);
    });
    if (!this.mainActivated) this.activateNow();
  }

  registerTranspilerConfig() {
    if (this.metadata.atomTranspilers) {
      CompileCache.addTranspilerConfigForPath(
        this.path,
        this.name,
        this.metadata,
        this.metadata.atomTranspilers
      );
    }
  }

  unregisterTranspilerConfig() {
    if (this.metadata.atomTranspilers) {
      CompileCache.removeTranspilerConfigForPath(this.path);
    }
  }

  loadKeymaps() {
    if (this.bundledPackage && this.packageManager.packagesCache[this.name]) {
      this.keymaps = [];
      for (const keymapPath in this.packageManager.packagesCache[this.name]
        .keymaps) {
        const keymapObject = this.packageManager.packagesCache[this.name]
          .keymaps[keymapPath];
        this.keymaps.push([`core:${keymapPath}`, keymapObject]);
      }
    } else {
      this.keymaps = this.getKeymapPaths().map(keymapPath => [
        keymapPath,
        CSON.readFileSync(keymapPath, { allowDuplicateKeys: false }) || {}
      ]);
    }
  }

  loadMenus() {
    if (this.bundledPackage && this.packageManager.packagesCache[this.name]) {
      this.menus = [];
      for (const menuPath in this.packageManager.packagesCache[this.name]
        .menus) {
        const menuObject = this.packageManager.packagesCache[this.name].menus[
          menuPath
        ];
        this.menus.push([`core:${menuPath}`, menuObject]);
      }
    } else {
      this.menus = this.getMenuPaths().map(menuPath => [
        menuPath,
        CSON.readFileSync(menuPath) || {}
      ]);
    }
  }

  getKeymapPaths() {
    const keymapsDirPath = path.join(this.path, 'keymaps');
    if (this.metadata.keymaps) {
      return this.metadata.keymaps.map(name =>
        fs.resolve(keymapsDirPath, name, ['json', 'cson', ''])
      );
    } else {
      return fs.listSync(keymapsDirPath, ['cson', 'json']);
    }
  }

  getMenuPaths() {
    const menusDirPath = path.join(this.path, 'menus');
    if (this.metadata.menus) {
      return this.metadata.menus.map(name =>
        fs.resolve(menusDirPath, name, ['json', 'cson', ''])
      );
    } else {
      return fs.listSync(menusDirPath, ['cson', 'json']);
    }
  }

  loadStylesheets() {
    this.stylesheets = this.getStylesheetPaths().map(stylesheetPath => [
      stylesheetPath,
      this.themeManager.loadStylesheet(stylesheetPath, true)
    ]);
  }

  registerDeserializerMethods() {
    if (this.metadata.deserializers) {
      Object.keys(this.metadata.deserializers).forEach(deserializerName => {
        const methodName = this.metadata.deserializers[deserializerName];
        this.deserializerManager.add({
          name: deserializerName,
          deserialize: (state, atomEnvironment) => {
            this.registerViewProviders();
            this.requireMainModule();
            this.initializeIfNeeded();
            if (atomEnvironment.packages.hasActivatedInitialPackages()) {
              // Only explicitly activate the package if initial packages
              // have finished activating. This is because deserialization
              // generally occurs at Atom startup, which happens before the
              // workspace element is added to the DOM and is inconsistent with
              // with when initial package activation occurs. Triggering activation
              // immediately may cause problems with packages that expect to
              // always have access to the workspace element.
              // Otherwise, we just set the deserialized flag and package-manager
              // will activate this package as normal during initial package activation.
              this.activateNow();
            }
            this.deserialized = true;
            return this.mainModule[methodName](state, atomEnvironment);
          }
        });
      });
    }
  }

  activateCoreStartupServices() {
    const directoryProviderService =
      this.metadata.providedServices &&
      this.metadata.providedServices['atom.directory-provider'];
    if (directoryProviderService) {
      this.requireMainModule();
      const servicesByVersion = {};
      for (let version in directoryProviderService.versions) {
        const methodName = directoryProviderService.versions[version];
        if (typeof this.mainModule[methodName] === 'function') {
          servicesByVersion[version] = this.mainModule[methodName]();
        }
      }
      this.packageManager.serviceHub.provide(
        'atom.directory-provider',
        servicesByVersion
      );
    }
  }

  registerViewProviders() {
    if (this.metadata.viewProviders && !this.registeredViewProviders) {
      this.requireMainModule();
      this.metadata.viewProviders.forEach(methodName => {
        this.viewRegistry.addViewProvider(model => {
          this.initializeIfNeeded();
          return this.mainModule[methodName](model);
        });
      });
      this.registeredViewProviders = true;
    }
  }

  getStylesheetsPath() {
    return path.join(this.path, 'styles');
  }

  getStylesheetPaths() {
    if (
      this.bundledPackage &&
      this.packageManager.packagesCache[this.name] &&
      this.packageManager.packagesCache[this.name].styleSheetPaths
    ) {
      const { styleSheetPaths } = this.packageManager.packagesCache[this.name];
      return styleSheetPaths.map(styleSheetPath =>
        path.join(this.path, styleSheetPath)
      );
    } else {
      let indexStylesheet;
      const stylesheetDirPath = this.getStylesheetsPath();
      if (this.metadata.mainStyleSheet) {
        return [fs.resolve(this.path, this.metadata.mainStyleSheet)];
      } else if (this.metadata.styleSheets) {
        return this.metadata.styleSheets.map(name =>
          fs.resolve(stylesheetDirPath, name, ['css', 'less', ''])
        );
      } else if (
        (indexStylesheet = fs.resolve(this.path, 'index', ['css', 'less']))
      ) {
        return [indexStylesheet];
      } else {
        return fs.listSync(stylesheetDirPath, ['css', 'less']);
      }
    }
  }

  loadGrammarsSync() {
    if (this.grammarsLoaded) return;

    let grammarPaths;
    if (this.preloadedPackage && this.packageManager.packagesCache[this.name]) {
      ({ grammarPaths } = this.packageManager.packagesCache[this.name]);
    } else {
      grammarPaths = fs.listSync(path.join(this.path, 'grammars'), [
        'json',
        'cson'
      ]);
    }

    for (let grammarPath of grammarPaths) {
      if (
        this.preloadedPackage &&
        this.packageManager.packagesCache[this.name]
      ) {
        grammarPath = path.resolve(
          this.packageManager.resourcePath,
          grammarPath
        );
      }

      try {
        const grammar = this.grammarRegistry.readGrammarSync(grammarPath);
        grammar.packageName = this.name;
        grammar.bundledPackage = this.bundledPackage;
        this.grammars.push(grammar);
        grammar.activate();
      } catch (error) {
        console.warn(
          `Failed to load grammar: ${grammarPath}`,
          error.stack || error
        );
      }
    }

    this.grammarsLoaded = true;
    this.grammarsActivated = true;
  }

  loadGrammars() {
    if (this.grammarsLoaded) return Promise.resolve();

    const loadGrammar = (grammarPath, callback) => {
      if (this.preloadedPackage) {
        grammarPath = path.resolve(
          this.packageManager.resourcePath,
          grammarPath
        );
      }

      return this.grammarRegistry.readGrammar(grammarPath, (error, grammar) => {
        if (error) {
          const detail = `${error.message} in ${grammarPath}`;
          const stack = `${error.stack}\n  at ${grammarPath}:1:1`;
          this.notificationManager.addFatalError(
            `Failed to load a ${this.name} package grammar`,
            { stack, detail, packageName: this.name, dismissable: true }
          );
        } else {
          grammar.packageName = this.name;
          grammar.bundledPackage = this.bundledPackage;
          this.grammars.push(grammar);
          if (this.grammarsActivated) grammar.activate();
        }
        return callback();
      });
    };

    return new Promise(resolve => {
      if (
        this.preloadedPackage &&
        this.packageManager.packagesCache[this.name]
      ) {
        const { grammarPaths } = this.packageManager.packagesCache[this.name];
        return asyncEach(grammarPaths, loadGrammar, () => resolve());
      } else {
        const grammarsDirPath = path.join(this.path, 'grammars');
        fs.exists(grammarsDirPath, grammarsDirExists => {
          if (!grammarsDirExists) return resolve();
          fs.list(grammarsDirPath, ['json', 'cson'], (error, grammarPaths) => {
            if (error || !grammarPaths) return resolve();
            asyncEach(grammarPaths, loadGrammar, () => resolve());
          });
        });
      }
    });
  }

  loadSettings() {
    this.settings = [];

    const loadSettingsFile = (settingsPath, callback) => {
      return SettingsFile.load(settingsPath, (error, settingsFile) => {
        if (error) {
          const detail = `${error.message} in ${settingsPath}`;
          const stack = `${error.stack}\n  at ${settingsPath}:1:1`;
          this.notificationManager.addFatalError(
            `Failed to load the ${this.name} package settings`,
            { stack, detail, packageName: this.name, dismissable: true }
          );
        } else {
          this.settings.push(settingsFile);
          if (this.settingsActivated) settingsFile.activate(this.config);
        }
        return callback();
      });
    };

    if (this.preloadedPackage && this.packageManager.packagesCache[this.name]) {
      for (let settingsPath in this.packageManager.packagesCache[this.name]
        .settings) {
        const properties = this.packageManager.packagesCache[this.name]
          .settings[settingsPath];
        const settingsFile = new SettingsFile(
          `core:${settingsPath}`,
          properties || {}
        );
        this.settings.push(settingsFile);
        if (this.settingsActivated) settingsFile.activate(this.config);
      }
    } else {
      return new Promise(resolve => {
        const settingsDirPath = path.join(this.path, 'settings');
        fs.exists(settingsDirPath, settingsDirExists => {
          if (!settingsDirExists) return resolve();
          fs.list(settingsDirPath, ['json', 'cson'], (error, settingsPaths) => {
            if (error || !settingsPaths) return resolve();
            asyncEach(settingsPaths, loadSettingsFile, () => resolve());
          });
        });
      });
    }
  }

  serialize() {
    if (this.mainActivated) {
      if (typeof this.mainModule.serialize === 'function') {
        try {
          return this.mainModule.serialize();
        } catch (error) {
          console.error(
            `Error serializing package '${this.name}'`,
            error.stack
          );
        }
      }
    }
  }

  async deactivate() {
    this.activationPromise = null;
    this.resolveActivationPromise = null;
    if (this.activationCommandSubscriptions)
      this.activationCommandSubscriptions.dispose();
    if (this.activationHookSubscriptions)
      this.activationHookSubscriptions.dispose();
    this.configSchemaRegisteredOnActivate = false;
    this.unregisterURIHandler();
    this.deactivateResources();
    this.deactivateKeymaps();

    if (!this.mainActivated) {
      this.emitter.emit('did-deactivate');
      return;
    }

    if (typeof this.mainModule.deactivate === 'function') {
      try {
        const deactivationResult = this.mainModule.deactivate();
        if (
          deactivationResult &&
          typeof deactivationResult.then === 'function'
        ) {
          await deactivationResult;
        }
      } catch (error) {
        console.error(`Error deactivating package '${this.name}'`, error.stack);
      }
    }

    if (typeof this.mainModule.deactivateConfig === 'function') {
      try {
        await this.mainModule.deactivateConfig();
      } catch (error) {
        console.error(`Error deactivating package '${this.name}'`, error.stack);
      }
    }

    this.mainActivated = false;
    this.mainInitialized = false;
    this.emitter.emit('did-deactivate');
  }

  deactivateResources() {
    for (let grammar of this.grammars) {
      grammar.deactivate();
    }
    for (let settings of this.settings) {
      settings.deactivate(this.config);
    }

    if (this.stylesheetDisposables) this.stylesheetDisposables.dispose();
    if (this.activationDisposables) this.activationDisposables.dispose();
    if (this.keymapDisposables) this.keymapDisposables.dispose();

    this.stylesheetsActivated = false;
    this.grammarsActivated = false;
    this.settingsActivated = false;
    this.menusActivated = false;
  }

  reloadStylesheets() {
    try {
      this.loadStylesheets();
    } catch (error) {
      this.handleError(
        `Failed to reload the ${this.name} package stylesheets`,
        error
      );
    }

    if (this.stylesheetDisposables) this.stylesheetDisposables.dispose();
    this.stylesheetDisposables = new CompositeDisposable();
    this.stylesheetsActivated = false;
    this.activateStylesheets();
  }

  requireMainModule() {
    if (this.bundledPackage && this.packageManager.packagesCache[this.name]) {
      if (this.packageManager.packagesCache[this.name].main) {
        this.mainModule = requireModule(
          this.packageManager.packagesCache[this.name].main
        );
        return this.mainModule;
      }
    } else if (this.mainModuleRequired) {
      return this.mainModule;
    } else if (!this.isCompatible()) {
      const nativeModuleNames = this.incompatibleModules
        .map(m => m.name)
        .join(', ');
      console.warn(dedent`
        Failed to require the main module of '${
          this.name
        }' because it requires one or more incompatible native modules (${nativeModuleNames}).
        Run \`apm rebuild\` in the package directory and restart Atom to resolve.\
      `);
    } else {
      const mainModulePath = this.getMainModulePath();
      if (fs.isFileSync(mainModulePath)) {
        this.mainModuleRequired = true;

        const previousViewProviderCount = this.viewRegistry.getViewProviderCount();
        const previousDeserializerCount = this.deserializerManager.getDeserializerCount();
        this.mainModule = requireModule(mainModulePath);
        if (
          this.viewRegistry.getViewProviderCount() ===
            previousViewProviderCount &&
          this.deserializerManager.getDeserializerCount() ===
            previousDeserializerCount
        ) {
          localStorage.setItem(
            this.getCanDeferMainModuleRequireStorageKey(),
            'true'
          );
        } else {
          localStorage.removeItem(
            this.getCanDeferMainModuleRequireStorageKey()
          );
        }
        return this.mainModule;
      }
    }
  }

  getMainModulePath() {
    if (this.resolvedMainModulePath) return this.mainModulePath;
    this.resolvedMainModulePath = true;

    if (this.bundledPackage && this.packageManager.packagesCache[this.name]) {
      if (this.packageManager.packagesCache[this.name].main) {
        this.mainModulePath = path.resolve(
          this.packageManager.resourcePath,
          'static',
          this.packageManager.packagesCache[this.name].main
        );
      } else {
        this.mainModulePath = null;
      }
    } else {
      const mainModulePath = this.metadata.main
        ? path.join(this.path, this.metadata.main)
        : path.join(this.path, 'index');
      this.mainModulePath = fs.resolveExtension(mainModulePath, [
        '',
        ...CompileCache.supportedExtensions
      ]);
    }
    return this.mainModulePath;
  }

  activationShouldBeDeferred() {
    return (
      !this.deserialized &&
      (this.hasActivationCommands() ||
        this.hasActivationHooks() ||
        this.hasWorkspaceOpeners() ||
        this.hasDeferredURIHandler())
    );
  }

  hasActivationHooks() {
    const hooks = this.getActivationHooks();
    return hooks && hooks.length > 0;
  }

  hasWorkspaceOpeners() {
    const openers = this.getWorkspaceOpeners();
    return openers && openers.length > 0;
  }

  hasActivationCommands() {
    const object = this.getActivationCommands();
    for (let selector in object) {
      const commands = object[selector];
      if (commands.length > 0) return true;
    }
    return false;
  }

  hasDeferredURIHandler() {
    const handler = this.getURIHandler();
    return handler && handler.deferActivation !== false;
  }

  subscribeToDeferredActivation() {
    this.subscribeToActivationCommands();
    this.subscribeToActivationHooks();
    this.subscribeToWorkspaceOpeners();
  }

  subscribeToActivationCommands() {
    this.activationCommandSubscriptions = new CompositeDisposable();
    const object = this.getActivationCommands();
    for (let selector in object) {
      const commands = object[selector];
      for (let command of commands) {
        ((selector, command) => {
          // Add dummy command so it appears in menu.
          // The real command will be registered on package activation
          try {
            this.activationCommandSubscriptions.add(
              this.commandRegistry.add(selector, command, function() {})
            );
          } catch (error) {
            if (error.code === 'EBADSELECTOR') {
              const metadataPath = path.join(this.path, 'package.json');
              error.message += ` in ${metadataPath}`;
              error.stack += `\n  at ${metadataPath}:1:1`;
            }
            throw error;
          }

          this.activationCommandSubscriptions.add(
            this.commandRegistry.onWillDispatch(event => {
              if (event.type !== command) return;
              let currentTarget = event.target;
              while (currentTarget) {
                if (currentTarget.webkitMatchesSelector(selector)) {
                  this.activationCommandSubscriptions.dispose();
                  this.activateNow();
                  break;
                }
                currentTarget = currentTarget.parentElement;
              }
            })
          );
        })(selector, command);
      }
    }
  }

  getActivationCommands() {
    if (this.activationCommands) return this.activationCommands;

    this.activationCommands = {};

    if (this.metadata.activationCommands) {
      for (let selector in this.metadata.activationCommands) {
        const commands = this.metadata.activationCommands[selector];
        if (!this.activationCommands[selector])
          this.activationCommands[selector] = [];
        if (typeof commands === 'string') {
          this.activationCommands[selector].push(commands);
        } else if (Array.isArray(commands)) {
          this.activationCommands[selector].push(...commands);
        }
      }
    }

    return this.activationCommands;
  }

  subscribeToActivationHooks() {
    this.activationHookSubscriptions = new CompositeDisposable();
    for (let hook of this.getActivationHooks()) {
      if (typeof hook === 'string' && hook.trim().length > 0) {
        this.activationHookSubscriptions.add(
          this.packageManager.onDidTriggerActivationHook(hook, () =>
            this.activateNow()
          )
        );
      }
    }
  }

  getActivationHooks() {
    if (this.metadata && this.activationHooks) return this.activationHooks;

    if (this.metadata.activationHooks) {
      if (Array.isArray(this.metadata.activationHooks)) {
        this.activationHooks = Array.from(
          new Set(this.metadata.activationHooks)
        );
      } else if (typeof this.metadata.activationHooks === 'string') {
        this.activationHooks = [this.metadata.activationHooks];
      } else {
        this.activationHooks = [];
      }
    } else {
      this.activationHooks = [];
    }

    return this.activationHooks;
  }

  subscribeToWorkspaceOpeners() {
    this.workspaceOpenerSubscriptions = new CompositeDisposable();
    for (let opener of this.getWorkspaceOpeners()) {
      this.workspaceOpenerSubscriptions.add(
        atom.workspace.addOpener(filePath => {
          if (filePath === opener) {
            this.activateNow();
            this.workspaceOpenerSubscriptions.dispose();
            return atom.workspace.createItemForURI(opener);
          }
        })
      );
    }
  }

  getWorkspaceOpeners() {
    if (this.workspaceOpeners) return this.workspaceOpeners;

    if (this.metadata.workspaceOpeners) {
      if (Array.isArray(this.metadata.workspaceOpeners)) {
        this.workspaceOpeners = Array.from(
          new Set(this.metadata.workspaceOpeners)
        );
      } else if (typeof this.metadata.workspaceOpeners === 'string') {
        this.workspaceOpeners = [this.metadata.workspaceOpeners];
      } else {
        this.workspaceOpeners = [];
      }
    } else {
      this.workspaceOpeners = [];
    }

    return this.workspaceOpeners;
  }

  getURIHandler() {
    return this.metadata && this.metadata.uriHandler;
  }

  // Does the given module path contain native code?
  isNativeModule(modulePath) {
    try {
      return this.getModulePathNodeFiles(modulePath).length > 0;
    } catch (error) {
      return false;
    }
  }

  // get the list of `.node` files for the given module path
  getModulePathNodeFiles(modulePath) {
    try {
      const modulePathNodeFiles = fs.listSync(
        path.join(modulePath, 'build', 'Release'),
        ['.node']
      );
      return modulePathNodeFiles;
    } catch (error) {
      return [];
    }
  }

  // Get a Map of all the native modules => the `.node` files that this package depends on.
  //
  // First try to get this information from
  // @metadata._atomModuleCache.extensions. If @metadata._atomModuleCache doesn't
  // exist, recurse through all dependencies.
  getNativeModuleDependencyPathsMap() {
    const nativeModulePaths = new Map();

    if (this.metadata._atomModuleCache) {
      const nodeFilePaths = [];
      const relativeNativeModuleBindingPaths =
        (this.metadata._atomModuleCache.extensions &&
          this.metadata._atomModuleCache.extensions['.node']) ||
        [];
      for (let relativeNativeModuleBindingPath of relativeNativeModuleBindingPaths) {
        const nodeFilePath = path.join(
          this.path,
          relativeNativeModuleBindingPath,
          '..',
          '..',
          '..'
        );
        nodeFilePaths.push(nodeFilePath);
      }
      nativeModulePaths.set(this.path, nodeFilePaths);
      return nativeModulePaths;
    }

    const traversePath = nodeModulesPath => {
      try {
        for (let modulePath of fs.listSync(nodeModulesPath)) {
          const modulePathNodeFiles = this.getModulePathNodeFiles(modulePath);
          if (modulePathNodeFiles) {
            nativeModulePaths.set(modulePath, modulePathNodeFiles);
          }
          traversePath(path.join(modulePath, 'node_modules'));
        }
      } catch (error) {}
    };

    traversePath(path.join(this.path, 'node_modules'));

    return nativeModulePaths;
  }

  // Get an array of all the native modules that this package depends on.
  // See `getNativeModuleDependencyPathsMap` for more information
  getNativeModuleDependencyPaths() {
    return [...this.getNativeModuleDependencyPathsMap().keys()];
  }

  /*
  Section: Native Module Compatibility
  */

  // Extended: Are all native modules depended on by this package correctly
  // compiled against the current version of Atom?
  //
  // Incompatible packages cannot be activated.
  //
  // Returns a {Boolean}, true if compatible, false if incompatible.
  isCompatible() {
    if (this.compatible == null) {
      if (this.preloadedPackage) {
        this.compatible = true;
      } else if (this.getMainModulePath()) {
        this.incompatibleModules = this.getIncompatibleNativeModules();
        this.compatible =
          this.incompatibleModules.length === 0 &&
          this.getBuildFailureOutput() == null;
      } else {
        this.compatible = true;
      }
    }
    return this.compatible;
  }

  // Extended: Rebuild native modules in this package's dependencies for the
  // current version of Atom.
  //
  // Returns a {Promise} that resolves with an object containing `code`,
  // `stdout`, and `stderr` properties based on the results of running
  // `apm rebuild` on the package.
  rebuild() {
    return new Promise(resolve =>
      this.runRebuildProcess(result => {
        if (result.code === 0) {
          global.localStorage.removeItem(
            this.getBuildFailureOutputStorageKey()
          );
        } else {
          this.compatible = false;
          global.localStorage.setItem(
            this.getBuildFailureOutputStorageKey(),
            result.stderr
          );
        }
        global.localStorage.setItem(
          this.getIncompatibleNativeModulesStorageKey(),
          '[]'
        );
        resolve(result);
      })
    );
  }

  // Extended: If a previous rebuild failed, get the contents of stderr.
  //
  // Returns a {String} or null if no previous build failure occurred.
  getBuildFailureOutput() {
    return global.localStorage.getItem(this.getBuildFailureOutputStorageKey());
  }

  runRebuildProcess(done) {
    let stderr = '';
    let stdout = '';
    return new BufferedProcess({
      command: this.packageManager.getApmPath(),
      args: ['rebuild', '--no-color'],
      options: { cwd: this.path },
      stderr(output) {
        stderr += output;
      },
      stdout(output) {
        stdout += output;
      },
      exit(code) {
        done({ code, stdout, stderr });
      }
    });
  }

  getBuildFailureOutputStorageKey() {
    return `installed-packages:${this.name}:${
      this.metadata.version
    }:build-error`;
  }

  getIncompatibleNativeModulesStorageKey() {
    const electronVersion = process.versions.electron;
    return `installed-packages:${this.name}:${
      this.metadata.version
    }:electron-${electronVersion}:incompatible-native-modules`;
  }

  getCanDeferMainModuleRequireStorageKey() {
    return `installed-packages:${this.name}:${
      this.metadata.version
    }:can-defer-main-module-require`;
  }

  // Get the incompatible native modules that this package depends on.
  // This recurses through all dependencies and requires all `.node` files.
  //
  // This information is cached in local storage on a per package/version basis
  // to minimize the impact on startup time.
  getIncompatibleNativeModules() {
    if (!this.packageManager.devMode) {
      try {
        const arrayAsString = global.localStorage.getItem(
          this.getIncompatibleNativeModulesStorageKey()
        );
        if (arrayAsString) return JSON.parse(arrayAsString);
      } catch (error1) {}
    }

    const incompatibleNativeModules = [];
    const nativeModulePaths = this.getNativeModuleDependencyPathsMap();
    for (const [nativeModulePath, nodeFilesPaths] of nativeModulePaths) {
      try {
        // require each .node file
        for (const nodeFilePath of nodeFilesPaths) {
          require(nodeFilePath);
        }
      } catch (error) {
        let version;
        try {
          ({ version } = require(`${nativeModulePath}/package.json`));
        } catch (error2) {}
        incompatibleNativeModules.push({
          path: nativeModulePath,
          name: path.basename(nativeModulePath),
          version,
          error: error.message
        });
      }
    }

    global.localStorage.setItem(
      this.getIncompatibleNativeModulesStorageKey(),
      JSON.stringify(incompatibleNativeModules)
    );

    return incompatibleNativeModules;
  }

  handleError(message, error) {
    if (atom.inSpecMode()) throw error;

    let detail, location, stack;
    if (error.filename && error.location && error instanceof SyntaxError) {
      location = `${error.filename}:${error.location.first_line + 1}:${error
        .location.first_column + 1}`;
      detail = `${error.message} in ${location}`;
      stack = 'SyntaxError: ' + error.message + '\n' + 'at ' + location;
    } else if (
      error.less &&
      error.filename &&
      error.column != null &&
      error.line != null
    ) {
      location = `${error.filename}:${error.line}:${error.column}`;
      detail = `${error.message} in ${location}`;
      stack = 'LessError: ' + error.message + '\n' + 'at ' + location;
    } else {
      detail = error.message;
      stack = error.stack || error;
    }

    this.notificationManager.addFatalError(message, {
      stack,
      detail,
      packageName: this.name,
      dismissable: true
    });
  }
};

class SettingsFile {
  static load(path, callback) {
    CSON.readFile(path, (error, properties = {}) => {
      if (error) {
        callback(error);
      } else {
        callback(null, new SettingsFile(path, properties));
      }
    });
  }

  constructor(path, properties) {
    this.path = path;
    this.properties = properties;
  }

  activate(config) {
    for (let selector in this.properties) {
      config.set(null, this.properties[selector], {
        scopeSelector: selector,
        source: this.path
      });
    }
  }

  deactivate(config) {
    for (let selector in this.properties) {
      config.unset(null, { scopeSelector: selector, source: this.path });
    }
  }
}
