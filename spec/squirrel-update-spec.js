const electron = require('electron');
const fs = require('fs-plus');
const path = require('path');
const temp = require('temp').track();

electron.app = {
  getName() {
    return 'Atom';
  },
  getVersion() {
    return '1.0.0';
  },
  getPath() {
    return '/tmp/atom.exe';
  }
};

const SquirrelUpdate = require('../src/main-process/squirrel-update');
const Spawner = require('../src/main-process/spawner');
const WinShell = require('../src/main-process/win-shell');

// Run passed callback as Spawner.spawn() would do
const invokeCallback = function(callback) {
  const error = null;
  const stdout = '';
  return typeof callback === 'function' ? callback(error, stdout) : undefined;
};

describe('Windows Squirrel Update', function() {
  let tempHomeDirectory = null;

  beforeEach(function() {
    // Prevent the actual home directory from being manipulated
    tempHomeDirectory = temp.mkdirSync('atom-temp-home-');
    spyOn(fs, 'getHomeDirectory').andReturn(tempHomeDirectory);

    // Prevent any spawned command from actually running and affecting the host
    spyOn(Spawner, 'spawn').andCallFake((
      command,
      args,
      callback // do nothing on command, just run passed callback
    ) => invokeCallback(callback));

    // Prevent any actual change to Windows Shell
    class FakeShellOption {
      isRegistered(callback) {
        return callback(true);
      }
      register(callback) {
        return callback(null);
      }
      deregister(callback) {
        return callback(null, true);
      }
      update(callback) {
        return callback(null);
      }
    }
    WinShell.fileHandler = new FakeShellOption();
    WinShell.fileContextMenu = new FakeShellOption();
    WinShell.folderContextMenu = new FakeShellOption();
    WinShell.folderBackgroundContextMenu = new FakeShellOption();
    electron.app.quit = jasmine.createSpy('quit');
  });

  afterEach(function() {
    electron.app.quit.reset();
    try {
      temp.cleanupSync();
    } catch (error) {}
  });

  it('quits the app on all squirrel events', function() {
    expect(SquirrelUpdate.handleStartupEvent('--squirrel-install')).toBe(true);

    waitsFor(() => electron.app.quit.callCount === 1);

    runs(function() {
      electron.app.quit.reset();
      expect(SquirrelUpdate.handleStartupEvent('--squirrel-updated')).toBe(
        true
      );
    });

    waitsFor(() => electron.app.quit.callCount === 1);

    runs(function() {
      electron.app.quit.reset();
      expect(SquirrelUpdate.handleStartupEvent('--squirrel-uninstall')).toBe(
        true
      );
    });

    waitsFor(() => electron.app.quit.callCount === 1);

    runs(function() {
      electron.app.quit.reset();
      expect(SquirrelUpdate.handleStartupEvent('--squirrel-obsolete')).toBe(
        true
      );
    });

    waitsFor(() => electron.app.quit.callCount === 1);

    runs(() =>
      expect(SquirrelUpdate.handleStartupEvent('--not-squirrel')).toBe(false)
    );
  });

  describe('Desktop shortcut', function() {
    let desktopShortcutPath = '/non/existing/path';

    beforeEach(function() {
      desktopShortcutPath = path.join(tempHomeDirectory, 'Desktop', 'Atom.lnk');

      jasmine.unspy(Spawner, 'spawn');
      spyOn(Spawner, 'spawn').andCallFake(function(command, args, callback) {
        if (
          path.basename(command) === 'Update.exe' &&
          (args != null ? args[0] : undefined) === '--createShortcut' &&
          (args != null ? args[3].match(/Desktop/i) : undefined)
        ) {
          fs.writeFileSync(desktopShortcutPath, '');
        } else {
        }
        // simply ignore other commands

        invokeCallback(callback);
      });
    });

    it('does not exist before install', () =>
      expect(fs.existsSync(desktopShortcutPath)).toBe(false));

    describe('on install', function() {
      beforeEach(function() {
        SquirrelUpdate.handleStartupEvent('--squirrel-install');
        waitsFor(() => electron.app.quit.callCount === 1);
      });

      it('creates desktop shortcut', () =>
        expect(fs.existsSync(desktopShortcutPath)).toBe(true));

      describe('when shortcut is deleted and then app is updated', function() {
        beforeEach(function() {
          fs.removeSync(desktopShortcutPath);
          expect(fs.existsSync(desktopShortcutPath)).toBe(false);

          SquirrelUpdate.handleStartupEvent('--squirrel-updated');
          waitsFor(() => electron.app.quit.callCount === 2);
        });

        it('does not recreate shortcut', () =>
          expect(fs.existsSync(desktopShortcutPath)).toBe(false));
      });

      describe('when shortcut is kept and app is updated', function() {
        beforeEach(function() {
          SquirrelUpdate.handleStartupEvent('--squirrel-updated');
          waitsFor(() => electron.app.quit.callCount === 2);
        });

        it('still has desktop shortcut', () =>
          expect(fs.existsSync(desktopShortcutPath)).toBe(true));
      });
    });
  });
});
