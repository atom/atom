function openFile (atom, {query}) {
  const {filename, line, column} = query

  atom.workspace.open(filename, {
    initialLine: parseInt(line || 0, 10),
    initialColumn: parseInt(column || 0, 10),
    searchAllPanes: true
  })
}

const ROUTER = {
  '/open/file': openFile
}

module.exports = {
  create (atomEnv) {
    return function coreURIHandler (parsed) {
      const handler = ROUTER[parsed.pathname]
      if (handler) {
        handler(atomEnv, parsed)
      }
    }
  }
}
