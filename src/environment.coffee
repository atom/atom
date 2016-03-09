child_process = require('child_process')
os = require('os')

# Gets a dump of the user's configured shell environment.
#
# Returns the output of the `env` command or `undefined` if there was an error.
getRawShellEnv = ->
  shell = process.env.SHELL ? "/bin/bash"

  # The `-ilc` set of options was tested to work with the OS X v10.11
  # default-installed versions of bash, zsh, sh, and ksh. It *does not*
  # work with csh or tcsh. Given that bash and zsh should cover the
  # vast majority of users and it gracefully falls back to prior behavior,
  # this should be safe.
  results = child_process.spawnSync(shell, ["-ilc", "env"], encoding: "utf8")
  return if results.error?
  return unless results.stdout and results.stdout.length > 0

  results.stdout

module.exports =
  # Gets the user's configured shell environment.
  #
  # Returns a copy of the user's shell enviroment.
  getShellEnv: ->
    shellEnvText = getRawShellEnv()
    return unless shellEnvText?

    env = {}

    for line in shellEnvText.split(os.EOL)
      if line.includes("=")
        components = line.split("=")
        if components.length is 2
          env[components[0]] = components[1]
        else
          k = components.shift()
          v = components.join("=")
          env[k] = v

    env
