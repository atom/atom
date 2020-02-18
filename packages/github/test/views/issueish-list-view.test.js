import React from 'react';
import {shallow} from 'enzyme';

import Branch, {nullBranch} from '../../lib/models/branch';
import BranchSet from '../../lib/models/branch-set';
import Issueish from '../../lib/models/issueish';
import IssueishListView from '../../lib/views/issueish-list-view';
import CheckSuitesAccumulator from '../../lib/containers/accumulators/check-suites-accumulator';
import {pullRequestBuilder} from '../builder/graphql/pr';

import issueishQuery from '../../lib/controllers/__generated__/issueishListController_results.graphql';

function createPullRequestResult({number, states}) {
  return pullRequestBuilder(issueishQuery)
    .number(number)
    .commits(conn => {
      conn.addNode(n => n.commit(c => {
        if (states) {
          c.status(st => {
            for (const state of states) {
              st.addContext(con => con.state(state));
            }
          });
        } else {
          c.nullStatus();
        }
      }));
    })
    .build();
}

const allGreen = new Issueish(createPullRequestResult({number: 1, states: ['SUCCESS', 'SUCCESS', 'SUCCESS']}));
const mixed = new Issueish(createPullRequestResult({number: 2, states: ['SUCCESS', 'PENDING', 'FAILURE']}));
const allRed = new Issueish(createPullRequestResult({number: 3, states: ['FAILURE', 'ERROR', 'FAILURE']}));
const noStatus = new Issueish(createPullRequestResult({number: 4, states: null}));

class CustomComponent extends React.Component {
  render() {
    return <div className="custom" />;
  }
}

