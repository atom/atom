const path = require('path');

const UIWatcher = require('../lib/ui-watcher');

const { conditionPromise } = require('./async-spec-helpers');

describe('UIWatcher', () => {
  let uiWatcher = null;

  beforeEach(() =>
    atom.packages.packageDirPaths.push(path.join(__dirname, 'fixtures'))
  );

  afterEach(() => uiWatcher && uiWatcher.destroy());

  describe("when a base theme's file changes", () => {
    beforeEach(() => {
      spyOn(atom.themes, 'resolveStylesheet').andReturn(
        path.join(__dirname, 'fixtures', 'static', 'atom.less')
      );
      uiWatcher = new UIWatcher();
    });

    it('reloads all the base styles', () => {
      spyOn(atom.themes, 'reloadBaseStylesheets');

      expect(uiWatcher.baseTheme.entities[0].getPath()).toContain(
        `${path.sep}static${path.sep}`
      );

      uiWatcher.baseTheme.entities[0].emitter.emit('did-change');
      expect(atom.themes.reloadBaseStylesheets).toHaveBeenCalled();
    });
  });

  it("watches all the style sheets in the theme's styles folder", async () => {
    const packagePath = path.join(
      __dirname,
      'fixtures',
      'package-with-styles-folder'
    );

    await atom.packages.activatePackage(packagePath);
    uiWatcher = new UIWatcher();

    const lastWatcher = uiWatcher.watchers[uiWatcher.watchers.length - 1];

    expect(lastWatcher.entities.length).toBe(4);
    expect(lastWatcher.entities[0].getPath()).toBe(
      path.join(packagePath, 'styles')
    );
    expect(lastWatcher.entities[1].getPath()).toBe(
      path.join(packagePath, 'styles', '3.css')
    );
    expect(lastWatcher.entities[2].getPath()).toBe(
      path.join(packagePath, 'styles', 'sub', '1.css')
    );
    expect(lastWatcher.entities[3].getPath()).toBe(
      path.join(packagePath, 'styles', 'sub', '2.less')
    );
  });

  describe('when a package stylesheet file changes', async () => {
    beforeEach(async () => {
      await atom.packages.activatePackage(
        path.join(__dirname, 'fixtures', 'package-with-styles-manifest')
      );
      uiWatcher = new UIWatcher();
    });

    it('reloads all package styles', () => {
      const pack = atom.packages.getActivePackages()[0];
      spyOn(pack, 'reloadStylesheets');

      uiWatcher.watchers[
        uiWatcher.watchers.length - 1
      ].entities[1].emitter.emit('did-change');

      expect(pack.reloadStylesheets).toHaveBeenCalled();
    });
  });

  describe('when a package does not have a stylesheet', () => {
    beforeEach(async () => {
      await atom.packages.activatePackage('package-with-index');
      uiWatcher = new UIWatcher();
    });

    it('does not create a PackageWatcher', () => {
      expect(uiWatcher.watchedPackages['package-with-index']).toBeUndefined();
    });
  });

  describe('when a package global file changes', () => {
    beforeEach(async () => {
      atom.config.set('core.themes', [
        'theme-with-ui-variables',
        'theme-with-multiple-imported-files'
      ]);

      await atom.themes.activateThemes();
      uiWatcher = new UIWatcher();
    });

    afterEach(() => atom.themes.deactivateThemes());

    it('reloads every package when the variables file changes', () => {
      let varEntity;
      for (const theme of atom.themes.getActiveThemes()) {
        spyOn(theme, 'reloadStylesheets');
      }

      for (const entity of uiWatcher.watchedThemes.get(
        'theme-with-multiple-imported-files'
      ).entities) {
        if (entity.getPath().indexOf('variables') > -1) varEntity = entity;
      }
      varEntity.emitter.emit('did-change');

      for (const theme of atom.themes.getActiveThemes()) {
        expect(theme.reloadStylesheets).toHaveBeenCalled();
      }
    });
  });

  describe('watcher lifecycle', () => {
    it('starts watching a package if it is activated after initial startup', async () => {
      uiWatcher = new UIWatcher();
      expect(uiWatcher.watchedPackages.size).toBe(0);

      await atom.packages.activatePackage(
        path.join(__dirname, 'fixtures', 'package-with-styles-folder')
      );
      expect(
        uiWatcher.watchedPackages.get('package-with-styles-folder')
      ).not.toBeUndefined();
    });

    it('unwatches a package after it is deactivated', async () => {
      await atom.packages.activatePackage(
        path.join(__dirname, 'fixtures', 'package-with-styles-folder')
      );
      uiWatcher = new UIWatcher();
      const watcher = uiWatcher.watchedPackages.get(
        'package-with-styles-folder'
      );
      expect(watcher).not.toBeUndefined();

      const watcherDestructionSpy = jasmine.createSpy('watcher-on-did-destroy');
      watcher.onDidDestroy(watcherDestructionSpy);

      await atom.packages.deactivatePackage('package-with-styles-folder');
      expect(
        uiWatcher.watchedPackages.get('package-with-styles-folder')
      ).toBeUndefined();
      expect(uiWatcher.watchedPackages.size).toBe(0);
      expect(watcherDestructionSpy).toHaveBeenCalled();
    });

    it('does not watch activated packages after the UI watcher has been destroyed', async () => {
      uiWatcher = new UIWatcher();
      uiWatcher.destroy();

      await atom.packages.activatePackage(
        path.join(__dirname, 'fixtures', 'package-with-styles-folder')
      );
      expect(uiWatcher.watchedPackages.size).toBe(0);
    });
  });

  describe('minimal theme packages', () => {
    let pack = null;
    beforeEach(async () => {
      atom.config.set('core.themes', [
        'theme-with-syntax-variables',
        'theme-with-index-less'
      ]);
      await atom.themes.activateThemes();
      uiWatcher = new UIWatcher();
      pack = atom.themes.getActiveThemes()[0];
    });

    afterEach(() => atom.themes.deactivateThemes());

    it('watches themes without a styles directory', () => {
      spyOn(pack, 'reloadStylesheets');
      spyOn(atom.themes, 'reloadBaseStylesheets');

      const watcher = uiWatcher.watchedThemes.get('theme-with-index-less');

      expect(watcher.entities.length).toBe(1);

      watcher.entities[0].emitter.emit('did-change');
      expect(pack.reloadStylesheets).toHaveBeenCalled();
      expect(atom.themes.reloadBaseStylesheets).not.toHaveBeenCalled();
    });
  });

  describe('theme packages', () => {
    let pack = null;
    beforeEach(async () => {
      atom.config.set('core.themes', [
        'theme-with-syntax-variables',
        'theme-with-multiple-imported-files'
      ]);

      await atom.themes.activateThemes();
      uiWatcher = new UIWatcher();
      pack = atom.themes.getActiveThemes()[0];
    });

    afterEach(() => atom.themes.deactivateThemes());

    it('reloads the theme when anything within the theme changes', () => {
      spyOn(pack, 'reloadStylesheets');
      spyOn(atom.themes, 'reloadBaseStylesheets');

      const watcher = uiWatcher.watchedThemes.get(
        'theme-with-multiple-imported-files'
      );

      expect(watcher.entities.length).toBe(6);

      watcher.entities[2].emitter.emit('did-change');
      expect(pack.reloadStylesheets).toHaveBeenCalled();
      expect(atom.themes.reloadBaseStylesheets).not.toHaveBeenCalled();

      watcher.entities[watcher.entities.length - 1].emitter.emit('did-change');
      expect(atom.themes.reloadBaseStylesheets).toHaveBeenCalled();
    });

    it('unwatches when a theme is deactivated', async () => {
      jasmine.useRealClock();

      atom.config.set('core.themes', []);
      await conditionPromise(
        () => !uiWatcher.watchedThemes['theme-with-multiple-imported-files']
      );
    });

    it('watches a new theme when it is deactivated', async () => {
      jasmine.useRealClock();

      atom.config.set('core.themes', [
        'theme-with-syntax-variables',
        'theme-with-package-file'
      ]);
      await conditionPromise(() =>
        uiWatcher.watchedThemes.get('theme-with-package-file')
      );

      pack = atom.themes.getActiveThemes()[0];
      spyOn(pack, 'reloadStylesheets');

      expect(pack.name).toBe('theme-with-package-file');

      const watcher = uiWatcher.watchedThemes.get('theme-with-package-file');
      watcher.entities[2].emitter.emit('did-change');
      expect(pack.reloadStylesheets).toHaveBeenCalled();
    });
  });
});
