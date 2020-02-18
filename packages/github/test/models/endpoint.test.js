import {getEndpoint} from '../../lib/models/endpoint';

describe('Endpoint', function() {
  describe('on dotcom', function() {
    let dotcom;

    beforeEach(function() {
      dotcom = getEndpoint('github.com');
    });

    it('identifies the GraphQL resource URI', function() {
      assert.strictEqual(dotcom.getGraphQLRoot(), 'https://api.github.com/graphql');
    });

    it('identifies the REST base resource URI', function() {
      assert.strictEqual(dotcom.getRestRoot(), 'https://api.github.com');
      assert.strictEqual(dotcom.getRestURI(), 'https://api.github.com');
    });

    it('joins additional path segments to a REST URI', function() {
      assert.strictEqual(dotcom.getRestURI('sub', 're?source'), 'https://api.github.com/sub/re%3Fsource');
    });

    it('accesses the hostname', function() {
      assert.strictEqual(dotcom.getHost(), 'github.com');
    });

    it('accesses a login model account', function() {
      assert.strictEqual(dotcom.getLoginAccount(), 'https://api.github.com');
    });
  });

  describe('an enterprise instance', function() {
    let enterprise;

    beforeEach(function() {
      enterprise = getEndpoint('github.horse');
    });

    it('identifies the GraphQL resource URI', function() {
      assert.strictEqual(enterprise.getGraphQLRoot(), 'https://github.horse/api/v3/graphql');
    });

    it('identifies the REST base resource URI', function() {
      assert.strictEqual(enterprise.getRestRoot(), 'https://github.horse/api/v3');
      assert.strictEqual(enterprise.getRestURI(), 'https://github.horse/api/v3');
    });

    it('joins additional path segments to the REST URI', function() {
      assert.strictEqual(enterprise.getRestURI('sub', 're?source'), 'https://github.horse/api/v3/sub/re%3Fsource');
    });

    it('accesses the hostname', function() {
      assert.strictEqual(enterprise.getHost(), 'github.horse');
    });

    it('accesses a login model key', function() {
      assert.strictEqual(enterprise.getLoginAccount(), 'https://github.horse');
    });
  });
});
