const { conditionPromise } = require('./helpers/async-spec-helpers');
const MockUpdater = require('./mocks/updater');

describe('the status bar', () => {
  let atomVersion;
  let workspaceElement;

  beforeEach(async () => {
    let storage = {};

    spyOn(window.localStorage, 'setItem').andCallFake((key, value) => {
      storage[key] = value;
    });
    spyOn(window.localStorage, 'getItem').andCallFake(key => {
      return storage[key];
    });
    spyOn(atom, 'getVersion').andCallFake(() => {
      return atomVersion;
    });

    workspaceElement = atom.views.getView(atom.workspace);

    await atom.packages.activatePackage('status-bar');
    await atom.workspace.open('sample.js');
  });

  afterEach(async () => {
    await atom.packages.deactivatePackage('about');
    await atom.packages.deactivatePackage('status-bar');
  });

  describe('on a stable version', function() {
    beforeEach(async () => {
      atomVersion = '1.2.3';

      await atom.packages.activatePackage('about');
    });

    describe('with no update', () => {
      it('does not show the view', () => {
        expect(workspaceElement).not.toContain('.about-release-notes');
      });
    });

    describe('with an update', () => {
      it('shows the view when the update finishes downloading', () => {
        MockUpdater.finishDownloadingUpdate('42.0.0');
        expect(workspaceElement).toContain('.about-release-notes');
      });

      describe('clicking on the status', () => {
        it('opens the about page', async () => {
          MockUpdater.finishDownloadingUpdate('42.0.0');
          workspaceElement.querySelector('.about-release-notes').click();
          await conditionPromise(() =>
            workspaceElement.querySelector('.about')
          );
          expect(workspaceElement.querySelector('.about')).toExist();
        });
      });

      it('continues to show the squirrel until Atom is updated to the new version', async () => {
        MockUpdater.finishDownloadingUpdate('42.0.0');
        expect(workspaceElement).toContain('.about-release-notes');

        await atom.packages.deactivatePackage('about');
        expect(workspaceElement).not.toContain('.about-release-notes');

        await atom.packages.activatePackage('about');
        await Promise.resolve(); // Service consumption hooks are deferred until the next tick
        expect(workspaceElement).toContain('.about-release-notes');

        await atom.packages.deactivatePackage('about');
        expect(workspaceElement).not.toContain('.about-release-notes');

        atomVersion = '42.0.0';
        await atom.packages.activatePackage('about');

        await Promise.resolve(); // Service consumption hooks are deferred until the next tick
        expect(workspaceElement).not.toContain('.about-release-notes');
      });

      it('does not show the view if Atom is updated to a newer version than notified', async () => {
        MockUpdater.finishDownloadingUpdate('42.0.0');

        await atom.packages.deactivatePackage('about');

        atomVersion = '43.0.0';
        await atom.packages.activatePackage('about');

        await Promise.resolve(); // Service consumption hooks are deferred until the next tick
        expect(workspaceElement).not.toContain('.about-release-notes');
      });
    });
  });

  describe('on a beta version', function() {
    beforeEach(async () => {
      atomVersion = '1.2.3-beta4';

      await atom.packages.activatePackage('about');
    });

    describe('with no update', () => {
      it('does not show the view', () => {
        expect(workspaceElement).not.toContain('.about-release-notes');
      });
    });

    describe('with an update', () => {
      it('shows the view when the update finishes downloading', () => {
        MockUpdater.finishDownloadingUpdate('42.0.0');
        expect(workspaceElement).toContain('.about-release-notes');
      });

      describe('clicking on the status', () => {
        it('opens the about page', async () => {
          MockUpdater.finishDownloadingUpdate('42.0.0');
          workspaceElement.querySelector('.about-release-notes').click();
          await conditionPromise(() =>
            workspaceElement.querySelector('.about')
          );
          expect(workspaceElement.querySelector('.about')).toExist();
        });
      });

      it('continues to show the squirrel until Atom is updated to the new version', async () => {
        MockUpdater.finishDownloadingUpdate('42.0.0');
        expect(workspaceElement).toContain('.about-release-notes');

        await atom.packages.deactivatePackage('about');
        expect(workspaceElement).not.toContain('.about-release-notes');

        await atom.packages.activatePackage('about');
        await Promise.resolve(); // Service consumption hooks are deferred until the next tick
        expect(workspaceElement).toContain('.about-release-notes');

        await atom.packages.deactivatePackage('about');
        expect(workspaceElement).not.toContain('.about-release-notes');

        atomVersion = '42.0.0';
        await atom.packages.activatePackage('about');

        await Promise.resolve(); // Service consumption hooks are deferred until the next tick
        expect(workspaceElement).not.toContain('.about-release-notes');
      });

      it('does not show the view if Atom is updated to a newer version than notified', async () => {
        MockUpdater.finishDownloadingUpdate('42.0.0');

        await atom.packages.deactivatePackage('about');

        atomVersion = '43.0.0';
        await atom.packages.activatePackage('about');

        await Promise.resolve(); // Service consumption hooks are deferred until the next tick
        expect(workspaceElement).not.toContain('.about-release-notes');
      });
    });
  });

  describe('on a development version', function() {
    beforeEach(async () => {
      atomVersion = '1.2.3-dev-0123abcd';

      await atom.packages.activatePackage('about');
    });

    describe('with no update', () => {
      it('does not show the view', () => {
        expect(workspaceElement).not.toContain('.about-release-notes');
      });
    });

    describe('with a previously downloaded update', () => {
      it('does not show the view', () => {
        window.localStorage.setItem('about:version-available', '42.0.0');

        expect(workspaceElement).not.toContain('.about-release-notes');
      });
    });
  });
});
