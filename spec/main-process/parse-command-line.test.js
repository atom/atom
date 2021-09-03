const { assert } = require('chai');
const parseCommandLine = require('../../src/main-process/parse-command-line');

describe('parseCommandLine', () => {
  describe('when --uri-handler is not passed', () => {
    it('parses arguments as normal', () => {
      const args = parseCommandLine([
        '-d',
        '--safe',
        '--test',
        '/some/path',
        'atom://test/url',
        'atom://other/url'
      ]);
      assert.isTrue(args.devMode);
      assert.isTrue(args.safeMode);
      assert.isTrue(args.test);
      assert.deepEqual(args.urlsToOpen, [
        'atom://test/url',
        'atom://other/url'
      ]);
      assert.deepEqual(args.pathsToOpen, ['/some/path']);
    });

    // The "underscore flag" with no "non-flag argument" after it
    // is the minimal reproducer for the macOS Gatekeeper startup bug.
    // By default, it causes the addition of boolean "true"s into yargs' "non-flag argument" array: `argv._`
    // Whereas we do string-only operations on these arguments, expecting them to be paths or URIs.
    describe('and --_ or -_ are passed', () => {
      it('does not attempt to parse booleans as paths or URIs', () => {
        const args = parseCommandLine([
          '--_',
          '/some/path',
          '-_',
          '-_',
          'some/other/path',
          'atom://test/url',
          '--_',
          'atom://other/url',
          '-_',
          './another-path.file',
          '-_',
          '-_',
          '-_'
        ]);
        assert.deepEqual(args.urlsToOpen, [
          'atom://test/url',
          'atom://other/url'
        ]);
        assert.deepEqual(args.pathsToOpen, [
          '/some/path',
          'some/other/path',
          './another-path.file'
        ]);
      });
    });

    describe('and a non-flag number is passed as an argument', () => {
      it('does not attempt to parse numbers as paths or URIs', () => {
        const args = parseCommandLine([
          '43',
          '/some/path',
          '22',
          '97',
          'some/other/path',
          'atom://test/url',
          '885',
          'atom://other/url',
          '42',
          './another-path.file'
        ]);
        assert.deepEqual(args.urlsToOpen, [
          'atom://test/url',
          'atom://other/url'
        ]);
        assert.deepEqual(args.pathsToOpen, [
          '/some/path',
          'some/other/path',
          './another-path.file'
        ]);
      });
    });
  });

  describe('when --uri-handler is passed', () => {
    it('ignores other arguments and limits to one URL', () => {
      const args = parseCommandLine([
        '-d',
        '--uri-handler',
        '--safe',
        '--test',
        '/some/path',
        'atom://test/url',
        'atom://other/url'
      ]);
      assert.isUndefined(args.devMode);
      assert.isUndefined(args.safeMode);
      assert.isUndefined(args.test);
      assert.deepEqual(args.urlsToOpen, ['atom://test/url']);
      assert.deepEqual(args.pathsToOpen, []);
    });
  });

  describe('when evil macOS Gatekeeper flag "-psn_0_[six or seven digits here]" is passed', () => {
    it('ignores any arguments starting with "-psn_"', () => {
      const getPsnFlag = () => {
        return `-psn_0_${Math.floor(Math.random() * 10_000_000)}`;
      };
      const args = parseCommandLine([
        getPsnFlag(),
        '/some/path',
        getPsnFlag(),
        getPsnFlag(),
        'some/other/path',
        'atom://test/url',
        getPsnFlag(),
        'atom://other/url',
        '-psn_ Any argument starting with "-psn_" should be ignored, even this one.',
        './another-path.file'
      ]);
      assert.deepEqual(args.urlsToOpen, [
        'atom://test/url',
        'atom://other/url'
      ]);
      assert.deepEqual(args.pathsToOpen, [
        '/some/path',
        'some/other/path',
        './another-path.file'
      ]);
    });
  });
});
