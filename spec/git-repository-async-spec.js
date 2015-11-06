'use babel'

const fs = require('fs-plus')
const path = require('path')
const temp = require('temp')

temp.track()

const GitRepositoryAsync = require('../src/git-repository-async')

const openFixture = (fixture) => {
  return GitRepositoryAsync.open(path.join(__dirname, 'fixtures', 'git', fixture))
}

const copyRepository = () => {
  let workingDirPath = temp.mkdirSync('atom-working-dir')
  fs.copySync(path.join(__dirname, 'fixtures', 'git', 'working-dir'), workingDirPath)
  fs.renameSync(path.join(workingDirPath, 'git.git'), path.join(workingDirPath, '.git'))
  return fs.realpathSync(workingDirPath)
}


fdescribe('GitRepositoryAsync', () => {
  describe('@open(path)', () => {
    it('repo is null when no repository is found', () => {
      let repo = GitRepositoryAsync.open(path.join(temp.dir, 'nogit.txt'))

      waitsForPromise({shouldReject: true}, () => {
        return repo.repoPromise
      })

      runs(() => {
        expect(repo.repo).toBe(null)
      })
    })
  })

  describe('.getPath()', () => {
    xit('returns the repository path for a .git directory path')

    it('returns the repository path for a repository path', () => {
      let repo = openFixture('master.git')
      let onSuccess = jasmine.createSpy('onSuccess')
      waitsForPromise(() => repo.getPath().then(onSuccess))

      runs(() => {
        expect(onSuccess.mostRecentCall.args[0]).toBe(
          path.join(__dirname, 'fixtures', 'git', 'master.git')
        )
      })
    })
  })

  describe('buffer events', () => {
    beforeEach(() => {
      // This is sync, should be fine in a beforeEach
      atom.project.setPaths([copyRepository()])
    })

    it('emits a status-changed events when a buffer is saved', () => {
      let editor, called
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

    it('emits a status-changed event when a buffer is reloaded', () => {
      let editor
      let statusHandler = jasmine.createSpy('statusHandler')
      let reloadHandler = jasmine.createSpy('reloadHandler')

      waitsForPromise(function () {
        return atom.workspace.open('other.txt').then((o) => {
          editor = o
        })
      })

      runs(() => {
        fs.writeFileSync(editor.getPath(), 'changed')
        atom.project.getRepositories()[0].async.onDidChangeStatus(statusHandler)
        editor.getBuffer().reload()
      })

      waitsFor(() => {
        return statusHandler.callCount > 0
      })

      runs(() => {
        expect(statusHandler.callCount).toBe(1)
        expect(statusHandler).toHaveBeenCalledWith({path: editor.getPath(), pathStatus: 256})
        let buffer = editor.getBuffer()
        buffer.onDidReload(reloadHandler)
        buffer.reload()
      })

      waitsFor(() => { return reloadHandler.callCount > 0 })
      runs(() => { expect(statusHandler.callCount).toBe(1) })
    })
  })

})
