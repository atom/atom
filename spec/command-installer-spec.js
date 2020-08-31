const path = require('path');
const fs = require('fs-plus');
const temp = require('temp').track();
const CommandInstaller = require('../src/command-installer');

describe('CommandInstaller on #darwin', () => {
  let installer, resourcesPath, installationPath, atomBinPath, apmBinPath;

  beforeEach(() => {
    installationPath = temp.mkdirSync('atom-bin');

    resourcesPath = temp.mkdirSync('atom-app');
    atomBinPath = path.join(resourcesPath, 'app', 'atom.sh');
    apmBinPath = path.join(
      resourcesPath,
      'app',
      'apm',
      'node_modules',
      '.bin',
      'apm'
    );
    fs.writeFileSync(atomBinPath, '');
    fs.writeFileSync(apmBinPath, '');
    fs.chmodSync(atomBinPath, '755');
    fs.chmodSync(apmBinPath, '755');

    spyOn(CommandInstaller.prototype, 'getResourcesDirectory').andReturn(
      resourcesPath
    );
    spyOn(CommandInstaller.prototype, 'getInstallDirectory').andReturn(
      installationPath
    );
  });

  afterEach(() => {
    try {
      temp.cleanupSync();
    } catch (error) {}
  });

  it('shows an error dialog when installing commands interactively fails', () => {
    const appDelegate = jasmine.createSpyObj('appDelegate', ['confirm']);
    installer = new CommandInstaller(appDelegate);
    installer.initialize('2.0.2');
    spyOn(installer, 'installAtomCommand').andCallFake((__, callback) =>
      callback(new Error('an error'))
    );

    installer.installShellCommandsInteractively();

    expect(appDelegate.confirm.mostRecentCall.args[0]).toEqual({
      message: 'Failed to install shell commands',
      detail: 'an error'
    });

    appDelegate.confirm.reset();
    installer.installAtomCommand.andCallFake((__, callback) => callback());
    spyOn(installer, 'installApmCommand').andCallFake((__, callback) =>
      callback(new Error('another error'))
    );

    installer.installShellCommandsInteractively();

    expect(appDelegate.confirm.mostRecentCall.args[0]).toEqual({
      message: 'Failed to install shell commands',
      detail: 'another error'
    });
  });

  it('shows a success dialog when installing commands interactively succeeds', () => {
    const appDelegate = jasmine.createSpyObj('appDelegate', ['confirm']);
    installer = new CommandInstaller(appDelegate);
    installer.initialize('2.0.2');
    spyOn(installer, 'installAtomCommand').andCallFake((__, callback) =>
      callback(undefined, 'atom')
    );
    spyOn(installer, 'installApmCommand').andCallFake((__, callback) =>
      callback(undefined, 'apm')
    );

    installer.installShellCommandsInteractively();

    expect(appDelegate.confirm.mostRecentCall.args[0]).toEqual({
      message: 'Commands installed.',
      detail: 'The shell commands `atom` and `apm` are installed.'
    });
  });

  describe('when using a stable version of atom', () => {
    beforeEach(() => {
      installer = new CommandInstaller();
      installer.initialize('2.0.2');
    });

    it("symlinks the atom command as 'atom'", () => {
      const installedAtomPath = path.join(installationPath, 'atom');
      expect(fs.isFileSync(installedAtomPath)).toBeFalsy();

      waitsFor(done => {
        installer.installAtomCommand(false, error => {
          expect(error).toBeNull();
          expect(fs.realpathSync(installedAtomPath)).toBe(
            fs.realpathSync(atomBinPath)
          );
          expect(fs.isExecutableSync(installedAtomPath)).toBe(true);
          expect(fs.isFileSync(path.join(installationPath, 'atom-beta'))).toBe(
            false
          );
          done();
        });
      });
    });

    it("symlinks the apm command as 'apm'", () => {
      const installedApmPath = path.join(installationPath, 'apm');
      expect(fs.isFileSync(installedApmPath)).toBeFalsy();

      waitsFor(done => {
        installer.installApmCommand(false, error => {
          expect(error).toBeNull();
          expect(fs.realpathSync(installedApmPath)).toBe(
            fs.realpathSync(apmBinPath)
          );
          expect(fs.isExecutableSync(installedApmPath)).toBeTruthy();
          expect(fs.isFileSync(path.join(installationPath, 'apm-beta'))).toBe(
            false
          );
          done();
        });
      });
    });
  });

  describe('when using a beta version of atom', () => {
    beforeEach(() => {
      installer = new CommandInstaller();
      installer.initialize('2.2.0-beta.0');
    });

    it("symlinks the atom command as 'atom-beta'", () => {
      const installedAtomPath = path.join(installationPath, 'atom-beta');
      expect(fs.isFileSync(installedAtomPath)).toBeFalsy();

      waitsFor(done => {
        installer.installAtomCommand(false, error => {
          expect(error).toBeNull();
          expect(fs.realpathSync(installedAtomPath)).toBe(
            fs.realpathSync(atomBinPath)
          );
          expect(fs.isExecutableSync(installedAtomPath)).toBe(true);
          expect(fs.isFileSync(path.join(installationPath, 'atom'))).toBe(
            false
          );
          done();
        });
      });
    });

    it("symlinks the apm command as 'apm-beta'", () => {
      const installedApmPath = path.join(installationPath, 'apm-beta');
      expect(fs.isFileSync(installedApmPath)).toBeFalsy();

      waitsFor(done => {
        installer.installApmCommand(false, error => {
          expect(error).toBeNull();
          expect(fs.realpathSync(installedApmPath)).toBe(
            fs.realpathSync(apmBinPath)
          );
          expect(fs.isExecutableSync(installedApmPath)).toBeTruthy();
          expect(fs.isFileSync(path.join(installationPath, 'apm'))).toBe(false);
          done();
        });
      });
    });
  });

  describe('when using a nightly version of atom', () => {
    beforeEach(() => {
      installer = new CommandInstaller();
      installer.initialize('2.2.0-nightly0');
    });

    it("symlinks the atom command as 'atom-nightly'", () => {
      const installedAtomPath = path.join(installationPath, 'atom-nightly');
      expect(fs.isFileSync(installedAtomPath)).toBeFalsy();

      waitsFor(done => {
        installer.installAtomCommand(false, error => {
          expect(error).toBeNull();
          expect(fs.realpathSync(installedAtomPath)).toBe(
            fs.realpathSync(atomBinPath)
          );
          expect(fs.isExecutableSync(installedAtomPath)).toBe(true);
          expect(fs.isFileSync(path.join(installationPath, 'atom'))).toBe(
            false
          );
          done();
        });
      });
    });

    it("symlinks the apm command as 'apm-nightly'", () => {
      const installedApmPath = path.join(installationPath, 'apm-nightly');
      expect(fs.isFileSync(installedApmPath)).toBeFalsy();

      waitsFor(done => {
        installer.installApmCommand(false, error => {
          expect(error).toBeNull();
          expect(fs.realpathSync(installedApmPath)).toBe(
            fs.realpathSync(apmBinPath)
          );
          expect(fs.isExecutableSync(installedApmPath)).toBeTruthy();
          expect(fs.isFileSync(path.join(installationPath, 'nightly'))).toBe(
            false
          );
          done();
        });
      });
    });
  });
});
