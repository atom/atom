'use babel'

const fs = require('fs-plus')
const path = require('path')
const temp = require('temp')

const GitRepositoryAsync = require('../src/git-repository-async')

const openFixture = (fixture) => {
  GitRepositoryAsync.open(path.join(__dirname, 'fixtures', 'git', fixture))
}

const copyRepository = () => {
  let workingDirPath = temp.mkdirSync('atom-working-dir')
  fs.copySync(path.join(__dirname, 'fixtures', 'git', 'working-dir'), workingDirPath)
  fs.renameSync(path.join(workingDirPath, 'git.git'), path.join(workingDirPath, '.git'))
  return fs.realpathSync(workingDirPath)
}

describe('GitRepositoryAsync', function () {
  describe('buffer events', () => {

    fit('emits a status-changed events when a buffer is saved', () => {
      let editor, called

      atom.project.setPaths([copyRepository()])
      waitsForPromise(function () {
        return atom.workspace.open('other.txt').then((o) => {
          editor = o
        })
      })

      runs(() => {
        editor.insertNewline()
        let repo = atom.project.getRepositories()[0]
        repo.async.onDidChangeStatus((c) => {
          called = c
        })
        editor.save()
      })

      waitsFor(() => {
        return Boolean(called)
      })

      runs(() => {
        expect(called).toEqual({path: editor.getPath(), pathStatus: 256})
      })
    })

    xit('emits a status-changed event when a buffer is reloaded')

    xit('emits a status-changed event when a buffer\'s path changes')
  })

  xdescribe('GitRepositoryAsync::relativize(filePath)')
})
