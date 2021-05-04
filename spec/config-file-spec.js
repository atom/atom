const fs = require('fs-plus');
const path = require('path');
const temp = require('temp').track();
const dedent = require('dedent');
const ConfigFile = require('../src/config-file');

describe('ConfigFile', () => {
  let filePath, configFile, subscription;

  beforeEach(async () => {
    jasmine.useRealClock();
    const tempDir = fs.realpathSync(temp.mkdirSync());
    filePath = path.join(tempDir, 'the-config.cson');
  });

  afterEach(() => {
    subscription.dispose();
  });

  describe('when the file does not exist', () => {
    it('returns an empty object from .get()', async () => {
      configFile = new ConfigFile(filePath);
      subscription = await configFile.watch();
      expect(configFile.get()).toEqual({});
    });
  });

  describe('when the file is empty', () => {
    it('returns an empty object from .get()', async () => {
      writeFileSync(filePath, '');
      configFile = new ConfigFile(filePath);
      subscription = await configFile.watch();
      expect(configFile.get()).toEqual({});
    });
  });

  describe('when the file is updated with valid CSON', () => {
    it('notifies onDidChange observers with the data', async () => {
      configFile = new ConfigFile(filePath);
      subscription = await configFile.watch();

      const event = new Promise(resolve => configFile.onDidChange(resolve));

      writeFileSync(
        filePath,
        dedent`
        '*':
          foo: 'bar'

        'javascript':
          foo: 'baz'
      `
      );

      expect(await event).toEqual({
        '*': { foo: 'bar' },
        javascript: { foo: 'baz' }
      });

      expect(configFile.get()).toEqual({
        '*': { foo: 'bar' },
        javascript: { foo: 'baz' }
      });
    });
  });

  describe('when the file is updated with invalid CSON', () => {
    it('notifies onDidError observers', async () => {
      configFile = new ConfigFile(filePath);
      subscription = await configFile.watch();

      const message = new Promise(resolve => configFile.onDidError(resolve));

      writeFileSync(
        filePath,
        dedent`
        um what?
      `,
        2
      );

      expect(await message).toContain('Failed to load `the-config.cson`');

      const event = new Promise(resolve => configFile.onDidChange(resolve));

      writeFileSync(
        filePath,
        dedent`
        '*':
          foo: 'bar'

        'javascript':
          foo: 'baz'
      `,
        4
      );

      expect(await event).toEqual({
        '*': { foo: 'bar' },
        javascript: { foo: 'baz' }
      });
    });
  });

  describe('ConfigFile.at()', () => {
    let path0, path1;

    beforeEach(() => {
      path0 = filePath;
      path1 = path.join(fs.realpathSync(temp.mkdirSync()), 'the-config.cson');

      configFile = ConfigFile.at(path0);
    });

    it('returns an existing ConfigFile', () => {
      const cf = ConfigFile.at(path0);
      expect(cf).toEqual(configFile);
    });

    it('creates a new ConfigFile for unrecognized paths', () => {
      const cf = ConfigFile.at(path1);
      expect(cf).not.toEqual(configFile);
    });
  });
});

function writeFileSync(filePath, content, seconds = 2) {
  const utime = Date.now() / 1000 + seconds;
  fs.writeFileSync(filePath, content);
  fs.utimesSync(filePath, utime, utime);
}
