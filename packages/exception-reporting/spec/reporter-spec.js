const Reporter = require('../lib/reporter');
const semver = require('semver');
const os = require('os');
const path = require('path');
const fs = require('fs-plus');
let osVersion = `${os.platform()}-${os.arch()}-${os.release()}`;

let getReleaseChannel = version => {
  return version.indexOf('beta') > -1
    ? 'beta'
    : version.indexOf('dev') > -1
    ? 'dev'
    : 'stable';
};

describe('Reporter', () => {
  let reporter,
    requests,
    initialStackTraceLimit,
    initialFsGetHomeDirectory,
    mockActivePackages;

  beforeEach(() => {
    reporter = new Reporter({
      request: (url, options) => requests.push(Object.assign({ url }, options)),
      alwaysReport: true,
      reportPreviousErrors: false
    });
    requests = [];
    mockActivePackages = [];
    spyOn(atom.packages, 'getActivePackages').andCallFake(
      () => mockActivePackages
    );

    initialStackTraceLimit = Error.stackTraceLimit;
    Error.stackTraceLimit = 1;

    initialFsGetHomeDirectory = fs.getHomeDirectory;
  });

  afterEach(() => {
    fs.getHomeDirectory = initialFsGetHomeDirectory;
    Error.stackTraceLimit = initialStackTraceLimit;
  });

  describe('.reportUncaughtException(error)', () => {
    it('posts errors originated inside Atom Core to BugSnag', () => {
      const repositoryRootPath = path.join(__dirname, '..');
      reporter = new Reporter({
        request: (url, options) =>
          requests.push(Object.assign({ url }, options)),
        alwaysReport: true,
        reportPreviousErrors: false,
        resourcePath: repositoryRootPath
      });

      let error = new Error();
      Error.captureStackTrace(error);
      reporter.reportUncaughtException(error);
      let [lineNumber, columnNumber] = error.stack
        .match(/.js:(\d+):(\d+)/)
        .slice(1)
        .map(s => parseInt(s));

      expect(requests.length).toBe(1);
      let [request] = requests;
      expect(request.method).toBe('POST');
      expect(request.url).toBe('https://notify.bugsnag.com');
      expect(request.headers.get('Content-Type')).toBe('application/json');
      let body = JSON.parse(request.body);
      // Delete `inProject` field because tests may fail when run as part of Atom core
      // (i.e. when this test file will be located under `node_modules/exception-reporting/spec`)
      delete body.events[0].exceptions[0].stacktrace[0].inProject;

      expect(body).toEqual({
        apiKey: Reporter.API_KEY,
        notifier: {
          name: 'Atom',
          version: Reporter.LIB_VERSION,
          url: 'https://www.atom.io'
        },
        events: [
          {
            payloadVersion: '2',
            exceptions: [
              {
                errorClass: 'Error',
                message: '',
                stacktrace: [
                  {
                    method: semver.gt(process.versions.electron, '1.6.0')
                      ? 'Spec.it'
                      : 'it',
                    file: 'spec/reporter-spec.js',
                    lineNumber: lineNumber,
                    columnNumber: columnNumber
                  }
                ]
              }
            ],
            severity: 'error',
            user: {},
            app: {
              version: atom.getVersion(),
              releaseStage: getReleaseChannel(atom.getVersion())
            },
            device: {
              osVersion: osVersion
            }
          }
        ]
      });
    });

    it('posts errors originated outside Atom Core to BugSnag', () => {
      fs.getHomeDirectory = () => path.join(__dirname, '..', '..');

      let error = new Error();
      Error.captureStackTrace(error);
      reporter.reportUncaughtException(error);
      let [lineNumber, columnNumber] = error.stack
        .match(/.js:(\d+):(\d+)/)
        .slice(1)
        .map(s => parseInt(s));

      expect(requests.length).toBe(1);
      let [request] = requests;
      expect(request.method).toBe('POST');
      expect(request.url).toBe('https://notify.bugsnag.com');
      expect(request.headers.get('Content-Type')).toBe('application/json');
      let body = JSON.parse(request.body);
      // Delete `inProject` field because tests may fail when run as part of Atom core
      // (i.e. when this test file will be located under `node_modules/exception-reporting/spec`)
      delete body.events[0].exceptions[0].stacktrace[0].inProject;

      expect(body).toEqual({
        apiKey: Reporter.API_KEY,
        notifier: {
          name: 'Atom',
          version: Reporter.LIB_VERSION,
          url: 'https://www.atom.io'
        },
        events: [
          {
            payloadVersion: '2',
            exceptions: [
              {
                errorClass: 'Error',
                message: '',
                stacktrace: [
                  {
                    method: semver.gt(process.versions.electron, '1.6.0')
                      ? 'Spec.it'
                      : 'it',
                    file: '~/exception-reporting/spec/reporter-spec.js',
                    lineNumber: lineNumber,
                    columnNumber: columnNumber
                  }
                ]
              }
            ],
            severity: 'error',
            user: {},
            app: {
              version: atom.getVersion(),
              releaseStage: getReleaseChannel(atom.getVersion())
            },
            device: {
              osVersion: osVersion
            }
          }
        ]
      });
    });

    describe('when the error object has `privateMetadata` and `privateMetadataDescription` fields', () => {
      let [error, notification] = [];

      beforeEach(() => {
        atom.notifications.clear();
        spyOn(atom.notifications, 'addInfo').andCallThrough();

        error = new Error();
        Error.captureStackTrace(error);

        error.metadata = { foo: 'bar' };
        error.privateMetadata = { baz: 'quux' };
        error.privateMetadataDescription = 'The contents of baz';
      });

      it('posts a notification asking for consent', () => {
        reporter.reportUncaughtException(error);
        expect(atom.notifications.addInfo).toHaveBeenCalled();
      });

      it('submits the error with the private metadata if the user consents', () => {
        spyOn(reporter, 'reportUncaughtException').andCallThrough();
        reporter.reportUncaughtException(error);
        reporter.reportUncaughtException.reset();

        notification = atom.notifications.getNotifications()[0];

        let notificationOptions = atom.notifications.addInfo.argsForCall[0][1];
        expect(notificationOptions.buttons[1].text).toMatch(/Yes/);

        notificationOptions.buttons[1].onDidClick();
        expect(reporter.reportUncaughtException).toHaveBeenCalledWith(error);
        expect(reporter.reportUncaughtException.callCount).toBe(1);
        expect(error.privateMetadata).toBeUndefined();
        expect(error.privateMetadataDescription).toBeUndefined();
        expect(error.metadata).toEqual({ foo: 'bar', baz: 'quux' });

        expect(notification.isDismissed()).toBe(true);
      });

      it('submits the error without the private metadata if the user does not consent', () => {
        spyOn(reporter, 'reportUncaughtException').andCallThrough();
        reporter.reportUncaughtException(error);
        reporter.reportUncaughtException.reset();

        notification = atom.notifications.getNotifications()[0];

        let notificationOptions = atom.notifications.addInfo.argsForCall[0][1];
        expect(notificationOptions.buttons[0].text).toMatch(/No/);

        notificationOptions.buttons[0].onDidClick();
        expect(reporter.reportUncaughtException).toHaveBeenCalledWith(error);
        expect(reporter.reportUncaughtException.callCount).toBe(1);
        expect(error.privateMetadata).toBeUndefined();
        expect(error.privateMetadataDescription).toBeUndefined();
        expect(error.metadata).toEqual({ foo: 'bar' });

        expect(notification.isDismissed()).toBe(true);
      });

      it('submits the error without the private metadata if the user dismisses the notification', () => {
        spyOn(reporter, 'reportUncaughtException').andCallThrough();
        reporter.reportUncaughtException(error);
        reporter.reportUncaughtException.reset();

        notification = atom.notifications.getNotifications()[0];
        notification.dismiss();

        expect(reporter.reportUncaughtException).toHaveBeenCalledWith(error);
        expect(reporter.reportUncaughtException.callCount).toBe(1);
        expect(error.privateMetadata).toBeUndefined();
        expect(error.privateMetadataDescription).toBeUndefined();
        expect(error.metadata).toEqual({ foo: 'bar' });
      });
    });

    it('treats packages located in atom.packages.getPackageDirPaths as user packages', () => {
      mockActivePackages = [
        {
          name: 'user-1',
          path: '/Users/user/.atom/packages/user-1',
          metadata: { version: '1.0.0' }
        },
        {
          name: 'user-2',
          path: '/Users/user/.atom/packages/user-2',
          metadata: { version: '1.2.0' }
        },
        {
          name: 'bundled-1',
          path:
            '/Applications/Atom.app/Contents/Resources/app.asar/node_modules/bundled-1',
          metadata: { version: '1.0.0' }
        },
        {
          name: 'bundled-2',
          path:
            '/Applications/Atom.app/Contents/Resources/app.asar/node_modules/bundled-2',
          metadata: { version: '1.2.0' }
        }
      ];

      const packageDirPaths = ['/Users/user/.atom/packages'];

      spyOn(atom.packages, 'getPackageDirPaths').andReturn(packageDirPaths);

      let error = new Error();
      Error.captureStackTrace(error);
      reporter.reportUncaughtException(error);

      expect(error.metadata.userPackages).toEqual({
        'user-1': '1.0.0',
        'user-2': '1.2.0'
      });
      expect(error.metadata.bundledPackages).toEqual({
        'bundled-1': '1.0.0',
        'bundled-2': '1.2.0'
      });
    });

    it('adds previous error messages and assertion failures to the reported metadata', () => {
      reporter.reportPreviousErrors = true;

      reporter.reportUncaughtException(new Error('A'));
      reporter.reportUncaughtException(new Error('B'));
      reporter.reportFailedAssertion(new Error('X'));
      reporter.reportFailedAssertion(new Error('Y'));

      reporter.reportUncaughtException(new Error('C'));

      expect(requests.length).toBe(5);

      const lastRequest = requests[requests.length - 1];
      const body = JSON.parse(lastRequest.body);

      console.log(body);
      expect(body.events[0].metaData.previousErrors).toEqual(['A', 'B']);
      expect(body.events[0].metaData.previousAssertionFailures).toEqual([
        'X',
        'Y'
      ]);
    });
  });

  describe('.reportFailedAssertion(error)', () => {
    it('posts warnings to bugsnag', () => {
      fs.getHomeDirectory = () => path.join(__dirname, '..', '..');

      let error = new Error();
      Error.captureStackTrace(error);
      reporter.reportFailedAssertion(error);
      let [lineNumber, columnNumber] = error.stack
        .match(/.js:(\d+):(\d+)/)
        .slice(1)
        .map(s => parseInt(s));

      expect(requests.length).toBe(1);
      let [request] = requests;
      expect(request.method).toBe('POST');
      expect(request.url).toBe('https://notify.bugsnag.com');
      expect(request.headers.get('Content-Type')).toBe('application/json');
      let body = JSON.parse(request.body);
      // Delete `inProject` field because tests may fail when run as part of Atom core
      // (i.e. when this test file will be located under `node_modules/exception-reporting/spec`)
      delete body.events[0].exceptions[0].stacktrace[0].inProject;

      expect(body).toEqual({
        apiKey: Reporter.API_KEY,
        notifier: {
          name: 'Atom',
          version: Reporter.LIB_VERSION,
          url: 'https://www.atom.io'
        },
        events: [
          {
            payloadVersion: '2',
            exceptions: [
              {
                errorClass: 'Error',
                message: '',
                stacktrace: [
                  {
                    method: semver.gt(process.versions.electron, '1.6.0')
                      ? 'Spec.it'
                      : 'it',
                    file: '~/exception-reporting/spec/reporter-spec.js',
                    lineNumber: lineNumber,
                    columnNumber: columnNumber
                  }
                ]
              }
            ],
            severity: 'warning',
            user: {},
            app: {
              version: atom.getVersion(),
              releaseStage: getReleaseChannel(atom.getVersion())
            },
            device: {
              osVersion: osVersion
            }
          }
        ]
      });
    });

    describe('when the error object has `privateMetadata` and `privateMetadataDescription` fields', () => {
      let [error, notification] = [];

      beforeEach(() => {
        atom.notifications.clear();
        spyOn(atom.notifications, 'addInfo').andCallThrough();

        error = new Error();
        Error.captureStackTrace(error);

        error.metadata = { foo: 'bar' };
        error.privateMetadata = { baz: 'quux' };
        error.privateMetadataDescription = 'The contents of baz';
      });

      it('posts a notification asking for consent', () => {
        reporter.reportFailedAssertion(error);
        expect(atom.notifications.addInfo).toHaveBeenCalled();
      });

      it('submits the error with the private metadata if the user consents', () => {
        spyOn(reporter, 'reportFailedAssertion').andCallThrough();
        reporter.reportFailedAssertion(error);
        reporter.reportFailedAssertion.reset();

        notification = atom.notifications.getNotifications()[0];

        let notificationOptions = atom.notifications.addInfo.argsForCall[0][1];
        expect(notificationOptions.buttons[1].text).toMatch(/Yes/);

        notificationOptions.buttons[1].onDidClick();
        expect(reporter.reportFailedAssertion).toHaveBeenCalledWith(error);
        expect(reporter.reportFailedAssertion.callCount).toBe(1);
        expect(error.privateMetadata).toBeUndefined();
        expect(error.privateMetadataDescription).toBeUndefined();
        expect(error.metadata).toEqual({ foo: 'bar', baz: 'quux' });

        expect(notification.isDismissed()).toBe(true);
      });

      it('submits the error without the private metadata if the user does not consent', () => {
        spyOn(reporter, 'reportFailedAssertion').andCallThrough();
        reporter.reportFailedAssertion(error);
        reporter.reportFailedAssertion.reset();

        notification = atom.notifications.getNotifications()[0];

        let notificationOptions = atom.notifications.addInfo.argsForCall[0][1];
        expect(notificationOptions.buttons[0].text).toMatch(/No/);

        notificationOptions.buttons[0].onDidClick();
        expect(reporter.reportFailedAssertion).toHaveBeenCalledWith(error);
        expect(reporter.reportFailedAssertion.callCount).toBe(1);
        expect(error.privateMetadata).toBeUndefined();
        expect(error.privateMetadataDescription).toBeUndefined();
        expect(error.metadata).toEqual({ foo: 'bar' });

        expect(notification.isDismissed()).toBe(true);
      });

      it('submits the error without the private metadata if the user dismisses the notification', () => {
        spyOn(reporter, 'reportFailedAssertion').andCallThrough();
        reporter.reportFailedAssertion(error);
        reporter.reportFailedAssertion.reset();

        notification = atom.notifications.getNotifications()[0];
        notification.dismiss();

        expect(reporter.reportFailedAssertion).toHaveBeenCalledWith(error);
        expect(reporter.reportFailedAssertion.callCount).toBe(1);
        expect(error.privateMetadata).toBeUndefined();
        expect(error.privateMetadataDescription).toBeUndefined();
        expect(error.metadata).toEqual({ foo: 'bar' });
      });

      it("only notifies the user once for a given 'privateMetadataRequestName'", () => {
        let fakeStorage = {};
        spyOn(global.localStorage, 'setItem').andCallFake(
          (key, value) => (fakeStorage[key] = value)
        );
        spyOn(global.localStorage, 'getItem').andCallFake(
          key => fakeStorage[key]
        );

        error.privateMetadataRequestName = 'foo';

        reporter.reportFailedAssertion(error);
        expect(atom.notifications.addInfo).toHaveBeenCalled();
        atom.notifications.addInfo.reset();

        reporter.reportFailedAssertion(error);
        expect(atom.notifications.addInfo).not.toHaveBeenCalled();

        let error2 = new Error();
        Error.captureStackTrace(error2);
        error2.privateMetadataDescription = 'Something about you';
        error2.privateMetadata = { baz: 'quux' };
        error2.privateMetadataRequestName = 'bar';

        reporter.reportFailedAssertion(error2);
        expect(atom.notifications.addInfo).toHaveBeenCalled();
      });
    });

    it('treats packages located in atom.packages.getPackageDirPaths as user packages', () => {
      mockActivePackages = [
        {
          name: 'user-1',
          path: '/Users/user/.atom/packages/user-1',
          metadata: { version: '1.0.0' }
        },
        {
          name: 'user-2',
          path: '/Users/user/.atom/packages/user-2',
          metadata: { version: '1.2.0' }
        },
        {
          name: 'bundled-1',
          path:
            '/Applications/Atom.app/Contents/Resources/app.asar/node_modules/bundled-1',
          metadata: { version: '1.0.0' }
        },
        {
          name: 'bundled-2',
          path:
            '/Applications/Atom.app/Contents/Resources/app.asar/node_modules/bundled-2',
          metadata: { version: '1.2.0' }
        }
      ];

      const packageDirPaths = ['/Users/user/.atom/packages'];

      spyOn(atom.packages, 'getPackageDirPaths').andReturn(packageDirPaths);

      let error = new Error();
      Error.captureStackTrace(error);
      reporter.reportFailedAssertion(error);

      expect(error.metadata.userPackages).toEqual({
        'user-1': '1.0.0',
        'user-2': '1.2.0'
      });
      expect(error.metadata.bundledPackages).toEqual({
        'bundled-1': '1.0.0',
        'bundled-2': '1.2.0'
      });
    });

    it('adds previous error messages and assertion failures to the reported metadata', () => {
      reporter.reportPreviousErrors = true;

      reporter.reportUncaughtException(new Error('A'));
      reporter.reportUncaughtException(new Error('B'));
      reporter.reportFailedAssertion(new Error('X'));
      reporter.reportFailedAssertion(new Error('Y'));

      reporter.reportFailedAssertion(new Error('C'));

      expect(requests.length).toBe(5);

      const lastRequest = requests[requests.length - 1];
      const body = JSON.parse(lastRequest.body);

      expect(body.events[0].metaData.previousErrors).toEqual(['A', 'B']);
      expect(body.events[0].metaData.previousAssertionFailures).toEqual([
        'X',
        'Y'
      ]);
    });
  });
});
