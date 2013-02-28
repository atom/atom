{less} = require('less')

describe "require", ->
  describe "files with a `.less` extension", ->
    it "parses valid files into css", ->
      output = require(project.resolve("sample.less"))
      expect(output).toBe """
        #header {
          color: #4d926f;
        }
        h2 {
          color: #4d926f;
        }

      """

    it "throws an error when parsing invalid file", ->
      functionWithError = (-> require(project.resolve("sample-with-error.less")))
      expect(functionWithError).toThrow()