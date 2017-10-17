/** @babel */

import parseCommandLine from '../../src/main-process/parse-command-line'

describe('parseCommandLine', function () {
  describe('when --uri-handler is not passed', function () {
    it('parses arguments as normal', function () {
      const args = parseCommandLine(['-d', '--safe', '--test', '/some/path', 'atom://test/url', 'atom://other/url'])
      assert.isTrue(args.devMode)
      assert.isTrue(args.safeMode)
      assert.isTrue(args.test)
      assert.deepEqual(args.urlsToOpen, ['atom://test/url', 'atom://other/url'])
      assert.deepEqual(args.pathsToOpen, ['/some/path'])
    })
  })

  describe('when --uri-handler is passed', function () {
    it('ignores other arguments and limits to one URL', function () {
      const args = parseCommandLine(['-d', '--uri-handler', '--safe', '--test', '/some/path', 'atom://test/url', 'atom://other/url'])
      assert.isUndefined(args.devMode)
      assert.isUndefined(args.safeMode)
      assert.isUndefined(args.test)
      assert.deepEqual(args.urlsToOpen, ['atom://test/url'])
      assert.deepEqual(args.pathsToOpen, [])
    })
  })
})
