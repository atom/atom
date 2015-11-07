'use babel'

const fs = require('fs-plus')
const path = require('path')
const temp = require('temp')
const Git = require('nodegit')
const CompositeDisposable = require('event-kit').CompositeDisposable

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

async function waitBetter(fn) {
  const p = new Promise()
  let first = true
  const check = () => {
    if (fn()) {
      p.resolve()
      first = false
      return true
    } else if (first) {
      first = false
      return false
    } else {
      p.reject()
      return false
    }
  }

  if (!check()) {
    window.setTimeout(check, 500)
  }
  return p
}

fdescribe('GitRepositoryAsync-js', () => {
  let subscriptions

  beforeEach(() => {
    jasmine.useRealClock()
    subscriptions = new CompositeDisposable()
  })

  afterEach(() => {
    subscriptions.dispose()
  })

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

  describe('.isPathIgnored(path)', () => {
    it('resolves true for an ignored path', () => {
      let repo = openFixture('ignore.git')
      let onSuccess = jasmine.createSpy('onSuccess')
      waitsForPromise(() => repo.isPathIgnored('a.txt').then(onSuccess).catch(e => console.log(e)))

      runs(() => expect(onSuccess.mostRecentCall.args[0]).toBeTruthy())
    })

    it('resolves false for a non-ignored path', () => {
      let repo = openFixture('ignore.git')
      let onSuccess = jasmine.createSpy('onSuccess')
      waitsForPromise(() => repo.isPathIgnored('b.txt').then(onSuccess))
      runs(() => expect(onSuccess.mostRecentCall.args[0]).toBeFalsy())
    })
  })

  describe('.isPathModified(path)', () => {
    let repo, filePath, newPath, emptyPath

    beforeEach(() => {
      let workingDirPath = copyRepository()
      repo = GitRepositoryAsync.open(workingDirPath)
      filePath = path.join(workingDirPath, 'a.txt')
      newPath = path.join(workingDirPath, 'new-path.txt')
      fs.writeFileSync(newPath, "i'm new here")
      emptyPath = path.join(workingDirPath, 'empty-path.txt')
    })

    describe('when the path is unstaged', () => {
      it('resolves false if the path has not been modified', () => {
        let onSuccess = jasmine.createSpy('onSuccess')
        waitsForPromise(() => repo.isPathModified(filePath).then(onSuccess))
        runs(() => expect(onSuccess.mostRecentCall.args[0]).toBeFalsy())
      })

      it('resolves true if the path is modified', () => {
        fs.writeFileSync(filePath, "change")
        let onSuccess = jasmine.createSpy('onSuccess')
        waitsForPromise(() => repo.isPathModified(filePath).then(onSuccess))
        runs(() => expect(onSuccess.mostRecentCall.args[0]).toBeTruthy())
      })

      it('resolves false if the path is new', () => {
        let onSuccess = jasmine.createSpy('onSuccess')
        waitsForPromise(() => repo.isPathModified(newPath).then(onSuccess))
        runs(() => expect(onSuccess.mostRecentCall.args[0]).toBeFalsy())
      })

      it('resolves false if the path is invalid', () => {
        let onSuccess = jasmine.createSpy('onSuccess')
        waitsForPromise(() => repo.isPathModified(emptyPath).then(onSuccess))
        runs(() => expect(onSuccess.mostRecentCall.args[0]).toBeFalsy())
      })
    })
  })

  describe('.isPathNew(path)', () => {
    let filePath, newPath, repo

    beforeEach(() => {
      let workingDirPath = copyRepository()
      repo = GitRepositoryAsync.open(workingDirPath)
      filePath = path.join(workingDirPath, 'a.txt')
      newPath = path.join(workingDirPath, 'new-path.txt')
      fs.writeFileSync(newPath, "i'm new here")
    })

    describe('when the path is unstaged', () => {
      it('returns true if the path is new', () => {
        let onSuccess = jasmine.createSpy('onSuccess')
        waitsForPromise(() => repo.isPathNew(newPath).then(onSuccess))
        runs(() => expect(onSuccess.mostRecentCall.args[0]).toBeTruthy())
      })

      it("returns false if the path isn't new", async () => {
        let onSuccess = jasmine.createSpy('onSuccess')

        let modified = await repo.isPathModified(newPath).then(onSuccess)
        expect(modified).toBeFalsy()
      })
    })
  })

  describe('.checkoutHead(path)', () => {
    let filePath, repo

    beforeEach(() => {
      let workingDirPath = copyRepository()
      repo = GitRepositoryAsync.open(workingDirPath)
      filePath = path.join(workingDirPath, 'a.txt')
    })

    it('no longer reports a path as modified after checkout', async () => {
      let modified = await repo.isPathModified(filePath)
      expect(modified).toBeFalsy()
      fs.writeFileSync(filePath, 'ch ch changes')

      modified = await repo.isPathModified(filePath)
      expect(modified).toBeTruthy()

      // Don't need to assert that this succeded because waitsForPromise should
      // fail if it was rejected..
      await repo.checkoutHead(filePath)

      modified = await repo.isPathModified(filePath)
      expect(modified).toBeFalsy()
    })

    it('restores the contents of the path to the original text', async () => {
      fs.writeFileSync(filePath, 'ch ch changes')
      await repo.checkoutHead(filePath)
      xxpect(fs.readFileSync(filePath, 'utf8')).toBe('')
    })

    it('fires a did-change-status event if the checkout completes successfully', async () => {
      fs.writeFileSync(filePath, 'ch ch changes')

      await repo.getPathStatus(filePath)

      let statusHandler = jasmine.createSpy('statusHandler')
      subscriptions.add(repo.onDidChangeStatus(statusHandler))

      await repo.checkoutHead(filePath)

      expect(statusHandler.callCount).toBe(1)
      expect(statusHandler.argsForCall[0][0]).toEqual({path: filePath, pathStatus: 0})

      await repo.checkoutHead(filePath)
      expect(statusHandler.callCount).toBe(1)
    })
  })

  xdescribe('.checkoutHeadForEditor(editor)', () => {
    let filePath, editor, repo

    beforeEach(() => {
      let workingDirPath = copyRepository()
      repo = GitRepositoryAsync.open(workingDirPath)
      filePath = path.join(workingDirPath, 'a.txt')
      fs.writeFileSync(filePath, 'ch ch changes')

      waitsForPromise(() => atom.workspace.open(filePath))
      runs(() => editor = atom.workspace.getActiveTextEditor())
    })

    xit('displays a confirmation dialog by default', () => {
      spyOn(atom, 'confirm').andCallFake(buttons, () => buttons[0].OK())
      atom.config.set('editor.confirmCheckoutHeadRevision', true)

      waitsForPromise(() => repo.checkoutHeadForEditor(editor))
      runs(() => expect(fs.readFileSync(filePath, 'utf8')).toBe(''))
    })

    xit('does not display a dialog when confirmation is disabled', () => {
      spyOn(atom, 'confirm')
      atom.config.set('editor.confirmCheckoutHeadRevision', false)

      waitsForPromise(() => repo.checkoutHeadForEditor(editor))
      runs(() => {
        expect(fs.readFileSync(filePath, 'utf8')).toBe('')
        expect(atom.confirm).not.toHaveBeenCalled()
      })
    })
  })

  describe('.getPathStatus(path)', () => {
    let filePath, repo

    beforeEach(() => {
      let workingDirectory = copyRepository()
      repo = GitRepositoryAsync.open(workingDirectory)
      filePath = path.join(workingDirectory, 'file.txt')
    })

    it('trigger a status-changed event when the new status differs from the last cached one', async () => {
      let statusHandler = jasmine.createSpy("statusHandler")
      subscriptions.add(repo.onDidChangeStatus(statusHandler))
      fs.writeFileSync(filePath, '')

      await repo.getPathStatus(filePath)

      expect(statusHandler.callCount).toBe(1)
      let status = Git.Status.STATUS.WT_MODIFIED
      expect(statusHandler.argsForCall[0][0]).toEqual({path: filePath, pathStatus: status})
      fs.writeFileSync(filePath, 'abc')

      await repo.getPathStatus(filePath)
      expect(statusHandler.callCount).toBe(1)
    })
  })

  describe('.getDirectoryStatus(path)', () => {
    let directoryPath, filePath, repo

    beforeEach(() => {
      let workingDirectory = copyRepository()
      repo = GitRepositoryAsync.open(workingDirectory)
      directoryPath = path.join(workingDirectory, 'dir')
      filePath = path.join(directoryPath, 'b.txt')
    })

    it('gets the status based on the files inside the directory', async () => {
      let result = await repo.getDirectoryStatus(directoryPath)
      expect(repo.isStatusModified(result)).toBe(false)

      fs.writeFileSync(filePath, 'abc')

      await repo.getPathStatus(filePath)

      result = await repo.getDirectoryStatus(directoryPath)
      expect(repo.isStatusModified(result)).toBe(true)
    })
  })

  describe('.refreshStatus()', () => {
    let newPath, modifiedPath, cleanPath, originalModifiedPathText, repo

    beforeEach(() => {
      let workingDirectory = copyRepository()
      repo = GitRepositoryAsync.open(workingDirectory)
      modifiedPath = path.join(workingDirectory, 'file.txt')
      newPath = path.join(workingDirectory, 'untracked.txt')
      cleanPath = path.join(workingDirectory, 'other.txt')
      fs.writeFileSync(cleanPath, 'Full of text')
      fs.writeFileSync(newPath, '')
      newPath = fs.absolute(newPath) // specs could be running under symbol path.
    })

    it('returns status information for all new and modified files', async () => {
      fs.writeFileSync(modifiedPath, 'making this path modified')
      await repo.refreshStatus()

      expect(repo.getCachedPathStatus(cleanPath)).toBeUndefined()
      expect(repo.isStatusNew(repo.getCachedPathStatus(newPath))).toBeTruthy()
      expect(repo.isStatusModified(repo.getCachedPathStatus(modifiedPath))).toBeTruthy()
    })
  })

  describe('buffer events', () => {
    beforeEach(() => {
      // This is sync, should be fine in a beforeEach
      atom.project.setPaths([copyRepository()])
    })

    it('emits a status-changed events when a buffer is saved', async () => {
      let editor = await atom.workspace.open('other.txt')

      editor.insertNewline()

      let repository = atom.project.getRepositories()[0].async
      let called
      subscriptions.add(repository.onDidChangeStatus(c => called = c))
      editor.save()

      await waitBetter(() => Boolean(called))
      expect(called).toEqual({path: editor.getPath(), pathStatus: 256})
    })

    it('emits a status-changed event when a buffer is reloaded', async () => {
      let statusHandler = jasmine.createSpy('statusHandler')
      let reloadHandler = jasmine.createSpy('reloadHandler')

      let editor = await atom.workspace.open('other.txt')

      fs.writeFileSync(editor.getPath(), 'changed')

      let repository = atom.project.getRepositories()[0].async
      subscriptions.add(repository.onDidChangeStatus(statusHandler))
      editor.getBuffer().reload()

      await waitBetter(() => statusHandler.callCount > 0)

      expect(statusHandler.callCount).toBe(1)
      expect(statusHandler).toHaveBeenCalledWith({path: editor.getPath(), pathStatus: 256})

      let buffer = editor.getBuffer()
      subscriptions.add(buffer.onDidReload(reloadHandler))
      buffer.reload()

      await waitBetter(() => reloadHandler.callCount > 0)

      expect(statusHandler.callCount).toBe(1)
    })

    it("emits a status-changed event when a buffer's path changes", async () => {
      let editor = await atom.workspace.open('other.txt')

      fs.writeFileSync(editor.getPath(), 'changed')

      let statusHandler = jasmine.createSpy('statusHandler')
      let repository = atom.project.getRepositories()[0].async
      subscriptions.add(repository.onDidChangeStatus(statusHandler))
      editor.getBuffer().emitter.emit('did-change-path')
      await waitBetter(() => statusHandler.callCount >= 1)

      expect(statusHandler.callCount).toBe(1)
      expect(statusHandler).toHaveBeenCalledWith({path: editor.getPath(), pathStatus: 256})

      let pathHandler = jasmine.createSpy('pathHandler')
      let buffer = editor.getBuffer()
      subscriptions.add(buffer.onDidChangePath(pathHandler))
      buffer.emitter.emit('did-change-path')
      await waitBetter(() => pathHandler.callCount >= 1)
      expect(statusHandler.callCount).toBe(1)
    })

    // it('stops listening to the buffer when the repository is destroyed (regression)', () => {
    //   waitsForPromise(() => {
    //     atom.workspace.open('other.txt').then(o => editor = o)
    //   })
    //   runs(() => {
    //     atom.project.getRepositories()[0].destroy()
    //     expect(-> editor.save()).not.toThrow()
    //   })
    // })
  })

})
