const DefaultDirectorySearcher = require('../src/default-directory-searcher')
const Task = require('../src/task')
const path = require('path')

describe('DefaultDirectorySearcher', function () {
  let searcher
  let dirPath

  beforeEach(function () {
    dirPath = path.resolve(__dirname, 'fixtures', 'dir')
    searcher = new DefaultDirectorySearcher()
  })

  it('terminates the task after running a search', function () {
    const options = {
      ignoreCase: false,
      includeHidden: false,
      excludeVcsIgnores: true,
      inclusions: [],
      globalExclusions: ['a-dir'],
      didMatch () {},
      didError () {},
      didSearchPaths () {}
    }
    const searchPromise = searcher.search(
      [
        {
          getPath () {
            return dirPath
          }
        }
      ],
      /abcdefg/,
      options
    )
    spyOn(Task.prototype, 'terminate').andCallThrough()

    waitsForPromise(() => searchPromise)

    runs(() => expect(Task.prototype.terminate).toHaveBeenCalled())
  })
})
