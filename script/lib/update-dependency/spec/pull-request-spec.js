const nock = require('nock');
const { createPR, findPR } = require('../pull-request');
const createPrResponse = require('./fixtures/create-pr-response.json');
const searchResponse = require('./fixtures/search-response.json');

describe('Pull Request', () => {
  it('Should create a pull request', async () => {
    const scope = nock('https://api.github.com')
      .post('/repos/atom/atom/pulls', {
        title: '⬆️ octocat@2.0.0',
        body: 'Bumps octocat from 1.0.0 to 2.0.0',
        head: 'octocat-2.0.0',
        base: 'master'
      })
      .reply(200, createPrResponse);
    const response = await createPR(
      {
        moduleName: 'octocat',
        installed: '1.0.0',
        latest: '2.0.0',
        isCorePackage: false
      },
      'octocat-2.0.0'
    );
    scope.done();

    expect(response.data).toEqual(createPrResponse);
  });

  it('Should search for a pull request', async () => {
    const scope = nock('https://api.github.com')
      .get('/search/issues')
      .query({
        q:
          'octocat type:pr octocat@2.0.0 in:title repo:atom/atom head:octocat-2.0.0 state:open',
        owner: 'atom',
        repo: 'atom'
      })
      .reply(200, searchResponse);

    const response = await findPR(
      {
        moduleName: 'octocat',
        installed: '1.0.0',
        latest: '2.0.0'
      },
      'octocat-2.0.0'
    );
    scope.done();

    expect(response.data).toEqual(searchResponse);
  });
});
