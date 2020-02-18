import {graphql, createPaginationContainer} from 'react-relay';

import IssueishTimelineView from '../views/issueish-timeline-view';

export default createPaginationContainer(IssueishTimelineView, {
  pullRequest: graphql`
    fragment prTimelineController_pullRequest on PullRequest
    @argumentDefinitions(
      timelineCount: {type: "Int!"},
      timelineCursor: {type: "String"}
    ) {
      url
      ...headRefForcePushedEventView_issueish
      timelineItems(first: $timelineCount, after: $timelineCursor)
      @connection(key: "prTimelineContainer_timelineItems") {
        pageInfo { endCursor hasNextPage }
        edges {
          cursor
          node {
            __typename
            ...commitsView_nodes
            ...issueCommentView_item
            ...mergedEventView_item
            ...headRefForcePushedEventView_item
            ...commitCommentThreadView_item
            ...crossReferencedEventsView_nodes
          }
        }
      }
    }
  `,
}, {
  direction: 'forward',
  getConnectionFromProps(props) {
    return props.pullRequest.timeline;
  },
  getFragmentVariables(prevVars, totalCount) {
    return {
      ...prevVars,
      timelineCount: totalCount,
    };
  },
  getVariables(props, {count, cursor}, fragmentVariables) {
    return {
      url: props.pullRequest.url,
      timelineCount: count,
      timelineCursor: cursor,
    };
  },
  query: graphql`
    query prTimelineControllerQuery($timelineCount: Int!, $timelineCursor: String, $url: URI!) {
      resource(url: $url) {
        ... on PullRequest {
          ...prTimelineController_pullRequest @arguments(
            timelineCount: $timelineCount,
            timelineCursor: $timelineCursor
          )
        }
      }
    }
  `,
});
