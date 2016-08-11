/** @babel */

import {spawnSync} from 'child_process'

const ENVIRONMENT_VARIABLES_TO_PRESERVE = new Set([
  'NODE_ENV',
  'NODE_PATH',
  'ATOM_HOME'
])

const OSX_SHELLS_TO_PATCH = new Set([
  '/sh',
  '/bash',
  '/zsh',
  '/fish'
])

function updateProcessEnv (launchEnv) {
  let envToAssign
  if (launchEnv && launchEnv.PWD) {
    envToAssign = launchEnv
  } else {
    if (process.platform === 'darwin') {
      envToAssign = getEnvFromShell()
    }
  }

  if (envToAssign) {
    for (let key in process.env) {
      if (!ENVIRONMENT_VARIABLES_TO_PRESERVE.has(key)) {
        delete process.env[key]
      }
    }

    for (let key in envToAssign) {
      if (!ENVIRONMENT_VARIABLES_TO_PRESERVE.has(key)) {
        process.env[key] = envToAssign[key]
      }
    }
  }
}

function shellShouldBePatched () {
  let shell = process.env.SHELL
  if (!shell) {
    return false
  }
  for (let s of OSX_SHELLS_TO_PATCH) {
    if (shell.endsWith(s)) {
      return shell
    }
  }

  return false
}

function getEnvFromShell () {
  let shell = shellShouldBePatched()
  if (shell) {
    let {stdout} = spawnSync(shell, ['-ilc', 'command env'], {encoding: 'utf8'})
    if (stdout) {
      let result = {}
      for (let line of stdout.split('\n')) {
        if (line.includes('=')) {
          let components = line.split('=')
          let key = components.shift()
          let value = components.join('=')
          result[key] = value
        }
      }
      return result
    }
  }
}

export default { updateProcessEnv, shellShouldBePatched }
