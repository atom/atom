'use babel'

const path = require('path')
const temp = require('temp')

const GitRepositoryAsync = require('../src/git-repository-async')

const openFixture = (fixture) => {
  GitRepositoryAsync.open(path.join(__dirname, 'fixtures', 'git', fixture))
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
    it('returns the repository path for a repository path', () => {
      let repo = openFixture('master.git')
      let onSuccess = jasmine.createSpy('onSuccess')
      waitsForPromise(repo.getPath().then(onSuccess))

      runs(() => {
        expect(onSuccess.mostRecentCall.args[0]).toBe(
          path.join(__dirname, 'fixtures', 'git', 'master.git')
        )
      })
    })
  })
})
