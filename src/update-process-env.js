/** @babel */

import fs from 'fs'
import {spawnSync} from 'child_process'

const ENVIRONMENT_VARIABLES_TO_PRESERVE = new Set([
  'NODE_ENV',
  'NODE_PATH',
  'ATOM_HOME'
])

const OSX_SHELLS = new Set([
  '/sh',
  '/bash',
  '/zsh',
  '/fish',
  '/xonsh'
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

    if (envToAssign.ATOM_HOME && fs.existsSync(envToAssign.ATOM_HOME)) {
      process.env.ATOM_HOME = envToAssign.ATOM_HOME
    }
  }
}

function shouldGetEnvFromShell (shell) {
  if (!shell || shell.trim() === '') {
    return false
  }
  for (let s of OSX_SHELLS) {
    if (shell.endsWith(s)) {
      return true
    }
  }

  return false
}

function getEnvFromShell () {
  let shell = process.env.SHELL
  if (!shouldGetEnvFromShell(shell)) {
    return
  }

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

export default { updateProcessEnv, shouldGetEnvFromShell }
