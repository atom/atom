const os = require('os');
const path = require('path');
const updatePackageDependencies = require('../lib/update-package-dependencies');

describe('Update Package Dependencies', () => {
  let projectPath = null;

  beforeEach(() => {
    projectPath = __dirname;
    atom.project.setPaths([projectPath]);
  });

  describe('updating package dependencies', () => {
    let { command, args, stderr, exit, options } = {};
    beforeEach(() => {
      spyOn(updatePackageDependencies, 'runBufferedProcess').andCallFake(
        params => {
          ({ command, args, stderr, exit, options } = params);
          return true; // so that this.process isn't null
        }
      );
    });

    afterEach(() => {
      if (updatePackageDependencies.process) exit(0);
    });

    it('runs the `apm install` command', () => {
      updatePackageDependencies.update();

      expect(updatePackageDependencies.runBufferedProcess).toHaveBeenCalled();
      if (process.platform !== 'win32') {
        expect(command.endsWith('/apm')).toBe(true);
      } else {
        expect(command.endsWith('\\apm.cmd')).toBe(true);
      }
      expect(args).toEqual(['install', '--no-color']);
      expect(options.cwd).toEqual(projectPath);
    });

    it('only allows one apm process to be spawned at a time', () => {
      updatePackageDependencies.update();
      expect(updatePackageDependencies.runBufferedProcess.callCount).toBe(1);

      updatePackageDependencies.update();
      updatePackageDependencies.update();
      expect(updatePackageDependencies.runBufferedProcess.callCount).toBe(1);

      exit(0);
      updatePackageDependencies.update();
      expect(updatePackageDependencies.runBufferedProcess.callCount).toBe(2);
    });

    it('sets NODE_ENV to development in order to install devDependencies', () => {
      updatePackageDependencies.update();

      expect(options.env.NODE_ENV).toEqual('development');
    });

    it('adds a status bar tile', async () => {
      const statusBar = await atom.packages.activatePackage('status-bar');

      const activationPromise = atom.packages.activatePackage(
        'update-package-dependencies'
      );
      atom.commands.dispatch(
        atom.views.getView(atom.workspace),
        'update-package-dependencies:update'
      );
      const { mainModule } = await activationPromise;

      mainModule.update();

      let tile = statusBar.mainModule.statusBar
        .getRightTiles()
        .find(tile => tile.item.matches('update-package-dependencies-status'));
      expect(
        tile.item.classList.contains('update-package-dependencies-status')
      ).toBe(true);
      expect(tile.item.firstChild.classList.contains('loading')).toBe(true);

      exit(0);

      tile = statusBar.mainModule.statusBar
        .getRightTiles()
        .find(tile => tile.item.matches('update-package-dependencies-status'));
      expect(tile).toBeUndefined();
    });

    describe('when there are multiple project paths', () => {
      beforeEach(() => atom.project.setPaths([os.tmpdir(), projectPath]));

      it('uses the currently active one', async () => {
        await atom.workspace.open(path.join(projectPath, 'package.json'));

        updatePackageDependencies.update();
        expect(options.cwd).toEqual(projectPath);
      });
    });

    describe('when the update succeeds', () => {
      beforeEach(() => {
        updatePackageDependencies.update();
        exit(0);
      });

      it('shows a success notification message', () => {
        const notification = atom.notifications.getNotifications()[0];
        expect(notification.getType()).toEqual('success');
        expect(notification.getMessage()).toEqual(
          'Package dependencies updated'
        );
      });
    });

    describe('when the update fails', () => {
      beforeEach(() => {
        updatePackageDependencies.update();
        stderr('oh bother');
        exit(127);
      });

      it('shows a failure notification', () => {
        const notification = atom.notifications.getNotifications()[0];
        expect(notification.getType()).toEqual('error');
        expect(notification.getMessage()).toEqual(
          'Failed to update package dependencies'
        );
        expect(notification.getDetail()).toEqual('oh bother');
        expect(notification.isDismissable()).toBe(true);
      });
    });
  });

  describe('the `update-package-dependencies:update` command', () => {
    beforeEach(() => spyOn(updatePackageDependencies, 'update'));

    it('activates the package and updates package dependencies', async () => {
      const activationPromise = atom.packages.activatePackage(
        'update-package-dependencies'
      );
      atom.commands.dispatch(
        atom.views.getView(atom.workspace),
        'update-package-dependencies:update'
      );
      const { mainModule } = await activationPromise;
      expect(mainModule.update).toHaveBeenCalled();
    });
  });
});