describe('IssueishListView', function() {
  let branch, branchSet;

  beforeEach(function() {
    branch = new Branch('master', nullBranch, nullBranch, true);
    branchSet = new BranchSet();
    branchSet.add(branch);
  });

  function buildApp(overrideProps = {}) {
    return (
      <IssueishListView
        title="aaa"
        isLoading={true}
        total={0}
        issueishes={[]}

        onCreatePr={() => {}}
        onIssueishClick={() => {}}
        onMoreClick={() => {}}

        {...overrideProps}
      />
    );
  }

  it('sets the accordion title to the search name', function() {
    const wrapper = shallow(buildApp({
      title: 'the search name',
    }));
    assert.strictEqual(wrapper.find('Accordion').prop('leftTitle'), 'the search name');
  });

  describe('while loading', function() {
    it('sets its accordion as isLoading', function() {
      const wrapper = shallow(buildApp());
      assert.isTrue(wrapper.find('Accordion').prop('isLoading'));
    });

    it('passes an empty result list', function() {
      const wrapper = shallow(buildApp());
      assert.lengthOf(wrapper.find('Accordion').prop('results'), 0);
    });
  });

  describe('with empty results', function() {
    it('uses a custom EmptyComponent if one is provided', function() {
      const wrapper = shallow(buildApp({isLoading: false, emptyComponent: CustomComponent}));

      const empty = wrapper.find('Accordion').renderProp('emptyComponent')();
      assert.isTrue(empty.is(CustomComponent));
    });

    it('renders an error tile if an error is present', function() {
      const error = new Error('error');
      error.rawStack = error.stack;
      const wrapper = shallow(buildApp({isLoading: false, error}));

      const empty = wrapper.find('Accordion').renderProp('emptyComponent')();
      assert.isTrue(empty.is('QueryErrorTile'));
    });
  });

  describe('with nonempty results', function() {
    it('passes its results to the accordion', function() {
      const issueishes = [allGreen, mixed, allRed];
      const wrapper = shallow(buildApp({
        isLoading: false,
        total: 3,
        issueishes,
      }));
      assert.deepEqual(wrapper.find('Accordion').prop('results'), issueishes);
    });

    it('renders a check if all status checks are successful', function() {
      const wrapper = shallow(buildApp({isLoading: false, total: 1}));
      const result = wrapper.find('Accordion').renderProp('children')(allGreen);
      const accumulated = result.find(CheckSuitesAccumulator).renderProp('children')({runsBySuite: new Map()});
      assert.strictEqual(accumulated.find('Octicon.github-IssueishList-item--status').prop('icon'), 'check');
    });

    it('renders an x if all status checks have failed', function() {
      const wrapper = shallow(buildApp({isLoading: false, total: 1}));
      const result = wrapper.find('Accordion').renderProp('children')(allRed);
      const accumulated = result.find(CheckSuitesAccumulator).renderProp('children')({runsBySuite: new Map()});
      assert.strictEqual(accumulated.find('Octicon.github-IssueishList-item--status').prop('icon'), 'x');
    });

    it('renders a donut chart if status checks are mixed', function() {
      const wrapper = shallow(buildApp({isLoading: false, total: 1}));
      const result = wrapper.find('Accordion').renderProp('children')(mixed);
      const accumulated = result.find(CheckSuitesAccumulator).renderProp('children')({runsBySuite: new Map()});

      const chart = accumulated.find('StatusDonutChart');
      assert.strictEqual(chart.prop('pending'), 1);
      assert.strictEqual(chart.prop('failure'), 1);
      assert.strictEqual(chart.prop('success'), 1);
    });

    it('renders nothing with no status checks are present', function() {
      const wrapper = shallow(buildApp({isLoading: false, total: 1}));
      const result = wrapper.find('Accordion').renderProp('children')(noStatus);
      const accumulated = result.find(CheckSuitesAccumulator).renderProp('children')({runsBySuite: new Map()});

      assert.strictEqual(accumulated.find('Octicon.github-IssueishList-item--status').prop('icon'), 'dash');
    });

    it('calls its onIssueishClick handler when an item is clicked', function() {
      const onIssueishClick = sinon.stub();
      const wrapper = shallow(buildApp({isLoading: false, onIssueishClick}));

      wrapper.find('Accordion').prop('onClickItem')(mixed);
      assert.isTrue(onIssueishClick.calledWith(mixed));
    });

    it('calls its onMoreClick handler when a "more" component is clicked', function() {
      const onMoreClick = sinon.stub();
      const wrapper = shallow(buildApp({isLoading: false, onMoreClick}));

      const more = wrapper.find('Accordion').renderProp('moreComponent')();
      more.find('.github-IssueishList-more a').simulate('click');
      assert.isTrue(onMoreClick.called);
    });

    it('calls its `showActionsMenu` handler when the menu icon is clicked', function() {
      const issueishes = [allGreen, mixed, allRed];
      const showActionsMenu = sinon.stub();
      const wrapper = shallow(buildApp({
        isLoading: false,
        total: 3,
        issueishes,
        showActionsMenu,
      }));
      const result = wrapper.find('Accordion').renderProp('children')(mixed);
      const child = result.find(CheckSuitesAccumulator).renderProp('children')({runsBySuite: new Map()});

      child.find('Octicon.github-IssueishList-item--menu').simulate('click', {
        preventDefault() {},
        stopPropagation() {},
      });
      assert.isTrue(showActionsMenu.calledWith(mixed));
    });
  });

  it('renders review button only if needed', function() {
    const openReviews = sinon.spy();
    const wrapper = shallow(buildApp({total: 1, issueishes: [allGreen], openReviews}));
    const child0 = wrapper.find('Accordion').renderProp('reviewsButton')();
    assert.isFalse(child0.exists('.github-IssueishList-openReviewsButton'));

    wrapper.setProps({needReviewsButton: true});
    const child1 = wrapper.find('Accordion').renderProp('reviewsButton')();
    assert.isTrue(child1.exists('.github-IssueishList-openReviewsButton'));
    child1.find('.github-IssueishList-openReviewsButton').simulate('click', {stopPropagation() {}});
    assert.isTrue(openReviews.called);
  });
});
