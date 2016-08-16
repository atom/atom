/** @babel */

import {Disposable} from 'event-kit'

export default Object.freeze({
  name: 'Null Grammar',
  scopeName: 'text.plain',
  onDidUpdate (callback) {
    return new Disposable(noop)
  }
})

function noop () {}
