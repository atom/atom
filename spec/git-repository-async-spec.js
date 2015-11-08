'use babel'

const fs = require('fs-plus')
const Git = require('nodegit')
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
  describe('getPathStatus', function () {
    it('trigger a status-changed event when the new status differs from the last cached one', function () {
      let workingDirectory = copyRepository()
      let repo = GitRepositoryAsync.open(workingDirectory)
      let filePath = path.join(workingDirectory, 'file.txt')
      let statusHandler = jasmine.createSpy('statusHandler')

      repo.onDidChangeStatus(statusHandler)
      fs.writeFileSync(filePath, '')

      waitsForPromise(async function () {
        await repo.getPathStatus(filePath)
        expect(statusHandler.callCount).toBe(1)
        let expectedStatus = Git.Status.STATUS.WT_MODIFIED
        expect(statusHandler.argsForCall[0][0]).toEqual({path: filePath, pathStatus: expectedStatus})
        fs.writeFileSync(filePath, 'abc')
        await repo.getPathStatus(filePath)
        expect(statusHandler.callCount).toBe(1)
      })
    })
  })

  describe('buffer events', () => {
    beforeEach(function () {
      atom.project.setPaths([copyRepository()])
    })

    it('emits a status-changed events when a buffer is saved', () => {
      // TODO might as well use jasmine spies for consistency rather than `called`
      // here
      let editor, called

      waitsForPromise(async function () {
        editor = await atom.workspace.open('other.txt')
        editor.insertNewline()
        let repo = atom.project.getRepositories()[0]
        repo.async.onDidChangeStatus((c) => {
          called = c
        })
        editor.save()

        waitsFor(() => {
          return Boolean(called)
        })
      })

      runs(() => {
        expect(called).toEqual({path: editor.getPath(), pathStatus: 256})
      })
    })

    it('emits a status-changed event when a buffer is reloaded', () => {
      let editor
      let statusHandler = jasmine.createSpy('statusHandler')
      let reloadHandler = jasmine.createSpy('reloadHandler')

      waitsForPromise(async function() {
        editor = await atom.workspace.open('other.txt')

        fs.writeFileSync(editor.getPath(), 'changed')

        atom.project.getRepositories()[0].async.onDidChangeStatus(statusHandler)
        editor.getBuffer().reload()

        waitsFor(function () {
          return statusHandler.callCount === 1
        })
      })

      runs(function () {
        expect(statusHandler.callCount).toBe(1)
        expect(statusHandler).toHaveBeenCalledWith({path: editor.getPath(), pathStatus: Git.Status.STATUS.WT_MODIFIED})

        let buffer = editor.getBuffer()
        buffer.onDidReload(reloadHandler)
        buffer.reload()
      })

      waitsFor(function () {
        return reloadHandler.callCount === 1
      })

      runs(function () {
        expect(statusHandler.callCount).toBe(1)
      })
    })

    it('emits a status-changed event when a buffer\'s path changes', function () {
      let editor
      let statusHandler = jasmine.createSpy('statusHandler')
      let pathHandler = jasmine.createSpy('pathHandler')

      waitsForPromise(async function () {
        editor = await atom.workspace.open('other.txt')
        let buffer = editor.getBuffer()
        let repo = atom.project.getRepositories()[0].async

        fs.writeFileSync(editor.getPath(), 'changed')

        repo.onDidChangeStatus(statusHandler)

        buffer.emitter.emit('did-change-path')
        waitsFor(function () { return statusHandler.callCount === 1 })
      })

      runs(function () {
        expect(statusHandler.callCount).toBe(1)
        expect(statusHandler).toHaveBeenCalledWith({path: editor.getPath(), pathStatus: Git.Status.STATUS.WT_MODIFIED})
        let buffer = editor.getBuffer()
        buffer.onDidChangePath(pathHandler)
        buffer.emitter.emit('did-change-path')
      })

      waitsFor(function () {
        return pathHandler.callCount === 1
      })

      runs(function () {
        // The first result should be cached so the status should only change once.
        expect(statusHandler.callCount).toBe(1)
      })
    })
  })

  xdescribe('GitRepositoryAsync::relativize(filePath)')
})
