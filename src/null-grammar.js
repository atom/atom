/** @babel */

import {Disposable} from 'event-kit'

module.exports = Object.freeze({
  name: 'Null Grammar',
  scopeName: 'text.plain',
  onDidUpdate (callback) {
    return new Disposable(noop)
  }
})

function noop () {}
