import React from 'react';
import {shallow} from 'enzyme';

import IssueishTimelineView, {collectionRenderer} from '../../lib/views/issueish-timeline-view';

describe('IssueishTimelineView', function() {
  function buildApp(opts, overloadProps = {}) {
    const o = {
      relayHasMore: () => false,
      relayLoadMore: () => {},
      relayIsLoading: () => false,
      useIssue: true,
      timelineItemSpecs: [],
      timelineStartCursor: 0,
      ...opts,
    };

    if (o.timelineItemTotal === undefined) {
      o.timelineItemTotal = o.timelineItemSpecs.length;
    }

    const props = {
      switchToIssueish: () => {},
      relay: {
        hasMore: o.relayHasMore,
        loadMore: o.relayLoadMore,
        isLoading: o.relayIsLoading,
      },
      ...overloadProps,
    };

    const timelineItems = {
      edges: o.timelineItemSpecs.map((spec, i) => ({
        cursor: `result${i}`,
        node: {
          id: spec.id,
          __typename: spec.kind,
        },
      })),
      pageInfo: {
        startCursor: `result${o.timelineStartCursor}`,
        endCursor: `result${o.timelineStartCursor + o.timelineItemSpecs.length}`,
        hasNextPage: o.timelineStartCursor + o.timelineItemSpecs.length < o.timelineItemTotal,
        hasPreviousPage: o.timelineStartCursor !== 0,
      },
      totalCount: o.timelineItemTotal,
    };

    if (o.issueMode) {
      props.issue = {timelineItems};
    } else {
      props.pullRequest = {timelineItems};
    }

    return <IssueishTimelineView {...props} />;
  }

  it('separates timeline issues by typename and renders a grouped child component for each', function() {
    const wrapper = shallow(buildApp({
      timelineItemSpecs: [
        {kind: 'PullRequestCommit', id: 0},
        {kind: 'PullRequestCommit', id: 1},
        {kind: 'IssueComment', id: 2},
        {kind: 'MergedEvent', id: 3},
        {kind: 'PullRequestCommit', id: 4},
        {kind: 'PullRequestCommit', id: 5},
        {kind: 'PullRequestCommit', id: 6},
        {kind: 'PullRequestCommit', id: 7},
        {kind: 'IssueComment', id: 8},
        {kind: 'IssueComment', id: 9},
      ],
    }));

    const commitGroup0 = wrapper.find('ForwardRef(Relay(BareCommitsView))').filterWhere(c => c.prop('nodes').length === 2);
    assert.deepEqual(commitGroup0.prop('nodes').map(n => n.id), [0, 1]);

    const commentGroup0 = wrapper.find('Grouped(Relay(BareIssueCommentView))').filterWhere(c => c.prop('nodes').length === 1);
    assert.deepEqual(commentGroup0.prop('nodes').map(n => n.id), [2]);

    const mergedGroup = wrapper.find('Grouped(Relay(BareMergedEventView))').filterWhere(c => c.prop('nodes').length === 1);
    assert.deepEqual(mergedGroup.prop('nodes').map(n => n.id), [3]);

    const commitGroup1 = wrapper.find('ForwardRef(Relay(BareCommitsView))').filterWhere(c => c.prop('nodes').length === 4);
    assert.deepEqual(commitGroup1.prop('nodes').map(n => n.id), [4, 5, 6, 7]);

    const commentGroup1 = wrapper.find('Grouped(Relay(BareIssueCommentView))').filterWhere(c => c.prop('nodes').length === 2);
    assert.deepEqual(commentGroup1.prop('nodes').map(n => n.id), [8, 9]);
  });

  it('skips unrecognized timeline events', function() {
    sinon.stub(console, 'warn');

    const wrapper = shallow(buildApp({
      timelineItemSpecs: [
        {kind: 'PullRequestCommit', id: 0},
        {kind: 'PullRequestCommit', id: 1},
        {kind: 'FancyNewDotcomFeature', id: 2},
        {kind: 'IssueComment', id: 3},
      ],
    }));

    assert.lengthOf(wrapper.find('.github-PrTimeline').children(), 2);

    // eslint-disable-next-line no-console
    assert.isTrue(console.warn.calledWith('unrecognized timeline event type: FancyNewDotcomFeature'));
  });

  it('omits the load more link if there are no more events', function() {
    const wrapper = shallow(buildApp({
      relayHasMore: () => false,
    }));
    assert.isFalse(wrapper.find('.github-PrTimeline-loadMoreButton').exists());
  });

  it('renders a link to load more timeline events', function() {
    const relayLoadMore = sinon.stub().callsArg(1);
    const wrapper = shallow(buildApp({
      relayHasMore: () => true,
      relayLoadMore,
      relayIsLoading: () => false,
      timelineItemSpecs: [
        {kind: 'Commit', id: 0},
        {kind: 'IssueComment', id: 1},
      ],
    }));

    const button = wrapper.find('.github-PrTimeline-loadMoreButton');
    assert.strictEqual(button.text(), 'Load More');
    assert.isFalse(relayLoadMore.called);
    button.simulate('click');
    assert.isTrue(relayLoadMore.called);
  });

  it('renders ellipses while loading', function() {
    const wrapper = shallow(buildApp({
      relayHasMore: () => true,
      relayIsLoading: () => true,
    }));

    assert.isTrue(wrapper.find('Octicon[icon="ellipsis"]').exists());
  });

  describe('collectionRenderer', function() {
    class Item extends React.Component {
      render() {
        return <span>{this.props.item}</span>;
      }

      static getFragment(fragName) {
        return `item fragment for ${fragName}`;
      }
    }

    it('renders a child component for each node', function() {
      const Component = collectionRenderer(Item, false);
      const props = {
        issueish: {},
        switchToIssueish: () => {},
        nodes: [1, 2, 3],
      };
      const wrapper = shallow(<Component {...props} />);

      assert.isTrue(wrapper.find('Item').everyWhere(i => i.prop('issueish') === props.issueish));
      assert.isTrue(wrapper.find('Item').everyWhere(i => i.prop('switchToIssueish') === props.switchToIssueish));
      assert.deepEqual(wrapper.find('Item').map(i => i.prop('item')), [1, 2, 3]);
      assert.isFalse(wrapper.find('.timeline-item').exists());
    });

    it('optionally applies the timeline-item class', function() {
      const Component = collectionRenderer(Item, true);
      const props = {
        issueish: {},
        switchToIssueish: () => {},
        nodes: [1, 2, 3],
      };
      const wrapper = shallow(<Component {...props} />);
      assert.isTrue(wrapper.find('.timeline-item').exists());
    });

    it('translates the static getFragment call', function() {
      const Component = collectionRenderer(Item);
      assert.strictEqual(Component.getFragment('something'), 'item fragment for something');
      assert.strictEqual(Component.getFragment('nodes'), 'item fragment for item');
    });
  });
});
