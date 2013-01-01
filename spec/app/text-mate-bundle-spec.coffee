fs = require('fs')
TextMateBundle = require 'text-mate-bundle'

describe "TextMateBundle", ->
  describe ".constructor(bundlePath)", ->
    it "logs warning, but does not raise errors if a grammar can't be parsed", ->
      bundlePath = fs.join(require.resolve('fixtures'), "test.tmbundle")
      spyOn(console, 'warn')
      expect(-> new TextMateBundle(bundlePath)).not.toThrow()
      expect(console.warn).toHaveBeenCalled()

