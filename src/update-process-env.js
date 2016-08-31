/** @babel */

import fs from 'fs'
import {spawnSync} from 'child_process'

const ENVIRONMENT_VARIABLES_TO_PRESERVE = new Set([
  'NODE_ENV',
  'NODE_PATH',
  'ATOM_HOME',
  'ATOM_SUPPRESS_ENV_PATCHING'
])

const PLATFORMS_KNOWN_TO_WORK = new Set([
  'darwin',
  'linux'
])

function updateProcessEnv (launchEnv) {
  let envToAssign
  if (launchEnv && shouldGetEnvFromShell(launchEnv)) {
    envToAssign = getEnvFromShell(launchEnv)
  } else if (launchEnv && launchEnv.PWD) {
    envToAssign = launchEnv
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
      } else {
        if (!process.env[key] && envToAssign[key]) {
          process.env[key] = envToAssign[key]
        }
      }
    }

    if (envToAssign.ATOM_HOME && fs.existsSync(envToAssign.ATOM_HOME)) {
      process.env.ATOM_HOME = envToAssign.ATOM_HOME
    }
  }
}

function shouldGetEnvFromShell (env) {
  if (!PLATFORMS_KNOWN_TO_WORK.has(process.platform)) {
    return false
  }

  if (!env || !env.SHELL || env.SHELL.trim() === '') {
    return false
  }

  if (env.ATOM_SUPPRESS_ENV_PATCHING || process.env.ATOM_SUPPRESS_ENV_PATCHING) {
    return false
  }

  return true
}

function getEnvFromShell (env) {
  if (!shouldGetEnvFromShell(env)) {
    return
  }

  let {stdout} = spawnSync(env.SHELL, ['-ilc', 'command env'], {encoding: 'utf8'})
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

export default { updateProcessEnv, shouldGetEnvFromShell }
