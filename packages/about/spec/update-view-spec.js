const { shell } = require('electron');
const main = require('../lib/main');
const AboutView = require('../lib/components/about-view');
const UpdateView = require('../lib/components/update-view');
const MockUpdater = require('./mocks/updater');

describe('UpdateView', () => {
  let aboutElement;
  let updateManager;
  let workspaceElement;
  let scheduler;

  beforeEach(async () => {
    let storage = {};

    spyOn(window.localStorage, 'setItem').andCallFake((key, value) => {
      storage[key] = value;
    });
    spyOn(window.localStorage, 'getItem').andCallFake(key => {
      return storage[key];
    });

    workspaceElement = atom.views.getView(atom.workspace);
    await atom.packages.activatePackage('about');
    spyOn(atom.autoUpdater, 'getState').andReturn('idle');
    spyOn(atom.autoUpdater, 'checkForUpdate');
    spyOn(atom.autoUpdater, 'platformSupportsUpdates').andReturn(true);
  });

  describe('when the About page is open', () => {
    beforeEach(async () => {
      jasmine.attachToDOM(workspaceElement);
      await atom.workspace.open('atom://about');
      aboutElement = workspaceElement.querySelector('.about');
      updateManager = main.model.state.updateManager;
      scheduler = AboutView.getScheduler();
    });

    describe('when the updates are not supported by the platform', () => {
      beforeEach(async () => {
        atom.autoUpdater.platformSupportsUpdates.andReturn(false);
        updateManager.resetState();
        await scheduler.getNextUpdatePromise();
      });

      it('hides the auto update UI and shows the update instructions link', async () => {
        expect(
          aboutElement.querySelector('.about-update-action-button')
        ).not.toBeVisible();
        expect(
          aboutElement.querySelector('.about-auto-updates')
        ).not.toBeVisible();
      });

      it('opens the update instructions page when the instructions link is clicked', async () => {
        spyOn(shell, 'openExternal');
        let link = aboutElement.querySelector(
          '.app-unsupported .about-updates-instructions'
        );
        link.click();

        let args = shell.openExternal.mostRecentCall.args;
        expect(shell.openExternal).toHaveBeenCalled();
        expect(args[0]).toContain('installing-atom');
      });
    });

    describe('when updates are supported by the platform', () => {
      beforeEach(async () => {
        atom.autoUpdater.platformSupportsUpdates.andReturn(true);
        updateManager.resetState();
        await scheduler.getNextUpdatePromise();
      });

      it('shows the auto update UI', () => {
        expect(aboutElement.querySelector('.about-updates')).toBeVisible();
      });

      it('shows the correct panels when the app checks for updates and there is no update available', async () => {
        expect(
          aboutElement.querySelector('.about-default-update-message')
        ).toBeVisible();

        MockUpdater.checkForUpdate();
        await scheduler.getNextUpdatePromise();
        expect(aboutElement.querySelector('.app-up-to-date')).not.toBeVisible();
        expect(
          aboutElement.querySelector('.app-checking-for-updates')
        ).toBeVisible();

        MockUpdater.updateNotAvailable();
        await scheduler.getNextUpdatePromise();
        expect(aboutElement.querySelector('.app-up-to-date')).toBeVisible();
        expect(
          aboutElement.querySelector('.app-checking-for-updates')
        ).not.toBeVisible();
      });

      it('shows the correct panels when the app checks for updates and encounters an error', async () => {
        expect(
          aboutElement.querySelector('.about-default-update-message')
        ).toBeVisible();

        MockUpdater.checkForUpdate();
        await scheduler.getNextUpdatePromise();
        expect(aboutElement.querySelector('.app-up-to-date')).not.toBeVisible();
        expect(
          aboutElement.querySelector('.app-checking-for-updates')
        ).toBeVisible();

        spyOn(atom.autoUpdater, 'getErrorMessage').andReturn(
          'an error message'
        );
        MockUpdater.updateError();
        await scheduler.getNextUpdatePromise();
        expect(aboutElement.querySelector('.app-update-error')).toBeVisible();
        expect(
          aboutElement.querySelector('.app-error-message').textContent
        ).toBe('an error message');
        expect(
          aboutElement.querySelector('.app-checking-for-updates')
        ).not.toBeVisible();
        expect(
          aboutElement.querySelector('.about-update-action-button').disabled
        ).toBe(false);
        expect(
          aboutElement.querySelector('.about-update-action-button').textContent
        ).toBe('Check now');
      });

      it('shows the correct panels and button states when the app checks for updates and an update is downloaded', async () => {
        expect(
          aboutElement.querySelector('.about-default-update-message')
        ).toBeVisible();
        expect(
          aboutElement.querySelector('.about-update-action-button').disabled
        ).toBe(false);
        expect(
          aboutElement.querySelector('.about-update-action-button').textContent
        ).toBe('Check now');

        MockUpdater.checkForUpdate();
        await scheduler.getNextUpdatePromise();

        expect(aboutElement.querySelector('.app-up-to-date')).not.toBeVisible();
        expect(
          aboutElement.querySelector('.app-checking-for-updates')
        ).toBeVisible();
        expect(
          aboutElement.querySelector('.about-update-action-button').disabled
        ).toBe(true);
        expect(
          aboutElement.querySelector('.about-update-action-button').textContent
        ).toBe('Check now');

        MockUpdater.downloadUpdate();
        await scheduler.getNextUpdatePromise();
        expect(
          aboutElement.querySelector('.app-checking-for-updates')
        ).not.toBeVisible();
        expect(
          aboutElement.querySelector('.app-downloading-update')
        ).toBeVisible();
        // TODO: at some point it would be nice to be able to cancel an update download, and then this would be a cancel button
        expect(
          aboutElement.querySelector('.about-update-action-button').disabled
        ).toBe(true);
        expect(
          aboutElement.querySelector('.about-update-action-button').textContent
        ).toBe('Check now');

        MockUpdater.finishDownloadingUpdate('42.0.0');
        await scheduler.getNextUpdatePromise();
        expect(
          aboutElement.querySelector('.app-downloading-update')
        ).not.toBeVisible();
        expect(
          aboutElement.querySelector('.app-update-available-to-install')
        ).toBeVisible();

        expect(
          aboutElement.querySelector(
            '.app-update-available-to-install .about-updates-version'
          ).textContent
        ).toBe('42.0.0');
        expect(
          aboutElement.querySelector('.about-update-action-button').disabled
        ).toBe(false);
        expect(
          aboutElement.querySelector('.about-update-action-button').textContent
        ).toBe('Restart and install');
      });

      it('opens the release notes for the downloaded release when the release notes link are clicked', async () => {
        MockUpdater.finishDownloadingUpdate('1.2.3');
        await scheduler.getNextUpdatePromise();

        spyOn(shell, 'openExternal');
        let link = aboutElement.querySelector(
          '.app-update-available-to-install .about-updates-release-notes'
        );
        link.click();

        let args = shell.openExternal.mostRecentCall.args;
        expect(shell.openExternal).toHaveBeenCalled();
        expect(args[0]).toContain('/v1.2.3');
      });

      it('executes checkForUpdate() when the check for update button is clicked', () => {
        let button = aboutElement.querySelector('.about-update-action-button');
        button.click();
        expect(atom.autoUpdater.checkForUpdate).toHaveBeenCalled();
      });

      it('executes restartAndInstallUpdate() when the restart and install button is clicked', async () => {
        spyOn(atom.autoUpdater, 'restartAndInstallUpdate');
        MockUpdater.finishDownloadingUpdate('42.0.0');
        await scheduler.getNextUpdatePromise();

        let button = aboutElement.querySelector('.about-update-action-button');
        button.click();
        expect(atom.autoUpdater.restartAndInstallUpdate).toHaveBeenCalled();
      });

      it("starts in the same state as atom's AutoUpdateManager", async () => {
        atom.autoUpdater.getState.andReturn('downloading');
        updateManager.resetState();

        await scheduler.getNextUpdatePromise();
        expect(
          aboutElement.querySelector('.app-checking-for-updates')
        ).not.toBeVisible();
        expect(
          aboutElement.querySelector('.app-downloading-update')
        ).toBeVisible();
        expect(
          aboutElement.querySelector('.about-update-action-button').disabled
        ).toBe(true);
        expect(
          aboutElement.querySelector('.about-update-action-button').textContent
        ).toBe('Check now');
      });

      describe('when core.automaticallyUpdate is toggled', () => {
        beforeEach(async () => {
          expect(atom.config.get('core.automaticallyUpdate')).toBe(true);
          atom.autoUpdater.checkForUpdate.reset();
        });

        it('shows the auto update UI', async () => {
          expect(
            aboutElement.querySelector('.about-auto-updates input').checked
          ).toBe(true);
          expect(
            aboutElement.querySelector('.about-default-update-message')
          ).toBeVisible();
          expect(
            aboutElement.querySelector('.about-default-update-message')
              .textContent
          ).toBe('Atom will check for updates automatically');

          atom.config.set('core.automaticallyUpdate', false);
          await scheduler.getNextUpdatePromise();

          expect(
            aboutElement.querySelector('.about-auto-updates input').checked
          ).toBe(false);
          expect(
            aboutElement.querySelector('.about-default-update-message')
          ).toBeVisible();
          expect(
            aboutElement.querySelector('.about-default-update-message')
              .textContent
          ).toBe('Automatic updates are disabled please check manually');
        });

        it('updates config and the UI when the checkbox is used to toggle', async () => {
          expect(
            aboutElement.querySelector('.about-auto-updates input').checked
          ).toBe(true);

          aboutElement.querySelector('.about-auto-updates input').click();
          await scheduler.getNextUpdatePromise();

          expect(atom.config.get('core.automaticallyUpdate')).toBe(false);
          expect(
            aboutElement.querySelector('.about-auto-updates input').checked
          ).toBe(false);
          expect(
            aboutElement.querySelector('.about-default-update-message')
          ).toBeVisible();
          expect(
            aboutElement.querySelector('.about-default-update-message')
              .textContent
          ).toBe('Automatic updates are disabled please check manually');

          aboutElement.querySelector('.about-auto-updates input').click();
          await scheduler.getNextUpdatePromise();

          expect(atom.config.get('core.automaticallyUpdate')).toBe(true);
          expect(
            aboutElement.querySelector('.about-auto-updates input').checked
          ).toBe(true);
          expect(
            aboutElement.querySelector('.about-default-update-message')
          ).toBeVisible();
          expect(
            aboutElement.querySelector('.about-default-update-message')
              .textContent
          ).toBe('Atom will check for updates automatically');
        });

        describe('checking for updates', function() {
          afterEach(() => {
            this.updateView = null;
          });

          it('checks for update when the about page is shown', () => {
            expect(atom.autoUpdater.checkForUpdate).not.toHaveBeenCalled();

            this.updateView = new UpdateView({
              updateManager: updateManager,
              availableVersion: '9999.0.0',
              viewUpdateReleaseNotes: () => {}
            });

            expect(atom.autoUpdater.checkForUpdate).toHaveBeenCalled();
          });

          it('does not check for update when the about page is shown and the update manager is not in the idle state', () => {
            atom.autoUpdater.getState.andReturn('downloading');
            updateManager.resetState();
            expect(atom.autoUpdater.checkForUpdate).not.toHaveBeenCalled();

            this.updateView = new UpdateView({
              updateManager: updateManager,
              availableVersion: '9999.0.0',
              viewUpdateReleaseNotes: () => {}
            });

            expect(atom.autoUpdater.checkForUpdate).not.toHaveBeenCalled();
          });

          it('does not check for update when the about page is shown and auto updates are turned off', () => {
            atom.config.set('core.automaticallyUpdate', false);
            expect(atom.autoUpdater.checkForUpdate).not.toHaveBeenCalled();

            this.updateView = new UpdateView({
              updateManager: updateManager,
              availableVersion: '9999.0.0',
              viewUpdateReleaseNotes: () => {}
            });

            expect(atom.autoUpdater.checkForUpdate).not.toHaveBeenCalled();
          });
        });
      });
    });
  });

  describe('when the About page is not open and an update is downloaded', () => {
    it('should display the new version when it is opened', async () => {
      MockUpdater.finishDownloadingUpdate('42.0.0');

      jasmine.attachToDOM(workspaceElement);
      await atom.workspace.open('atom://about');
      aboutElement = workspaceElement.querySelector('.about');
      updateManager = main.model.state.updateManager;
      scheduler = AboutView.getScheduler();

      expect(
        aboutElement.querySelector('.app-update-available-to-install')
      ).toBeVisible();
      expect(
        aboutElement.querySelector(
          '.app-update-available-to-install .about-updates-version'
        ).textContent
      ).toBe('42.0.0');
      expect(
        aboutElement.querySelector('.about-update-action-button').disabled
      ).toBe(false);
      expect(
        aboutElement.querySelector('.about-update-action-button').textContent
      ).toBe('Restart and install');
    });
  });
});
