const DefaultDirectorySearcher = require('../src/default-directory-searcher');
const Task = require('../src/task');
const path = require('path');

describe('DefaultDirectorySearcher', function() {
  let searcher;
  let dirPath;

  beforeEach(function() {
    dirPath = path.resolve(__dirname, 'fixtures', 'dir');
    searcher = new DefaultDirectorySearcher();
  });

  it('terminates the task after running a search', async function() {
    const options = {
      ignoreCase: false,
      includeHidden: false,
      excludeVcsIgnores: true,
      inclusions: [],
      globalExclusions: ['a-dir'],
      didMatch() {},
      didError() {},
      didSearchPaths() {}
    };

    spyOn(Task.prototype, 'terminate').andCallThrough();

    await searcher.search(
      [
        {
          getPath() {
            return dirPath;
          }
        }
      ],
      /abcdefg/,
      options
    );

    expect(Task.prototype.terminate).toHaveBeenCalled();
  });
});
