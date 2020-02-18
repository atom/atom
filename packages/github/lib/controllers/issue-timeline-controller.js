import {graphql, createPaginationContainer} from 'react-relay';

import IssueishTimelineView from '../views/issueish-timeline-view';

export default createPaginationContainer(IssueishTimelineView, {
  issue: graphql`
    fragment issueTimelineController_issue on Issue
    @argumentDefinitions(
      timelineCount: {type: "Int!"},
      timelineCursor: {type: "String"}
    ) {
      url
      timelineItems(
        first: $timelineCount, after: $timelineCursor
      ) @connection(key: "IssueTimelineController_timelineItems") {
        pageInfo { endCursor hasNextPage }
        edges {
          cursor
          node {
            __typename
            ...issueCommentView_item
            ...crossReferencedEventsView_nodes
          }
        }
      }
    }
  `,
}, {
  direction: 'forward',
  getConnectionFromProps(props) {
    return props.issue.timeline;
  },
  getFragmentVariables(prevVars, totalCount) {
    return {
      ...prevVars,
      timelineCount: totalCount,
    };
  },
  getVariables(props, {count, cursor}, fragmentVariables) {
    return {
      url: props.issue.url,
      timelineCount: count,
      timelineCursor: cursor,
    };
  },
  query: graphql`
    query issueTimelineControllerQuery($timelineCount: Int!, $timelineCursor: String, $url: URI!) {
      resource(url: $url) {
        ... on Issue {
          ...issueTimelineController_issue @arguments(timelineCount: $timelineCount, timelineCursor: $timelineCursor)
        }
      }
    }
  `,
});
