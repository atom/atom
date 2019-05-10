'use strict'

const path = require('path')
const {spawn} = require('child_process')

const CONFIG = require('../config')

module.exports = async function () {
  return new Promise((resolve, reject) => {
    const eslint = spawn(
      path.join('script', 'node_modules', '.bin', 'eslint'),
      ['--cache', '--format', 'json', '.'],
      { cwd: CONFIG.repositoryRootPath }
    )

    let output = ''
    let errorOutput = ''
    eslint.stdout.on('data', data => {
      output += data.toString()
    })

    eslint.stderr.on('data', data => {
      errorOutput += data.toString()
    })

    eslint.on('error', error => reject(error))
    eslint.on('close', exitCode => {
      const errors = []
      let files

      try {
        files = JSON.parse(output)
      } catch (_) {
        reject(errorOutput)
        return
      }

      for (const file of files) {
        for (const error of file.messages) {
          errors.push({
            path: file.filePath,
            message: error.message,
            lineNumber: error.line,
            rule: error.ruleId
          })
        }
      }

      resolve(errors)
    })
  })
}
