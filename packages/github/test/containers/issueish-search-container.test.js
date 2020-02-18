import React from 'react';
import {shallow, mount} from 'enzyme';

import {CHECK_SUITE_PAGE_SIZE, CHECK_RUN_PAGE_SIZE} from '../../lib/helpers';
import {expectRelayQuery} from '../../lib/relay-network-layer-manager';
import Search, {nullSearch} from '../../lib/models/search';
import {getEndpoint} from '../../lib/models/endpoint';
import IssueishSearchContainer from '../../lib/containers/issueish-search-container';
import {ManualStateObserver} from '../helpers';
import {relayResponseBuilder} from '../builder/graphql/query';

describe('IssueishSearchContainer', function() {
  let observer;

  beforeEach(function() {
    observer = new ManualStateObserver();
  });

  function buildApp(overrideProps = {}) {
    return (
      <IssueishSearchContainer
        token="1234"
        endpoint={getEndpoint('github.com')}
        search={new Search('default', 'type:pr')}
        remoteOperationObserver={observer}

        onOpenIssueish={() => {}}
        onOpenSearch={() => {}}
        onOpenReviews={() => {}}

        {...overrideProps}
      />
    );
  }

  it('performs no query for a null Search', function() {
    const wrapper = shallow(buildApp({search: nullSearch}));

    assert.isFalse(wrapper.find('ReactRelayQueryRenderer').exists());
    const list = wrapper.find('BareIssueishListController');
    assert.isTrue(list.exists());
    assert.isFalse(list.prop('isLoading'));
    assert.strictEqual(list.prop('total'), 0);
    assert.lengthOf(list.prop('results'), 0);
  });

  it('renders a query for the Search', async function() {
    const {resolve, promise} = expectRelayQuery({
      name: 'issueishSearchContainerQuery',
      variables: {
        query: 'type:pr author:me',
      },
    }, {
      search: {issueCount: 0, nodes: []},
    });

    const search = new Search('pull requests', 'type:pr author:me');
    const wrapper = shallow(buildApp({search}));
    assert.strictEqual(wrapper.find('ReactRelayQueryRenderer').prop('variables').query, 'type:pr author:me');
    resolve();
    await promise;
  });

  it('passes an empty result list and an isLoading prop to the controller while loading', async function() {
    const {resolve, promise} = expectRelayQuery({
      name: 'issueishSearchContainerQuery',
      variables: {
        query: 'type:pr author:me',
        first: 20,
        checkSuiteCount: CHECK_SUITE_PAGE_SIZE,
        checkSuiteCursor: null,
        checkRunCount: CHECK_RUN_PAGE_SIZE,
        checkRunCursor: null,
      },
    }, op => {
      return relayResponseBuilder(op)
        .build();
    });

    const search = new Search('pull requests', 'type:pr author:me');
    const wrapper = mount(buildApp({search}));

    const controller = wrapper.find('BareIssueishListController');
    assert.isTrue(controller.prop('isLoading'));

    resolve();
    await promise;
  });

  describe('when the query errors', function() {

    // Consumes the failing Relay Query console error
    beforeEach(function() {
      sinon.stub(console, 'error').withArgs(
        'Error encountered in subquery',
        sinon.match.defined.and(sinon.match.hasNested('errors[0].message', sinon.match('uh oh'))),
      ).callsFake(() => {}).callThrough();
    });

    it('passes an empty result list and an error prop to the controller', async function() {
      expectRelayQuery({
        name: 'issueishSearchContainerQuery',
        variables: {
          query: 'type:pr',
          first: 20,
          checkSuiteCount: CHECK_SUITE_PAGE_SIZE,
          checkSuiteCursor: null,
          checkRunCount: CHECK_RUN_PAGE_SIZE,
          checkRunCursor: null,
        },
      }, op => {
        return relayResponseBuilder(op)
          .addError('uh oh')
          .build();
      }).resolve();

      const wrapper = mount(buildApp({}));
      await assert.async.isTrue(
        wrapper.update().find('BareIssueishListController').filterWhere(n => !n.prop('isLoading')).exists(),
      );
      const controller = wrapper.find('BareIssueishListController');
      assert.deepEqual(controller.prop('error').errors, [{message: 'uh oh'}]);
      assert.lengthOf(controller.prop('results'), 0);
    });
  });

  it('passes results to the controller', async function() {
    const {promise, resolve} = expectRelayQuery({
      name: 'issueishSearchContainerQuery',
      variables: {
        query: 'type:pr author:me',
        first: 20,
        checkSuiteCount: CHECK_SUITE_PAGE_SIZE,
        checkSuiteCursor: null,
        checkRunCount: CHECK_RUN_PAGE_SIZE,
        checkRunCursor: null,
      },
    }, op => {
      return relayResponseBuilder(op)
        .search(s => {
          s.issueCount(2);
          s.addNode(n => n.bePullRequest(pr => {
            pr.id('pr0');
            pr.number(1);
            pr.commits(conn => conn.addNode());
          }));
          s.addNode(n => n.bePullRequest(pr => {
            pr.id('pr1');
            pr.number(2);
            pr.commits(conn => conn.addNode());
          }));
        })
        .build();
    });

    const search = new Search('pull requests', 'type:pr author:me');
    const wrapper = mount(buildApp({search}));

    resolve();
    await promise;

    const controller = wrapper.update().find('BareIssueishListController');
    assert.isFalse(controller.prop('isLoading'));
    assert.strictEqual(controller.prop('total'), 2);
    assert.isTrue(controller.prop('results').some(node => node.number === 1));
    assert.isTrue(controller.prop('results').some(node => node.number === 2));
  });
});
