/* eslint-disable no-new */
const ChildProcess = require('child_process');
const path = require('path');
const fs = require('fs-plus');
const BufferedProcess = require('../src/buffered-process');

describe('BufferedProcess', function() {
  describe('when a bad command is specified', function() {
    let [oldOnError] = [];
    beforeEach(function() {
      oldOnError = window.onerror;
      window.onerror = jasmine.createSpy();
    });

    afterEach(() => (window.onerror = oldOnError));

    describe('when there is an error handler specified', function() {
      describe('when an error event is emitted by the process', () =>
        it('calls the error handler and does not throw an exception', function() {
          const bufferedProcess = new BufferedProcess({
            command: 'bad-command-nope1',
            args: ['nothing'],
            options: { shell: false }
          });

          const errorSpy = jasmine
            .createSpy()
            .andCallFake(error => error.handle());
          bufferedProcess.onWillThrowError(errorSpy);

          waitsFor(() => errorSpy.callCount > 0);

          runs(function() {
            expect(window.onerror).not.toHaveBeenCalled();
            expect(errorSpy).toHaveBeenCalled();
            expect(errorSpy.mostRecentCall.args[0].error.message).toContain(
              'spawn bad-command-nope1 ENOENT'
            );
          });
        }));

      describe('when an error is thrown spawning the process', () =>
        it('calls the error handler and does not throw an exception', function() {
          spyOn(ChildProcess, 'spawn').andCallFake(function() {
            const error = new Error('Something is really wrong');
            error.code = 'EAGAIN';
            throw error;
          });

          const bufferedProcess = new BufferedProcess({
            command: 'ls',
            args: [],
            options: {}
          });

          const errorSpy = jasmine
            .createSpy()
            .andCallFake(error => error.handle());
          bufferedProcess.onWillThrowError(errorSpy);

          waitsFor(() => errorSpy.callCount > 0);

          runs(function() {
            expect(window.onerror).not.toHaveBeenCalled();
            expect(errorSpy).toHaveBeenCalled();
            expect(errorSpy.mostRecentCall.args[0].error.message).toContain(
              'Something is really wrong'
            );
          });
        }));
    });

    describe('when there is not an error handler specified', () =>
      it('does throw an exception', function() {
        new BufferedProcess({
          command: 'bad-command-nope2',
          args: ['nothing'],
          options: { shell: false }
        });

        waitsFor(() => window.onerror.callCount > 0);

        runs(function() {
          expect(window.onerror).toHaveBeenCalled();
          expect(window.onerror.mostRecentCall.args[0]).toContain(
            'Failed to spawn command `bad-command-nope2`'
          );
          expect(window.onerror.mostRecentCall.args[4].name).toBe(
            'BufferedProcessError'
          );
        });
      }));
  });

  describe('when autoStart is false', () =>
    it('doesnt start unless start method is called', function() {
      let stdout = '';
      let stderr = '';
      const exitCallback = jasmine.createSpy('exit callback');
      const apmProcess = new BufferedProcess({
        autoStart: false,
        command: atom.packages.getApmPath(),
        args: ['-h'],
        options: {},
        stdout(lines) {
          stdout += lines;
        },
        stderr(lines) {
          stderr += lines;
        },
        exit: exitCallback
      });

      expect(apmProcess.started).not.toBe(true);
      apmProcess.start();
      expect(apmProcess.started).toBe(true);

      waitsFor(() => exitCallback.callCount === 1);
      runs(function() {
        expect(stderr).toContain('apm - Atom Package Manager');
        expect(stdout).toEqual('');
      });
    }));

  it('calls the specified stdout, stderr, and exit callbacks', function() {
    let stdout = '';
    let stderr = '';
    const exitCallback = jasmine.createSpy('exit callback');
    new BufferedProcess({
      command: atom.packages.getApmPath(),
      args: ['-h'],
      options: {},
      stdout(lines) {
        stdout += lines;
      },
      stderr(lines) {
        stderr += lines;
      },
      exit: exitCallback
    });

    waitsFor(() => exitCallback.callCount === 1);

    runs(function() {
      expect(stderr).toContain('apm - Atom Package Manager');
      expect(stdout).toEqual('');
    });
  });

  it('calls the specified stdout callback with whole lines', function() {
    const exitCallback = jasmine.createSpy('exit callback');
    const loremPath = require.resolve('./fixtures/lorem.txt');
    const content = fs.readFileSync(loremPath).toString();
    let stdout = '';
    let allLinesEndWithNewline = true;
    new BufferedProcess({
      command: process.platform === 'win32' ? 'type' : 'cat',
      args: [loremPath],
      options: {},
      stdout(lines) {
        const endsWithNewline = lines.charAt(lines.length - 1) === '\n';
        if (!endsWithNewline) {
          allLinesEndWithNewline = false;
        }
        stdout += lines;
      },
      exit: exitCallback
    });

    waitsFor(() => exitCallback.callCount === 1);

    runs(function() {
      expect(allLinesEndWithNewline).toBe(true);
      expect(stdout).toBe(content);
    });
  });

  describe('on Windows', function() {
    let originalPlatform = null;

    beforeEach(function() {
      // Prevent any commands from actually running and affecting the host
      spyOn(ChildProcess, 'spawn');
      originalPlatform = process.platform;
      Object.defineProperty(process, 'platform', { value: 'win32' });
    });

    afterEach(() =>
      Object.defineProperty(process, 'platform', { value: originalPlatform })
    );

    describe('when the explorer command is spawned on Windows', () =>
      it("doesn't quote arguments of the form /root,C...", function() {
        new BufferedProcess({
          command: 'explorer.exe',
          args: ['/root,C:\\foo']
        });
        expect(ChildProcess.spawn.argsForCall[0][1][3]).toBe(
          '"explorer.exe /root,C:\\foo"'
        );
      }));

    it('spawns the command using a cmd.exe wrapper when options.shell is undefined', function() {
      new BufferedProcess({ command: 'dir' });
      expect(path.basename(ChildProcess.spawn.argsForCall[0][0])).toBe(
        'cmd.exe'
      );
      expect(ChildProcess.spawn.argsForCall[0][1][0]).toBe('/s');
      expect(ChildProcess.spawn.argsForCall[0][1][1]).toBe('/d');
      expect(ChildProcess.spawn.argsForCall[0][1][2]).toBe('/c');
      expect(ChildProcess.spawn.argsForCall[0][1][3]).toBe('"dir"');
    });
  });
});
