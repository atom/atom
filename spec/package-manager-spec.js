const path = require('path');
const url = require('url');
const Package = require('../src/package');
const PackageManager = require('../src/package-manager');
const temp = require('temp').track();
const fs = require('fs-plus');
const { Disposable } = require('atom');
const { buildKeydownEvent } = require('../src/keymap-extensions');
const { mockLocalStorage } = require('./spec-helper');
const ModuleCache = require('../src/module-cache');

describe('PackageManager', () => {
  function createTestElement(className) {
    const element = document.createElement('div');
    element.className = className;
    return element;
  }

  beforeEach(() => {
    spyOn(ModuleCache, 'add');
  });

  describe('initialize', () => {
    it('adds regular package path', () => {
      const packageManger = new PackageManager({});
      const configDirPath = path.join('~', 'someConfig');
      packageManger.initialize({ configDirPath });
      expect(packageManger.packageDirPaths.length).toBe(1);
      expect(packageManger.packageDirPaths[0]).toBe(
        path.join(configDirPath, 'packages')
      );
    });

    it('adds regular package path, dev package path, and Atom repo package path in dev mode and dev resource path is set', () => {
      const packageManger = new PackageManager({});
      const configDirPath = path.join('~', 'someConfig');
      const resourcePath = path.join('~', '/atom');
      packageManger.initialize({ configDirPath, resourcePath, devMode: true });
      expect(packageManger.packageDirPaths.length).toBe(3);
      expect(packageManger.packageDirPaths).toContain(
        path.join(configDirPath, 'packages')
      );
      expect(packageManger.packageDirPaths).toContain(
        path.join(configDirPath, 'dev', 'packages')
      );
      expect(packageManger.packageDirPaths).toContain(
        path.join(resourcePath, 'packages')
      );
    });
  });

  describe('::getApmPath()', () => {
    it('returns the path to the apm command', () => {
      let apmPath = path.join(
        process.resourcesPath,
        'app',
        'apm',
        'bin',
        'apm'
      );
      if (process.platform === 'win32') {
        apmPath += '.cmd';
      }
      expect(atom.packages.getApmPath()).toBe(apmPath);
    });

    describe('when the core.apmPath setting is set', () => {
      beforeEach(() => atom.config.set('core.apmPath', '/path/to/apm'));

      it('returns the value of the core.apmPath config setting', () => {
        expect(atom.packages.getApmPath()).toBe('/path/to/apm');
      });
    });
  });

  describe('::loadPackages()', () => {
    beforeEach(() => spyOn(atom.packages, 'loadAvailablePackage'));

    afterEach(async () => {
      await atom.packages.deactivatePackages();
      atom.packages.unloadPackages();
    });

    it('sets hasLoadedInitialPackages', () => {
      expect(atom.packages.hasLoadedInitialPackages()).toBe(false);
      atom.packages.loadPackages();
      expect(atom.packages.hasLoadedInitialPackages()).toBe(true);
    });
  });

  describe('::loadPackage(name)', () => {
    beforeEach(() => atom.config.set('core.disabledPackages', []));

    it('returns the package', () => {
      const pack = atom.packages.loadPackage('package-with-index');
      expect(pack instanceof Package).toBe(true);
      expect(pack.metadata.name).toBe('package-with-index');
    });

    it('returns the package if it has an invalid keymap', () => {
      spyOn(atom, 'inSpecMode').andReturn(false);
      const pack = atom.packages.loadPackage('package-with-broken-keymap');
      expect(pack instanceof Package).toBe(true);
      expect(pack.metadata.name).toBe('package-with-broken-keymap');
    });

    it('returns the package if it has an invalid stylesheet', () => {
      spyOn(atom, 'inSpecMode').andReturn(false);
      const pack = atom.packages.loadPackage('package-with-invalid-styles');
      expect(pack instanceof Package).toBe(true);
      expect(pack.metadata.name).toBe('package-with-invalid-styles');
      expect(pack.stylesheets.length).toBe(0);

      const addErrorHandler = jasmine.createSpy();
      atom.notifications.onDidAddNotification(addErrorHandler);
      expect(() => pack.reloadStylesheets()).not.toThrow();
      expect(addErrorHandler.callCount).toBe(2);
      expect(addErrorHandler.argsForCall[1][0].message).toContain(
        'Failed to reload the package-with-invalid-styles package stylesheets'
      );
      expect(addErrorHandler.argsForCall[1][0].options.packageName).toEqual(
        'package-with-invalid-styles'
      );
    });

    it('returns null if the package has an invalid package.json', () => {
      spyOn(atom, 'inSpecMode').andReturn(false);
      const addErrorHandler = jasmine.createSpy();
      atom.notifications.onDidAddNotification(addErrorHandler);
      expect(
        atom.packages.loadPackage('package-with-broken-package-json')
      ).toBeNull();
      expect(addErrorHandler.callCount).toBe(1);
      expect(addErrorHandler.argsForCall[0][0].message).toContain(
        'Failed to load the package-with-broken-package-json package'
      );
      expect(addErrorHandler.argsForCall[0][0].options.packageName).toEqual(
        'package-with-broken-package-json'
      );
    });

    it('returns null if the package name or path starts with a dot', () => {
      expect(
        atom.packages.loadPackage('/Users/user/.atom/packages/.git')
      ).toBeNull();
    });

    it('normalizes short repository urls in package.json', () => {
      let { metadata } = atom.packages.loadPackage(
        'package-with-short-url-package-json'
      );
      expect(metadata.repository.type).toBe('git');
      expect(metadata.repository.url).toBe('https://github.com/example/repo');
      ({ metadata } = atom.packages.loadPackage(
        'package-with-invalid-url-package-json'
      ));
      expect(metadata.repository.type).toBe('git');
      expect(metadata.repository.url).toBe('foo');
    });

    it('trims git+ from the beginning and .git from the end of repository URLs, even if npm already normalized them ', () => {
      const { metadata } = atom.packages.loadPackage(
        'package-with-prefixed-and-suffixed-repo-url'
      );
      expect(metadata.repository.type).toBe('git');
      expect(metadata.repository.url).toBe('https://github.com/example/repo');
    });

    it('returns null if the package is not found in any package directory', () => {
      spyOn(console, 'warn');
      expect(
        atom.packages.loadPackage('this-package-cannot-be-found')
      ).toBeNull();
      expect(console.warn.callCount).toBe(1);
      expect(console.warn.argsForCall[0][0]).toContain('Could not resolve');
    });

    describe('when the package is deprecated', () => {
      it('returns null', () => {
        spyOn(console, 'warn');
        expect(
          atom.packages.loadPackage(
            path.join(__dirname, 'fixtures', 'packages', 'wordcount')
          )
        ).toBeNull();
        expect(atom.packages.isDeprecatedPackage('wordcount', '2.1.9')).toBe(
          true
        );
        expect(atom.packages.isDeprecatedPackage('wordcount', '2.2.0')).toBe(
          true
        );
        expect(atom.packages.isDeprecatedPackage('wordcount', '2.2.1')).toBe(
          false
        );
        expect(
          atom.packages.getDeprecatedPackageMetadata('wordcount').version
        ).toBe('<=2.2.0');
      });
    });

    it('invokes ::onDidLoadPackage listeners with the loaded package', () => {
      let loadedPackage = null;

      atom.packages.onDidLoadPackage(pack => {
        loadedPackage = pack;
      });

      atom.packages.loadPackage('package-with-main');

      expect(loadedPackage.name).toBe('package-with-main');
    });

    it("registers any deserializers specified in the package's package.json", () => {
      atom.packages.loadPackage('package-with-deserializers');

      const state1 = { deserializer: 'Deserializer1', a: 'b' };
      expect(atom.deserializers.deserialize(state1)).toEqual({
        wasDeserializedBy: 'deserializeMethod1',
        state: state1
      });

      const state2 = { deserializer: 'Deserializer2', c: 'd' };
      expect(atom.deserializers.deserialize(state2)).toEqual({
        wasDeserializedBy: 'deserializeMethod2',
        state: state2
      });
    });

    it('early-activates any atom.directory-provider or atom.repository-provider services that the package provide', () => {
      jasmine.useRealClock();

      const providers = [];
      atom.packages.serviceHub.consume(
        'atom.directory-provider',
        '^0.1.0',
        provider => providers.push(provider)
      );

      atom.packages.loadPackage('package-with-directory-provider');
      expect(providers.map(p => p.name)).toEqual([
        'directory provider from package-with-directory-provider'
      ]);
    });

    describe("when there are view providers specified in the package's package.json", () => {
      const model1 = { worksWithViewProvider1: true };
      const model2 = { worksWithViewProvider2: true };

      afterEach(async () => {
        await atom.packages.deactivatePackage('package-with-view-providers');
        atom.packages.unloadPackage('package-with-view-providers');
      });

      it('does not load the view providers immediately', () => {
        const pack = atom.packages.loadPackage('package-with-view-providers');
        expect(pack.mainModule).toBeNull();

        expect(() => atom.views.getView(model1)).toThrow();
        expect(() => atom.views.getView(model2)).toThrow();
      });

      it('registers the view providers when the package is activated', async () => {
        atom.packages.loadPackage('package-with-view-providers');

        await atom.packages.activatePackage('package-with-view-providers');

        const element1 = atom.views.getView(model1);
        expect(element1 instanceof HTMLDivElement).toBe(true);
        expect(element1.dataset.createdBy).toBe('view-provider-1');

        const element2 = atom.views.getView(model2);
        expect(element2 instanceof HTMLDivElement).toBe(true);
        expect(element2.dataset.createdBy).toBe('view-provider-2');
      });

      it("registers the view providers when any of the package's deserializers are used", () => {
        atom.packages.loadPackage('package-with-view-providers');

        spyOn(atom.views, 'addViewProvider').andCallThrough();
        atom.deserializers.deserialize({
          deserializer: 'DeserializerFromPackageWithViewProviders',
          a: 'b'
        });
        expect(atom.views.addViewProvider.callCount).toBe(2);

        atom.deserializers.deserialize({
          deserializer: 'DeserializerFromPackageWithViewProviders',
          a: 'b'
        });
        expect(atom.views.addViewProvider.callCount).toBe(2);

        const element1 = atom.views.getView(model1);
        expect(element1 instanceof HTMLDivElement).toBe(true);
        expect(element1.dataset.createdBy).toBe('view-provider-1');

        const element2 = atom.views.getView(model2);
        expect(element2 instanceof HTMLDivElement).toBe(true);
        expect(element2.dataset.createdBy).toBe('view-provider-2');
      });
    });

    it("registers the config schema in the package's metadata, if present", () => {
      let pack = atom.packages.loadPackage('package-with-json-config-schema');
      expect(atom.config.getSchema('package-with-json-config-schema')).toEqual({
        type: 'object',
        properties: {
          a: { type: 'number', default: 5 },
          b: { type: 'string', default: 'five' }
        }
      });

      expect(pack.mainModule).toBeNull();

      atom.packages.unloadPackage('package-with-json-config-schema');
      atom.config.clear();

      pack = atom.packages.loadPackage('package-with-json-config-schema');
      expect(atom.config.getSchema('package-with-json-config-schema')).toEqual({
        type: 'object',
        properties: {
          a: { type: 'number', default: 5 },
          b: { type: 'string', default: 'five' }
        }
      });
    });

    describe('when a package does not have deserializers, view providers or a config schema in its package.json', () => {
      beforeEach(() => mockLocalStorage());

      it("defers loading the package's main module if the package previously used no Atom APIs when its main module was required", () => {
        const pack1 = atom.packages.loadPackage('package-with-main');
        expect(pack1.mainModule).toBeDefined();

        atom.packages.unloadPackage('package-with-main');

        const pack2 = atom.packages.loadPackage('package-with-main');
        expect(pack2.mainModule).toBeNull();
      });

      it("does not defer loading the package's main module if the package previously used Atom APIs when its main module was required", () => {
        const pack1 = atom.packages.loadPackage(
          'package-with-eval-time-api-calls'
        );
        expect(pack1.mainModule).toBeDefined();

        atom.packages.unloadPackage('package-with-eval-time-api-calls');

        const pack2 = atom.packages.loadPackage(
          'package-with-eval-time-api-calls'
        );
        expect(pack2.mainModule).not.toBeNull();
      });
    });
  });

  describe('::loadAvailablePackage(availablePackage)', () => {
    describe('if the package was preloaded', () => {
      it('adds the package path to the module cache', () => {
        const availablePackage = atom.packages
          .getAvailablePackages()
          .find(p => p.name === 'spell-check');
        availablePackage.isBundled = true;
        expect(
          atom.packages.preloadedPackages[availablePackage.name]
        ).toBeUndefined();
        expect(atom.packages.isPackageLoaded(availablePackage.name)).toBe(
          false
        );

        const metadata = atom.packages.loadPackageMetadata(availablePackage);
        atom.packages.preloadPackage(availablePackage.name, {
          rootDirPath: path.relative(
            atom.packages.resourcePath,
            availablePackage.path
          ),
          metadata
        });
        atom.packages.loadAvailablePackage(availablePackage);
        expect(atom.packages.isPackageLoaded(availablePackage.name)).toBe(true);
        expect(ModuleCache.add).toHaveBeenCalledWith(
          availablePackage.path,
          metadata
        );
      });

      it('deactivates it if it had been disabled', () => {
        const availablePackage = atom.packages
          .getAvailablePackages()
          .find(p => p.name === 'spell-check');
        availablePackage.isBundled = true;
        expect(
          atom.packages.preloadedPackages[availablePackage.name]
        ).toBeUndefined();
        expect(atom.packages.isPackageLoaded(availablePackage.name)).toBe(
          false
        );

        const metadata = atom.packages.loadPackageMetadata(availablePackage);
        const preloadedPackage = atom.packages.preloadPackage(
          availablePackage.name,
          {
            rootDirPath: path.relative(
              atom.packages.resourcePath,
              availablePackage.path
            ),
            metadata
          }
        );
        expect(preloadedPackage.keymapActivated).toBe(true);
        expect(preloadedPackage.settingsActivated).toBe(true);
        expect(preloadedPackage.menusActivated).toBe(true);

        atom.packages.loadAvailablePackage(
          availablePackage,
          new Set([availablePackage.name])
        );
        expect(atom.packages.isPackageLoaded(availablePackage.name)).toBe(
          false
        );
        expect(preloadedPackage.keymapActivated).toBe(false);
        expect(preloadedPackage.settingsActivated).toBe(false);
        expect(preloadedPackage.menusActivated).toBe(false);
      });

      it('deactivates it and reloads the new one if trying to load the same package outside of the bundle', () => {
        const availablePackage = atom.packages
          .getAvailablePackages()
          .find(p => p.name === 'spell-check');
        availablePackage.isBundled = true;
        expect(
          atom.packages.preloadedPackages[availablePackage.name]
        ).toBeUndefined();
        expect(atom.packages.isPackageLoaded(availablePackage.name)).toBe(
          false
        );

        const metadata = atom.packages.loadPackageMetadata(availablePackage);
        const preloadedPackage = atom.packages.preloadPackage(
          availablePackage.name,
          {
            rootDirPath: path.relative(
              atom.packages.resourcePath,
              availablePackage.path
            ),
            metadata
          }
        );
        expect(preloadedPackage.keymapActivated).toBe(true);
        expect(preloadedPackage.settingsActivated).toBe(true);
        expect(preloadedPackage.menusActivated).toBe(true);

        availablePackage.isBundled = false;
        atom.packages.loadAvailablePackage(availablePackage);
        expect(atom.packages.isPackageLoaded(availablePackage.name)).toBe(true);
        expect(preloadedPackage.keymapActivated).toBe(false);
        expect(preloadedPackage.settingsActivated).toBe(false);
        expect(preloadedPackage.menusActivated).toBe(false);
      });
    });

    describe('if the package was not preloaded', () => {
      it('adds the package path to the module cache', () => {
        const availablePackage = atom.packages
          .getAvailablePackages()
          .find(p => p.name === 'spell-check');
        availablePackage.isBundled = true;
        const metadata = atom.packages.loadPackageMetadata(availablePackage);
        atom.packages.loadAvailablePackage(availablePackage);
        expect(ModuleCache.add).toHaveBeenCalledWith(
          availablePackage.path,
          metadata
        );
      });
    });
  });

  describe('preloading', () => {
    it('requires the main module, loads the config schema and activates keymaps, menus and settings without reactivating them during package activation', () => {
      const availablePackage = atom.packages
        .getAvailablePackages()
        .find(p => p.name === 'spell-check');
      availablePackage.isBundled = true;
      const metadata = atom.packages.loadPackageMetadata(availablePackage);
      expect(
        atom.packages.preloadedPackages[availablePackage.name]
      ).toBeUndefined();
      expect(atom.packages.isPackageLoaded(availablePackage.name)).toBe(false);

      atom.packages.packagesCache = {};
      atom.packages.packagesCache[availablePackage.name] = {
        main: path.join(availablePackage.path, metadata.main),
        grammarPaths: []
      };
      const preloadedPackage = atom.packages.preloadPackage(
        availablePackage.name,
        {
          rootDirPath: path.relative(
            atom.packages.resourcePath,
            availablePackage.path
          ),
          metadata
        }
      );
      expect(preloadedPackage.keymapActivated).toBe(true);
      expect(preloadedPackage.settingsActivated).toBe(true);
      expect(preloadedPackage.menusActivated).toBe(true);
      expect(preloadedPackage.mainModule).toBeTruthy();
      expect(preloadedPackage.configSchemaRegisteredOnLoad).toBeTruthy();

      spyOn(atom.keymaps, 'add');
      spyOn(atom.menu, 'add');
      spyOn(atom.contextMenu, 'add');
      spyOn(atom.config, 'setSchema');

      atom.packages.loadAvailablePackage(availablePackage);
      expect(preloadedPackage.getMainModulePath()).toBe(
        path.join(availablePackage.path, metadata.main)
      );

      atom.packages.activatePackage(availablePackage.name);
      expect(atom.keymaps.add).not.toHaveBeenCalled();
      expect(atom.menu.add).not.toHaveBeenCalled();
      expect(atom.contextMenu.add).not.toHaveBeenCalled();
      expect(atom.config.setSchema).not.toHaveBeenCalled();
      expect(preloadedPackage.keymapActivated).toBe(true);
      expect(preloadedPackage.settingsActivated).toBe(true);
      expect(preloadedPackage.menusActivated).toBe(true);
      expect(preloadedPackage.mainModule).toBeTruthy();
      expect(preloadedPackage.configSchemaRegisteredOnLoad).toBeTruthy();
    });

    it('deactivates disabled keymaps during package activation', () => {
      const availablePackage = atom.packages
        .getAvailablePackages()
        .find(p => p.name === 'spell-check');
      availablePackage.isBundled = true;
      const metadata = atom.packages.loadPackageMetadata(availablePackage);
      expect(
        atom.packages.preloadedPackages[availablePackage.name]
      ).toBeUndefined();
      expect(atom.packages.isPackageLoaded(availablePackage.name)).toBe(false);

      atom.packages.packagesCache = {};
      atom.packages.packagesCache[availablePackage.name] = {
        main: path.join(availablePackage.path, metadata.main),
        grammarPaths: []
      };
      const preloadedPackage = atom.packages.preloadPackage(
        availablePackage.name,
        {
          rootDirPath: path.relative(
            atom.packages.resourcePath,
            availablePackage.path
          ),
          metadata
        }
      );
      expect(preloadedPackage.keymapActivated).toBe(true);
      expect(preloadedPackage.settingsActivated).toBe(true);
      expect(preloadedPackage.menusActivated).toBe(true);

      atom.packages.loadAvailablePackage(availablePackage);
      atom.config.set('core.packagesWithKeymapsDisabled', [
        availablePackage.name
      ]);
      atom.packages.activatePackage(availablePackage.name);

      expect(preloadedPackage.keymapActivated).toBe(false);
      expect(preloadedPackage.settingsActivated).toBe(true);
      expect(preloadedPackage.menusActivated).toBe(true);
    });
  });

  describe('::unloadPackage(name)', () => {
    describe('when the package is active', () => {
      it('throws an error', async () => {
        const pack = await atom.packages.activatePackage('package-with-main');
        expect(atom.packages.isPackageLoaded(pack.name)).toBeTruthy();
        expect(atom.packages.isPackageActive(pack.name)).toBeTruthy();

        expect(() => atom.packages.unloadPackage(pack.name)).toThrow();
        expect(atom.packages.isPackageLoaded(pack.name)).toBeTruthy();
        expect(atom.packages.isPackageActive(pack.name)).toBeTruthy();
      });
    });

    describe('when the package is not loaded', () => {
      it('throws an error', () => {
        expect(atom.packages.isPackageLoaded('unloaded')).toBeFalsy();
        expect(() => atom.packages.unloadPackage('unloaded')).toThrow();
        expect(atom.packages.isPackageLoaded('unloaded')).toBeFalsy();
      });
    });

    describe('when the package is loaded', () => {
      it('no longers reports it as being loaded', () => {
        const pack = atom.packages.loadPackage('package-with-main');
        expect(atom.packages.isPackageLoaded(pack.name)).toBeTruthy();
        atom.packages.unloadPackage(pack.name);
        expect(atom.packages.isPackageLoaded(pack.name)).toBeFalsy();
      });
    });

    it('invokes ::onDidUnloadPackage listeners with the unloaded package', () => {
      atom.packages.loadPackage('package-with-main');
      let unloadedPackage;
      atom.packages.onDidUnloadPackage(pack => {
        unloadedPackage = pack;
      });
      atom.packages.unloadPackage('package-with-main');
      expect(unloadedPackage.name).toBe('package-with-main');
    });
  });

  describe('::activatePackage(id)', () => {
    describe('when called multiple times', () => {
      it('it only calls activate on the package once', async () => {
        spyOn(Package.prototype, 'activateNow').andCallThrough();
        await atom.packages.activatePackage('package-with-index');
        await atom.packages.activatePackage('package-with-index');
        await atom.packages.activatePackage('package-with-index');

        expect(Package.prototype.activateNow.callCount).toBe(1);
      });
    });

    describe('when the package has a main module', () => {
      beforeEach(() => {
        spyOn(Package.prototype, 'requireMainModule').andCallThrough();
      });

      describe('when the metadata specifies a main module path˜', () => {
        it('requires the module at the specified path', async () => {
          const mainModule = require('./fixtures/packages/package-with-main/main-module');
          spyOn(mainModule, 'activate');

          const pack = await atom.packages.activatePackage('package-with-main');
          expect(mainModule.activate).toHaveBeenCalled();
          expect(pack.mainModule).toBe(mainModule);
        });
      });

      describe('when the metadata does not specify a main module', () => {
        it('requires index.coffee', async () => {
          const indexModule = require('./fixtures/packages/package-with-index/index');
          spyOn(indexModule, 'activate');

          const pack = await atom.packages.activatePackage(
            'package-with-index'
          );
          expect(indexModule.activate).toHaveBeenCalled();
          expect(pack.mainModule).toBe(indexModule);
        });
      });

      it('assigns config schema, including defaults when package contains a schema', async () => {
        expect(
          atom.config.get('package-with-config-schema.numbers.one')
        ).toBeUndefined();

        await atom.packages.activatePackage('package-with-config-schema');
        expect(atom.config.get('package-with-config-schema.numbers.one')).toBe(
          1
        );
        expect(atom.config.get('package-with-config-schema.numbers.two')).toBe(
          2
        );
        expect(
          atom.config.set('package-with-config-schema.numbers.one', 'nope')
        ).toBe(false);
        expect(
          atom.config.set('package-with-config-schema.numbers.one', '10')
        ).toBe(true);
        expect(atom.config.get('package-with-config-schema.numbers.one')).toBe(
          10
        );
      });

      describe('when the package metadata includes `activationCommands`', () => {
        let mainModule, promise, workspaceCommandListener, registration;

        beforeEach(() => {
          jasmine.attachToDOM(atom.workspace.getElement());
          mainModule = require('./fixtures/packages/package-with-activation-commands/index');
          mainModule.activationCommandCallCount = 0;
          spyOn(mainModule, 'activate').andCallThrough();

          workspaceCommandListener = jasmine.createSpy(
            'workspaceCommandListener'
          );
          registration = atom.commands.add(
            'atom-workspace',
            'activation-command',
            workspaceCommandListener
          );

          promise = atom.packages.activatePackage(
            'package-with-activation-commands'
          );
        });

        afterEach(() => {
          if (registration) {
            registration.dispose();
          }
          mainModule = null;
        });

        it('defers requiring/activating the main module until an activation event bubbles to the root view', async () => {
          expect(Package.prototype.requireMainModule.callCount).toBe(0);

          atom.workspace
            .getElement()
            .dispatchEvent(
              new CustomEvent('activation-command', { bubbles: true })
            );

          await promise;
          expect(Package.prototype.requireMainModule.callCount).toBe(1);
        });

        it('triggers the activation event on all handlers registered during activation', async () => {
          await atom.workspace.open();

          const editorElement = atom.workspace
            .getActiveTextEditor()
            .getElement();
          const editorCommandListener = jasmine.createSpy(
            'editorCommandListener'
          );
          atom.commands.add(
            'atom-text-editor',
            'activation-command',
            editorCommandListener
          );

          atom.commands.dispatch(editorElement, 'activation-command');
          expect(mainModule.activate.callCount).toBe(1);
          expect(mainModule.activationCommandCallCount).toBe(1);
          expect(editorCommandListener.callCount).toBe(1);
          expect(workspaceCommandListener.callCount).toBe(1);

          atom.commands.dispatch(editorElement, 'activation-command');
          expect(mainModule.activationCommandCallCount).toBe(2);
          expect(editorCommandListener.callCount).toBe(2);
          expect(workspaceCommandListener.callCount).toBe(2);
          expect(mainModule.activate.callCount).toBe(1);
        });

        it('activates the package immediately when the events are empty', async () => {
          mainModule = require('./fixtures/packages/package-with-empty-activation-commands/index');
          spyOn(mainModule, 'activate').andCallThrough();

          atom.packages.activatePackage(
            'package-with-empty-activation-commands'
          );

          expect(mainModule.activate.callCount).toBe(1);
        });

        it('adds a notification when the activation commands are invalid', () => {
          spyOn(atom, 'inSpecMode').andReturn(false);
          const addErrorHandler = jasmine.createSpy();
          atom.notifications.onDidAddNotification(addErrorHandler);
          expect(() =>
            atom.packages.activatePackage(
              'package-with-invalid-activation-commands'
            )
          ).not.toThrow();
          expect(addErrorHandler.callCount).toBe(1);
          expect(addErrorHandler.argsForCall[0][0].message).toContain(
            'Failed to activate the package-with-invalid-activation-commands package'
          );
          expect(addErrorHandler.argsForCall[0][0].options.packageName).toEqual(
            'package-with-invalid-activation-commands'
          );
        });

        it('adds a notification when the context menu is invalid', () => {
          spyOn(atom, 'inSpecMode').andReturn(false);
          const addErrorHandler = jasmine.createSpy();
          atom.notifications.onDidAddNotification(addErrorHandler);
          expect(() =>
            atom.packages.activatePackage('package-with-invalid-context-menu')
          ).not.toThrow();
          expect(addErrorHandler.callCount).toBe(1);
          expect(addErrorHandler.argsForCall[0][0].message).toContain(
            'Failed to activate the package-with-invalid-context-menu package'
          );
          expect(addErrorHandler.argsForCall[0][0].options.packageName).toEqual(
            'package-with-invalid-context-menu'
          );
        });

        it('adds a notification when the grammar is invalid', async () => {
          let notificationEvent;

          await new Promise(resolve => {
            const subscription = atom.notifications.onDidAddNotification(
              event => {
                notificationEvent = event;
                subscription.dispose();
                resolve();
              }
            );

            atom.packages.activatePackage('package-with-invalid-grammar');
          });

          expect(notificationEvent.message).toContain(
            'Failed to load a package-with-invalid-grammar package grammar'
          );
          expect(notificationEvent.options.packageName).toEqual(
            'package-with-invalid-grammar'
          );
        });

        it('adds a notification when the settings are invalid', async () => {
          let notificationEvent;

          await new Promise(resolve => {
            const subscription = atom.notifications.onDidAddNotification(
              event => {
                notificationEvent = event;
                subscription.dispose();
                resolve();
              }
            );

            atom.packages.activatePackage('package-with-invalid-settings');
          });

          expect(notificationEvent.message).toContain(
            'Failed to load the package-with-invalid-settings package settings'
          );
          expect(notificationEvent.options.packageName).toEqual(
            'package-with-invalid-settings'
          );
        });
      });

      describe('when the package metadata includes both activation commands and deserializers', () => {
        let mainModule, promise, workspaceCommandListener, registration;

        beforeEach(() => {
          jasmine.attachToDOM(atom.workspace.getElement());
          spyOn(atom.packages, 'hasActivatedInitialPackages').andReturn(true);
          mainModule = require('./fixtures/packages/package-with-activation-commands-and-deserializers/index');
          mainModule.activationCommandCallCount = 0;
          spyOn(mainModule, 'activate').andCallThrough();
          workspaceCommandListener = jasmine.createSpy(
            'workspaceCommandListener'
          );
          registration = atom.commands.add(
            '.workspace',
            'activation-command-2',
            workspaceCommandListener
          );

          promise = atom.packages.activatePackage(
            'package-with-activation-commands-and-deserializers'
          );
        });

        afterEach(() => {
          if (registration) {
            registration.dispose();
          }
          mainModule = null;
        });

        it('activates the package when a deserializer is called', async () => {
          expect(Package.prototype.requireMainModule.callCount).toBe(0);

          const state1 = { deserializer: 'Deserializer1', a: 'b' };
          expect(atom.deserializers.deserialize(state1, atom)).toEqual({
            wasDeserializedBy: 'deserializeMethod1',
            state: state1
          });

          await promise;
          expect(Package.prototype.requireMainModule.callCount).toBe(1);
        });

        it('defers requiring/activating the main module until an activation event bubbles to the root view', async () => {
          expect(Package.prototype.requireMainModule.callCount).toBe(0);

          atom.workspace
            .getElement()
            .dispatchEvent(
              new CustomEvent('activation-command-2', { bubbles: true })
            );

          await promise;
          expect(mainModule.activate.callCount).toBe(1);
          expect(mainModule.activationCommandCallCount).toBe(1);
          expect(Package.prototype.requireMainModule.callCount).toBe(1);
        });
      });

      describe('when the package metadata includes `activationHooks`', () => {
        let mainModule, promise;

        beforeEach(() => {
          mainModule = require('./fixtures/packages/package-with-activation-hooks/index');
          spyOn(mainModule, 'activate').andCallThrough();
        });

        it('defers requiring/activating the main module until an triggering of an activation hook occurs', async () => {
          promise = atom.packages.activatePackage(
            'package-with-activation-hooks'
          );
          expect(Package.prototype.requireMainModule.callCount).toBe(0);
          atom.packages.triggerActivationHook(
            'language-fictitious:grammar-used'
          );
          atom.packages.triggerDeferredActivationHooks();

          await promise;
          expect(Package.prototype.requireMainModule.callCount).toBe(1);
        });

        it('does not double register activation hooks when deactivating and reactivating', async () => {
          promise = atom.packages.activatePackage(
            'package-with-activation-hooks'
          );
          expect(mainModule.activate.callCount).toBe(0);
          atom.packages.triggerActivationHook(
            'language-fictitious:grammar-used'
          );
          atom.packages.triggerDeferredActivationHooks();

          await promise;
          expect(mainModule.activate.callCount).toBe(1);

          await atom.packages.deactivatePackage(
            'package-with-activation-hooks'
          );

          promise = atom.packages.activatePackage(
            'package-with-activation-hooks'
          );
          atom.packages.triggerActivationHook(
            'language-fictitious:grammar-used'
          );
          atom.packages.triggerDeferredActivationHooks();

          await promise;
          expect(mainModule.activate.callCount).toBe(2);
        });

        it('activates the package immediately when activationHooks is empty', async () => {
          mainModule = require('./fixtures/packages/package-with-empty-activation-hooks/index');
          spyOn(mainModule, 'activate').andCallThrough();

          expect(Package.prototype.requireMainModule.callCount).toBe(0);

          await atom.packages.activatePackage(
            'package-with-empty-activation-hooks'
          );
          expect(mainModule.activate.callCount).toBe(1);
          expect(Package.prototype.requireMainModule.callCount).toBe(1);
        });

        it('activates the package immediately if the activation hook had already been triggered', async () => {
          atom.packages.triggerActivationHook(
            'language-fictitious:grammar-used'
          );
          atom.packages.triggerDeferredActivationHooks();
          expect(Package.prototype.requireMainModule.callCount).toBe(0);

          await atom.packages.activatePackage('package-with-activation-hooks');
          expect(mainModule.activate.callCount).toBe(1);
          expect(Package.prototype.requireMainModule.callCount).toBe(1);
        });
      });

      describe('when the package metadata includes `workspaceOpeners`', () => {
        let mainModule, promise;

        beforeEach(() => {
          mainModule = require('./fixtures/packages/package-with-workspace-openers/index');
          spyOn(mainModule, 'activate').andCallThrough();
        });

        it('defers requiring/activating the main module until a registered opener is called', async () => {
          promise = atom.packages.activatePackage(
            'package-with-workspace-openers'
          );
          expect(Package.prototype.requireMainModule.callCount).toBe(0);
          atom.workspace.open('atom://fictitious');

          await promise;
          expect(Package.prototype.requireMainModule.callCount).toBe(1);
          expect(mainModule.openerCount).toBe(1);
        });

        it('activates the package immediately when the events are empty', async () => {
          mainModule = require('./fixtures/packages/package-with-empty-workspace-openers/index');
          spyOn(mainModule, 'activate').andCallThrough();

          atom.packages.activatePackage('package-with-empty-workspace-openers');

          expect(mainModule.activate.callCount).toBe(1);
        });
      });
    });

    describe('when the package has no main module', () => {
      it('does not throw an exception', () => {
        spyOn(console, 'error');
        spyOn(console, 'warn').andCallThrough();
        expect(() =>
          atom.packages.activatePackage('package-without-module')
        ).not.toThrow();
        expect(console.error).not.toHaveBeenCalled();
        expect(console.warn).not.toHaveBeenCalled();
      });
    });

    describe('when the package does not export an activate function', () => {
      it('activates the package and does not throw an exception or log a warning', async () => {
        spyOn(console, 'warn');
        await atom.packages.activatePackage('package-with-no-activate');
        expect(console.warn).not.toHaveBeenCalled();
      });
    });

    it("passes the activate method the package's previously serialized state if it exists", async () => {
      const pack = await atom.packages.activatePackage(
        'package-with-serialization'
      );
      expect(pack.mainModule.someNumber).not.toBe(77);
      pack.mainModule.someNumber = 77;
      atom.packages.serializePackage('package-with-serialization');
      await atom.packages.deactivatePackage('package-with-serialization');

      spyOn(pack.mainModule, 'activate').andCallThrough();
      await atom.packages.activatePackage('package-with-serialization');
      expect(pack.mainModule.activate).toHaveBeenCalledWith({ someNumber: 77 });
    });

    it('invokes ::onDidActivatePackage listeners with the activated package', async () => {
      let activatedPackage;
      atom.packages.onDidActivatePackage(pack => {
        activatedPackage = pack;
      });

      await atom.packages.activatePackage('package-with-main');
      expect(activatedPackage.name).toBe('package-with-main');
    });

    describe("when the package's main module throws an error on load", () => {
      it('adds a notification instead of throwing an exception', () => {
        spyOn(atom, 'inSpecMode').andReturn(false);
        atom.config.set('core.disabledPackages', []);
        const addErrorHandler = jasmine.createSpy();
        atom.notifications.onDidAddNotification(addErrorHandler);
        expect(() =>
          atom.packages.activatePackage('package-that-throws-an-exception')
        ).not.toThrow();
        expect(addErrorHandler.callCount).toBe(1);
        expect(addErrorHandler.argsForCall[0][0].message).toContain(
          'Failed to load the package-that-throws-an-exception package'
        );
        expect(addErrorHandler.argsForCall[0][0].options.packageName).toEqual(
          'package-that-throws-an-exception'
        );
      });

      it('re-throws the exception in test mode', () => {
        atom.config.set('core.disabledPackages', []);
        expect(() =>
          atom.packages.activatePackage('package-that-throws-an-exception')
        ).toThrow('This package throws an exception');
      });
    });

    describe('when the package is not found', () => {
      it('rejects the promise', async () => {
        spyOn(console, 'warn');
        atom.config.set('core.disabledPackages', []);

        try {
          await atom.packages.activatePackage('this-doesnt-exist');
          expect('Error to be thrown').toBe('');
        } catch (error) {
          expect(console.warn.callCount).toBe(1);
          expect(error.message).toContain(
            "Failed to load package 'this-doesnt-exist'"
          );
        }
      });
    });

    describe('keymap loading', () => {
      describe("when the metadata does not contain a 'keymaps' manifest", () => {
        it('loads all the .cson/.json files in the keymaps directory', async () => {
          const element1 = createTestElement('test-1');
          const element2 = createTestElement('test-2');
          const element3 = createTestElement('test-3');
          expect(
            atom.keymaps.findKeyBindings({
              keystrokes: 'ctrl-z',
              target: element1
            })
          ).toHaveLength(0);
          expect(
            atom.keymaps.findKeyBindings({
              keystrokes: 'ctrl-z',
              target: element2
            })
          ).toHaveLength(0);
          expect(
            atom.keymaps.findKeyBindings({
              keystrokes: 'ctrl-z',
              target: element3
            })
          ).toHaveLength(0);

          await atom.packages.activatePackage('package-with-keymaps');
          expect(
            atom.keymaps.findKeyBindings({
              keystrokes: 'ctrl-z',
              target: element1
            })[0].command
          ).toBe('test-1');
          expect(
            atom.keymaps.findKeyBindings({
              keystrokes: 'ctrl-z',
              target: element2
            })[0].command
          ).toBe('test-2');
          expect(
            atom.keymaps.findKeyBindings({
              keystrokes: 'ctrl-z',
              target: element3
            })
          ).toHaveLength(0);
        });
      });

      describe("when the metadata contains a 'keymaps' manifest", () => {
        it('loads only the keymaps specified by the manifest, in the specified order', async () => {
          const element1 = createTestElement('test-1');
          const element3 = createTestElement('test-3');
          expect(
            atom.keymaps.findKeyBindings({
              keystrokes: 'ctrl-z',
              target: element1
            })
          ).toHaveLength(0);

          await atom.packages.activatePackage('package-with-keymaps-manifest');
          expect(
            atom.keymaps.findKeyBindings({
              keystrokes: 'ctrl-z',
              target: element1
            })[0].command
          ).toBe('keymap-1');
          expect(
            atom.keymaps.findKeyBindings({
              keystrokes: 'ctrl-n',
              target: element1
            })[0].command
          ).toBe('keymap-2');
          expect(
            atom.keymaps.findKeyBindings({
              keystrokes: 'ctrl-y',
              target: element3
            })
          ).toHaveLength(0);
        });
      });

      describe('when the keymap file is empty', () => {
        it('does not throw an error on activation', async () => {
          await atom.packages.activatePackage('package-with-empty-keymap');
          expect(
            atom.packages.isPackageActive('package-with-empty-keymap')
          ).toBe(true);
        });
      });

      describe("when the package's keymaps have been disabled", () => {
        it('does not add the keymaps', async () => {
          const element1 = createTestElement('test-1');
          expect(
            atom.keymaps.findKeyBindings({
              keystrokes: 'ctrl-z',
              target: element1
            })
          ).toHaveLength(0);

          atom.config.set('core.packagesWithKeymapsDisabled', [
            'package-with-keymaps-manifest'
          ]);
          await atom.packages.activatePackage('package-with-keymaps-manifest');
          expect(
            atom.keymaps.findKeyBindings({
              keystrokes: 'ctrl-z',
              target: element1
            })
          ).toHaveLength(0);
        });
      });

      describe('when setting core.packagesWithKeymapsDisabled', () => {
        it("ignores package names in the array that aren't loaded", () => {
          atom.packages.observePackagesWithKeymapsDisabled();

          expect(() =>
            atom.config.set('core.packagesWithKeymapsDisabled', [
              'package-does-not-exist'
            ])
          ).not.toThrow();
          expect(() =>
            atom.config.set('core.packagesWithKeymapsDisabled', [])
          ).not.toThrow();
        });
      });

      describe("when the package's keymaps are disabled and re-enabled after it is activated", () => {
        it('removes and re-adds the keymaps', async () => {
          const element1 = createTestElement('test-1');
          atom.packages.observePackagesWithKeymapsDisabled();

          await atom.packages.activatePackage('package-with-keymaps-manifest');

          atom.config.set('core.packagesWithKeymapsDisabled', [
            'package-with-keymaps-manifest'
          ]);
          expect(
            atom.keymaps.findKeyBindings({
              keystrokes: 'ctrl-z',
              target: element1
            })
          ).toHaveLength(0);

          atom.config.set('core.packagesWithKeymapsDisabled', []);
          expect(
            atom.keymaps.findKeyBindings({
              keystrokes: 'ctrl-z',
              target: element1
            })[0].command
          ).toBe('keymap-1');
        });
      });

      describe('when the package is de-activated and re-activated', () => {
        let element, events, userKeymapPath;

        beforeEach(() => {
          userKeymapPath = path.join(temp.mkdirSync(), 'user-keymaps.cson');
          spyOn(atom.keymaps, 'getUserKeymapPath').andReturn(userKeymapPath);

          element = createTestElement('test-1');
          jasmine.attachToDOM(element);

          events = [];
          element.addEventListener('user-command', e => events.push(e));
          element.addEventListener('test-1', e => events.push(e));
        });

        afterEach(() => {
          element.remove();

          // Avoid leaking user keymap subscription
          atom.keymaps.watchSubscriptions[userKeymapPath].dispose();
          delete atom.keymaps.watchSubscriptions[userKeymapPath];

          temp.cleanupSync();
        });

        it("doesn't override user-defined keymaps", async () => {
          fs.writeFileSync(
            userKeymapPath,
            `".test-1": {"ctrl-z": "user-command"}`
          );
          atom.keymaps.loadUserKeymap();

          await atom.packages.activatePackage('package-with-keymaps');
          atom.keymaps.handleKeyboardEvent(
            buildKeydownEvent('z', { ctrl: true, target: element })
          );
          expect(events.length).toBe(1);
          expect(events[0].type).toBe('user-command');

          await atom.packages.deactivatePackage('package-with-keymaps');
          await atom.packages.activatePackage('package-with-keymaps');
          atom.keymaps.handleKeyboardEvent(
            buildKeydownEvent('z', { ctrl: true, target: element })
          );
          expect(events.length).toBe(2);
          expect(events[1].type).toBe('user-command');
        });
      });
    });

    describe('menu loading', () => {
      beforeEach(() => {
        atom.contextMenu.definitions = [];
        atom.menu.template = [];
      });

      describe("when the metadata does not contain a 'menus' manifest", () => {
        it('loads all the .cson/.json files in the menus directory', async () => {
          const element = createTestElement('test-1');
          expect(atom.contextMenu.templateForElement(element)).toEqual([]);

          await atom.packages.activatePackage('package-with-menus');
          expect(atom.menu.template.length).toBe(2);
          expect(atom.menu.template[0].label).toBe('Second to Last');
          expect(atom.menu.template[1].label).toBe('Last');
          expect(atom.contextMenu.templateForElement(element)[0].label).toBe(
            'Menu item 1'
          );
          expect(atom.contextMenu.templateForElement(element)[1].label).toBe(
            'Menu item 2'
          );
          expect(atom.contextMenu.templateForElement(element)[2].label).toBe(
            'Menu item 3'
          );
        });
      });

      describe("when the metadata contains a 'menus' manifest", () => {
        it('loads only the menus specified by the manifest, in the specified order', async () => {
          const element = createTestElement('test-1');
          expect(atom.contextMenu.templateForElement(element)).toEqual([]);

          await atom.packages.activatePackage('package-with-menus-manifest');
          expect(atom.menu.template[0].label).toBe('Second to Last');
          expect(atom.menu.template[1].label).toBe('Last');
          expect(atom.contextMenu.templateForElement(element)[0].label).toBe(
            'Menu item 2'
          );
          expect(atom.contextMenu.templateForElement(element)[1].label).toBe(
            'Menu item 1'
          );
          expect(
            atom.contextMenu.templateForElement(element)[2]
          ).toBeUndefined();
        });
      });

      describe('when the menu file is empty', () => {
        it('does not throw an error on activation', async () => {
          await atom.packages.activatePackage('package-with-empty-menu');
          expect(atom.packages.isPackageActive('package-with-empty-menu')).toBe(
            true
          );
        });
      });
    });

    describe('stylesheet loading', () => {
      describe("when the metadata contains a 'styleSheets' manifest", () => {
        it('loads style sheets from the styles directory as specified by the manifest', async () => {
          const one = require.resolve(
            './fixtures/packages/package-with-style-sheets-manifest/styles/1.css'
          );
          const two = require.resolve(
            './fixtures/packages/package-with-style-sheets-manifest/styles/2.less'
          );
          const three = require.resolve(
            './fixtures/packages/package-with-style-sheets-manifest/styles/3.css'
          );

          expect(atom.themes.stylesheetElementForId(one)).toBeNull();
          expect(atom.themes.stylesheetElementForId(two)).toBeNull();
          expect(atom.themes.stylesheetElementForId(three)).toBeNull();

          await atom.packages.activatePackage(
            'package-with-style-sheets-manifest'
          );
          expect(atom.themes.stylesheetElementForId(one)).not.toBeNull();
          expect(atom.themes.stylesheetElementForId(two)).not.toBeNull();
          expect(atom.themes.stylesheetElementForId(three)).toBeNull();
          expect(
            getComputedStyle(document.querySelector('#jasmine-content'))
              .fontSize
          ).toBe('1px');
        });
      });

      describe("when the metadata does not contain a 'styleSheets' manifest", () => {
        it('loads all style sheets from the styles directory', async () => {
          const one = require.resolve(
            './fixtures/packages/package-with-styles/styles/1.css'
          );
          const two = require.resolve(
            './fixtures/packages/package-with-styles/styles/2.less'
          );
          const three = require.resolve(
            './fixtures/packages/package-with-styles/styles/3.test-context.css'
          );
          const four = require.resolve(
            './fixtures/packages/package-with-styles/styles/4.css'
          );

          expect(atom.themes.stylesheetElementForId(one)).toBeNull();
          expect(atom.themes.stylesheetElementForId(two)).toBeNull();
          expect(atom.themes.stylesheetElementForId(three)).toBeNull();
          expect(atom.themes.stylesheetElementForId(four)).toBeNull();

          await atom.packages.activatePackage('package-with-styles');
          expect(atom.themes.stylesheetElementForId(one)).not.toBeNull();
          expect(atom.themes.stylesheetElementForId(two)).not.toBeNull();
          expect(atom.themes.stylesheetElementForId(three)).not.toBeNull();
          expect(atom.themes.stylesheetElementForId(four)).not.toBeNull();
          expect(
            getComputedStyle(document.querySelector('#jasmine-content'))
              .fontSize
          ).toBe('3px');
        });
      });

      it("assigns the stylesheet's context based on the filename", async () => {
        await atom.packages.activatePackage('package-with-styles');

        let count = 0;
        for (let styleElement of atom.styles.getStyleElements()) {
          if (styleElement.sourcePath.match(/1.css/)) {
            expect(styleElement.context).toBe(undefined);
            count++;
          }

          if (styleElement.sourcePath.match(/2.less/)) {
            expect(styleElement.context).toBe(undefined);
            count++;
          }

          if (styleElement.sourcePath.match(/3.test-context.css/)) {
            expect(styleElement.context).toBe('test-context');
            count++;
          }

          if (styleElement.sourcePath.match(/4.css/)) {
            expect(styleElement.context).toBe(undefined);
            count++;
          }
        }

        expect(count).toBe(4);
      });
    });

    describe('grammar loading', () => {
      it("loads the package's grammars", async () => {
        await atom.packages.activatePackage('package-with-grammars');
        expect(atom.grammars.selectGrammar('a.alot').name).toBe('Alot');
        expect(atom.grammars.selectGrammar('a.alittle').name).toBe('Alittle');
      });

      it('loads any tree-sitter grammars defined in the package', async () => {
        atom.config.set('core.useTreeSitterParsers', true);
        await atom.packages.activatePackage('package-with-tree-sitter-grammar');
        const grammar = atom.grammars.selectGrammar('test.somelang');
        expect(grammar.name).toBe('Some Language');
        expect(grammar.languageModule.isFakeTreeSitterParser).toBe(true);
      });
    });

    describe('scoped-property loading', () => {
      it('loads the scoped properties', async () => {
        await atom.packages.activatePackage('package-with-settings');
        expect(
          atom.config.get('editor.increaseIndentPattern', {
            scope: ['.source.omg']
          })
        ).toBe('^a');
      });
    });

    describe('URI handler registration', () => {
      it("registers the package's specified URI handler", async () => {
        const uri = 'atom://package-with-uri-handler/some/url?with=args';
        const mod = require('./fixtures/packages/package-with-uri-handler');
        spyOn(mod, 'handleURI');
        spyOn(atom.packages, 'hasLoadedInitialPackages').andReturn(true);
        const activationPromise = atom.packages.activatePackage(
          'package-with-uri-handler'
        );
        atom.dispatchURIMessage(uri);
        await activationPromise;
        expect(mod.handleURI).toHaveBeenCalledWith(url.parse(uri, true), uri);
      });
    });

    describe('service registration', () => {
      it("registers the package's provided and consumed services", async () => {
        const consumerModule = require('./fixtures/packages/package-with-consumed-services');

        let firstServiceV3Disposed = false;
        let firstServiceV4Disposed = false;
        let secondServiceDisposed = false;
        spyOn(consumerModule, 'consumeFirstServiceV3').andReturn(
          new Disposable(() => {
            firstServiceV3Disposed = true;
          })
        );
        spyOn(consumerModule, 'consumeFirstServiceV4').andReturn(
          new Disposable(() => {
            firstServiceV4Disposed = true;
          })
        );
        spyOn(consumerModule, 'consumeSecondService').andReturn(
          new Disposable(() => {
            secondServiceDisposed = true;
          })
        );

        await atom.packages.activatePackage('package-with-consumed-services');
        await atom.packages.activatePackage('package-with-provided-services');
        expect(consumerModule.consumeFirstServiceV3.callCount).toBe(1);
        expect(consumerModule.consumeFirstServiceV3).toHaveBeenCalledWith(
          'first-service-v3'
        );
        expect(consumerModule.consumeFirstServiceV4).toHaveBeenCalledWith(
          'first-service-v4'
        );
        expect(consumerModule.consumeSecondService).toHaveBeenCalledWith(
          'second-service'
        );

        consumerModule.consumeFirstServiceV3.reset();
        consumerModule.consumeFirstServiceV4.reset();
        consumerModule.consumeSecondService.reset();

        await atom.packages.deactivatePackage('package-with-provided-services');
        expect(firstServiceV3Disposed).toBe(true);
        expect(firstServiceV4Disposed).toBe(true);
        expect(secondServiceDisposed).toBe(true);

        await atom.packages.deactivatePackage('package-with-consumed-services');
        await atom.packages.activatePackage('package-with-provided-services');
        expect(consumerModule.consumeFirstServiceV3).not.toHaveBeenCalled();
        expect(consumerModule.consumeFirstServiceV4).not.toHaveBeenCalled();
        expect(consumerModule.consumeSecondService).not.toHaveBeenCalled();
      });

      it('ignores provided and consumed services that do not exist', async () => {
        const addErrorHandler = jasmine.createSpy();
        atom.notifications.onDidAddNotification(addErrorHandler);

        await atom.packages.activatePackage(
          'package-with-missing-consumed-services'
        );
        await atom.packages.activatePackage(
          'package-with-missing-provided-services'
        );
        expect(
          atom.packages.isPackageActive(
            'package-with-missing-consumed-services'
          )
        ).toBe(true);
        expect(
          atom.packages.isPackageActive(
            'package-with-missing-provided-services'
          )
        ).toBe(true);
        expect(addErrorHandler.callCount).toBe(0);
      });
    });
  });

  describe('::serialize', () => {
    it('does not serialize packages that threw an error during activation', async () => {
      spyOn(atom, 'inSpecMode').andReturn(false);
      spyOn(console, 'warn');

      const badPack = await atom.packages.activatePackage(
        'package-that-throws-on-activate'
      );
      spyOn(badPack.mainModule, 'serialize').andCallThrough();

      atom.packages.serialize();
      expect(badPack.mainModule.serialize).not.toHaveBeenCalled();
    });

    it("absorbs exceptions that are thrown by the package module's serialize method", async () => {
      spyOn(console, 'error');

      await atom.packages.activatePackage('package-with-serialize-error');
      await atom.packages.activatePackage('package-with-serialization');
      atom.packages.serialize();
      expect(
        atom.packages.packageStates['package-with-serialize-error']
      ).toBeUndefined();
      expect(atom.packages.packageStates['package-with-serialization']).toEqual(
        { someNumber: 1 }
      );
      expect(console.error).toHaveBeenCalled();
    });
  });

  describe('::deactivatePackages()', () => {
    it('deactivates all packages but does not serialize them', async () => {
      const pack1 = await atom.packages.activatePackage(
        'package-with-deactivate'
      );
      const pack2 = await atom.packages.activatePackage(
        'package-with-serialization'
      );

      spyOn(pack1.mainModule, 'deactivate');
      spyOn(pack2.mainModule, 'serialize');
      await atom.packages.deactivatePackages();
      expect(pack1.mainModule.deactivate).toHaveBeenCalled();
      expect(pack2.mainModule.serialize).not.toHaveBeenCalled();
    });
  });

  describe('::deactivatePackage(id)', () => {
    afterEach(() => atom.packages.unloadPackages());

    it("calls `deactivate` on the package's main module if activate was successful", async () => {
      spyOn(atom, 'inSpecMode').andReturn(false);

      const pack = await atom.packages.activatePackage(
        'package-with-deactivate'
      );
      expect(
        atom.packages.isPackageActive('package-with-deactivate')
      ).toBeTruthy();
      spyOn(pack.mainModule, 'deactivate').andCallThrough();

      await atom.packages.deactivatePackage('package-with-deactivate');
      expect(pack.mainModule.deactivate).toHaveBeenCalled();
      expect(atom.packages.isPackageActive('package-with-module')).toBeFalsy();

      spyOn(console, 'warn');
      const badPack = await atom.packages.activatePackage(
        'package-that-throws-on-activate'
      );
      expect(
        atom.packages.isPackageActive('package-that-throws-on-activate')
      ).toBeTruthy();
      spyOn(badPack.mainModule, 'deactivate').andCallThrough();

      await atom.packages.deactivatePackage('package-that-throws-on-activate');
      expect(badPack.mainModule.deactivate).not.toHaveBeenCalled();
      expect(
        atom.packages.isPackageActive('package-that-throws-on-activate')
      ).toBeFalsy();
    });

    it("absorbs exceptions that are thrown by the package module's deactivate method", async () => {
      spyOn(console, 'error');
      await atom.packages.activatePackage('package-that-throws-on-deactivate');
      await atom.packages.deactivatePackage(
        'package-that-throws-on-deactivate'
      );
      expect(console.error).toHaveBeenCalled();
    });

    it("removes the package's grammars", async () => {
      await atom.packages.activatePackage('package-with-grammars');
      await atom.packages.deactivatePackage('package-with-grammars');
      expect(atom.grammars.selectGrammar('a.alot').name).toBe('Null Grammar');
      expect(atom.grammars.selectGrammar('a.alittle').name).toBe(
        'Null Grammar'
      );
    });

    it("removes the package's keymaps", async () => {
      await atom.packages.activatePackage('package-with-keymaps');
      await atom.packages.deactivatePackage('package-with-keymaps');
      expect(
        atom.keymaps.findKeyBindings({
          keystrokes: 'ctrl-z',
          target: createTestElement('test-1')
        })
      ).toHaveLength(0);
      expect(
        atom.keymaps.findKeyBindings({
          keystrokes: 'ctrl-z',
          target: createTestElement('test-2')
        })
      ).toHaveLength(0);
    });

    it("removes the package's stylesheets", async () => {
      await atom.packages.activatePackage('package-with-styles');
      await atom.packages.deactivatePackage('package-with-styles');

      const one = require.resolve(
        './fixtures/packages/package-with-style-sheets-manifest/styles/1.css'
      );
      const two = require.resolve(
        './fixtures/packages/package-with-style-sheets-manifest/styles/2.less'
      );
      const three = require.resolve(
        './fixtures/packages/package-with-style-sheets-manifest/styles/3.css'
      );
      expect(atom.themes.stylesheetElementForId(one)).not.toExist();
      expect(atom.themes.stylesheetElementForId(two)).not.toExist();
      expect(atom.themes.stylesheetElementForId(three)).not.toExist();
    });

    it("removes the package's scoped-properties", async () => {
      await atom.packages.activatePackage('package-with-settings');
      expect(
        atom.config.get('editor.increaseIndentPattern', {
          scope: ['.source.omg']
        })
      ).toBe('^a');

      await atom.packages.deactivatePackage('package-with-settings');
      expect(
        atom.config.get('editor.increaseIndentPattern', {
          scope: ['.source.omg']
        })
      ).toBeUndefined();
    });

    it('invokes ::onDidDeactivatePackage listeners with the deactivated package', async () => {
      await atom.packages.activatePackage('package-with-main');

      let deactivatedPackage;
      atom.packages.onDidDeactivatePackage(pack => {
        deactivatedPackage = pack;
      });

      await atom.packages.deactivatePackage('package-with-main');
      expect(deactivatedPackage.name).toBe('package-with-main');
    });
  });

  describe('::activate()', () => {
    beforeEach(() => {
      spyOn(atom, 'inSpecMode').andReturn(false);
      jasmine.snapshotDeprecations();
      spyOn(console, 'warn');
      atom.packages.loadPackages();

      const loadedPackages = atom.packages.getLoadedPackages();
      expect(loadedPackages.length).toBeGreaterThan(0);
    });

    afterEach(async () => {
      await atom.packages.deactivatePackages();
      atom.packages.unloadPackages();
      jasmine.restoreDeprecationsSnapshot();
    });

    it('sets hasActivatedInitialPackages', async () => {
      spyOn(atom.styles, 'getUserStyleSheetPath').andReturn(null);
      spyOn(atom.packages, 'activatePackages');
      expect(atom.packages.hasActivatedInitialPackages()).toBe(false);

      await atom.packages.activate();
      expect(atom.packages.hasActivatedInitialPackages()).toBe(true);
    });

    it('activates all the packages, and none of the themes', () => {
      const packageActivator = spyOn(atom.packages, 'activatePackages');
      const themeActivator = spyOn(atom.themes, 'activatePackages');

      atom.packages.activate();

      expect(packageActivator).toHaveBeenCalled();
      expect(themeActivator).toHaveBeenCalled();

      const packages = packageActivator.mostRecentCall.args[0];
      for (let pack of packages) {
        expect(['atom', 'textmate']).toContain(pack.getType());
      }

      const themes = themeActivator.mostRecentCall.args[0];
      themes.map(theme => expect(['theme']).toContain(theme.getType()));
    });

    it('calls callbacks registered with ::onDidActivateInitialPackages', async () => {
      const package1 = atom.packages.loadPackage('package-with-main');
      const package2 = atom.packages.loadPackage('package-with-index');
      const package3 = atom.packages.loadPackage(
        'package-with-activation-commands'
      );
      spyOn(atom.packages, 'getLoadedPackages').andReturn([
        package1,
        package2,
        package3
      ]);
      spyOn(atom.themes, 'activatePackages');

      atom.packages.activate();
      await new Promise(resolve =>
        atom.packages.onDidActivateInitialPackages(resolve)
      );

      jasmine.unspy(atom.packages, 'getLoadedPackages');
      expect(atom.packages.getActivePackages().includes(package1)).toBe(true);
      expect(atom.packages.getActivePackages().includes(package2)).toBe(true);
      expect(atom.packages.getActivePackages().includes(package3)).toBe(false);
    });
  });

  describe('::enablePackage(id) and ::disablePackage(id)', () => {
    describe('with packages', () => {
      it('enables a disabled package', async () => {
        const packageName = 'package-with-main';
        atom.config.pushAtKeyPath('core.disabledPackages', packageName);
        atom.packages.observeDisabledPackages();
        expect(atom.config.get('core.disabledPackages')).toContain(packageName);

        const pack = atom.packages.enablePackage(packageName);
        await new Promise(resolve =>
          atom.packages.onDidActivatePackage(resolve)
        );

        expect(atom.packages.getLoadedPackages()).toContain(pack);
        expect(atom.packages.getActivePackages()).toContain(pack);
        expect(atom.config.get('core.disabledPackages')).not.toContain(
          packageName
        );
      });

      it('disables an enabled package', async () => {
        const packageName = 'package-with-main';
        const pack = await atom.packages.activatePackage(packageName);

        atom.packages.observeDisabledPackages();
        expect(atom.config.get('core.disabledPackages')).not.toContain(
          packageName
        );
        await new Promise(resolve => {
          atom.packages.onDidDeactivatePackage(resolve);
          atom.packages.disablePackage(packageName);
        });

        expect(atom.packages.getActivePackages()).not.toContain(pack);
        expect(atom.config.get('core.disabledPackages')).toContain(packageName);
      });

      it('returns null if the package cannot be loaded', () => {
        spyOn(console, 'warn');
        expect(atom.packages.enablePackage('this-doesnt-exist')).toBeNull();
        expect(console.warn.callCount).toBe(1);
      });

      it('does not disable an already disabled package', () => {
        const packageName = 'package-with-main';
        atom.config.pushAtKeyPath('core.disabledPackages', packageName);
        atom.packages.observeDisabledPackages();
        expect(atom.config.get('core.disabledPackages')).toContain(packageName);

        atom.packages.disablePackage(packageName);
        const packagesDisabled = atom.config
          .get('core.disabledPackages')
          .filter(pack => pack === packageName);
        expect(packagesDisabled.length).toEqual(1);
      });
    });

    describe('with themes', () => {
      beforeEach(() => atom.themes.activateThemes());
      afterEach(() => atom.themes.deactivateThemes());

      it('enables and disables a theme', async () => {
        const packageName = 'theme-with-package-file';
        expect(atom.config.get('core.themes')).not.toContain(packageName);
        expect(atom.config.get('core.disabledPackages')).not.toContain(
          packageName
        );

        // enabling of theme
        const pack = atom.packages.enablePackage(packageName);
        await new Promise(resolve =>
          atom.packages.onDidActivatePackage(resolve)
        );
        expect(atom.packages.isPackageActive(packageName)).toBe(true);
        expect(atom.config.get('core.themes')).toContain(packageName);
        expect(atom.config.get('core.disabledPackages')).not.toContain(
          packageName
        );

        await new Promise(resolve => {
          atom.themes.onDidChangeActiveThemes(resolve);
          atom.packages.disablePackage(packageName);
        });

        expect(atom.packages.getActivePackages()).not.toContain(pack);
        expect(atom.config.get('core.themes')).not.toContain(packageName);
        expect(atom.config.get('core.themes')).not.toContain(packageName);
        expect(atom.config.get('core.disabledPackages')).not.toContain(
          packageName
        );
      });
    });
  });

  describe('::getAvailablePackageNames', () => {
    it('detects a symlinked package', () => {
      const packageSymLinkedSource = path.join(
        __dirname,
        'fixtures',
        'packages',
        'folder',
        'package-symlinked'
      );
      const destination = path.join(
        atom.packages.getPackageDirPaths()[0],
        'package-symlinked'
      );
      if (!fs.isDirectorySync(destination)) {
        fs.symlinkSync(packageSymLinkedSource, destination, 'junction');
      }
      const availablePackages = atom.packages.getAvailablePackageNames();
      expect(availablePackages.includes('package-symlinked')).toBe(true);
      fs.removeSync(destination);
    });
  });
});
