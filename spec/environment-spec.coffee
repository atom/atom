child_process = require('child_process')
{getShellEnv} = require("../src/environment")

fdescribe "Environment handling", ->
  describe "when things are configured properly", ->
    beforeEach ->
      spyOn(child_process, "spawnSync").andReturn
        stdout: """
            FOO=BAR
            TERM=xterm-something
            PATH=/usr/bin:/bin:/usr/sbin:/sbin:/some/crazy/path/entry/that/should/not/exist
          """

    it "returns an object containing the information from the user's shell environment", ->
      env = getShellEnv()

      expect(env.FOO).toEqual "BAR"
      expect(env.TERM).toEqual "xterm-something"
      expect(env.PATH).toEqual "/usr/bin:/bin:/usr/sbin:/sbin:/some/crazy/path/entry/that/should/not/exist"

  describe "when an error occurs", ->
    beforeEach ->
      spyOn(child_process, "spawnSync").andReturn
        error: new Error("testing when an error occurs")

    it "returns undefined", ->
      expect(getShellEnv()).toBeUndefined()
