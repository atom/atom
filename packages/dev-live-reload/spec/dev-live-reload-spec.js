describe('Dev Live Reload', () => {
  describe('package activation', () => {
    let [pack, mainModule] = [];

    beforeEach(() => {
      pack = atom.packages.loadPackage('dev-live-reload');
      pack.requireMainModule();
      mainModule = pack.mainModule;
      spyOn(mainModule, 'startWatching');
    });

    describe('when the window is not in dev mode', () => {
      beforeEach(() => spyOn(atom, 'inDevMode').andReturn(false));

      it('does not watch files', async () => {
        spyOn(atom.packages, 'hasActivatedInitialPackages').andReturn(true);

        await atom.packages.activatePackage('dev-live-reload');
        expect(mainModule.startWatching).not.toHaveBeenCalled();
      });
    });

    describe('when the window is in spec mode', () => {
      beforeEach(() => spyOn(atom, 'inSpecMode').andReturn(true));

      it('does not watch files', async () => {
        spyOn(atom.packages, 'hasActivatedInitialPackages').andReturn(true);

        await atom.packages.activatePackage('dev-live-reload');
        expect(mainModule.startWatching).not.toHaveBeenCalled();
      });
    });

    describe('when the window is in dev mode', () => {
      beforeEach(() => {
        spyOn(atom, 'inDevMode').andReturn(true);
        spyOn(atom, 'inSpecMode').andReturn(false);
      });

      it('watches files', async () => {
        spyOn(atom.packages, 'hasActivatedInitialPackages').andReturn(true);

        await atom.packages.activatePackage('dev-live-reload');
        expect(mainModule.startWatching).toHaveBeenCalled();
      });
    });

    describe('when the window is in both dev mode and spec mode', () => {
      beforeEach(() => {
        spyOn(atom, 'inDevMode').andReturn(true);
        spyOn(atom, 'inSpecMode').andReturn(true);
      });

      it('does not watch files', async () => {
        spyOn(atom.packages, 'hasActivatedInitialPackages').andReturn(true);

        await atom.packages.activatePackage('dev-live-reload');
        expect(mainModule.startWatching).not.toHaveBeenCalled();
      });
    });

    describe('when the package is activated before initial packages have been activated', () => {
      beforeEach(() => {
        spyOn(atom, 'inDevMode').andReturn(true);
        spyOn(atom, 'inSpecMode').andReturn(false);
      });

      it('waits until all initial packages have been activated before watching files', async () => {
        await atom.packages.activatePackage('dev-live-reload');
        expect(mainModule.startWatching).not.toHaveBeenCalled();

        atom.packages.emitter.emit('did-activate-initial-packages');
        expect(mainModule.startWatching).toHaveBeenCalled();
      });
    });
  });

  describe('package deactivation', () => {
    beforeEach(() => {
      spyOn(atom, 'inDevMode').andReturn(true);
      spyOn(atom, 'inSpecMode').andReturn(false);
    });

    it('stops watching all files', async () => {
      spyOn(atom.packages, 'hasActivatedInitialPackages').andReturn(true);
      const { mainModule } = await atom.packages.activatePackage(
        'dev-live-reload'
      );
      expect(mainModule.uiWatcher).not.toBeNull();

      spyOn(mainModule.uiWatcher, 'destroy');

      await atom.packages.deactivatePackage('dev-live-reload');
      expect(mainModule.uiWatcher.destroy).toHaveBeenCalled();
    });

    it('unsubscribes from the onDidActivateInitialPackages subscription if it is disabled before all initial packages are activated', async () => {
      const { mainModule } = await atom.packages.activatePackage(
        'dev-live-reload'
      );
      expect(mainModule.activatedDisposable.disposed).toBe(false);

      await atom.packages.deactivatePackage('dev-live-reload');
      expect(mainModule.activatedDisposable.disposed).toBe(true);

      spyOn(mainModule, 'startWatching');
      atom.packages.emitter.emit('did-activate-initial-packages');
      expect(mainModule.startWatching).not.toHaveBeenCalled();
    });

    it('removes its commands', async () => {
      spyOn(atom.packages, 'hasActivatedInitialPackages').andReturn(true);
      await atom.packages.activatePackage('dev-live-reload');
      expect(
        atom.commands
          .findCommands({ target: atom.views.getView(atom.workspace) })
          .filter(command => command.name.startsWith('dev-live-reload')).length
      ).toBeGreaterThan(0);

      await atom.packages.deactivatePackage('dev-live-reload');
      expect(
        atom.commands
          .findCommands({ target: atom.views.getView(atom.workspace) })
          .filter(command => command.name.startsWith('dev-live-reload')).length
      ).toBe(0);
    });
  });
});
