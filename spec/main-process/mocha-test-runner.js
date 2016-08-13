"use babel"

import Mocha from 'mocha'
import fs from 'fs-plus'
import {assert} from 'chai'

export default function (testPaths) {
  global.assert = assert

  const mocha = new Mocha({reporter: 'spec'})
  for (let testPath of testPaths) {
    if (fs.isDirectorySync(testPath)) {
      for (let testFilePath of fs.listTreeSync(testPath)) {
        if (/\.test\.(coffee|js)$/.test(testFilePath)) {
          mocha.addFile(testFilePath)
        }
      }
    } else {
      mocha.addFile(testPath)
    }
  }

  mocha.run(function (failures) {
    if (failures === 0) {
      process.exit(0)
    } else {
      process.exit(1)
    }
  })
}
