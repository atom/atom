import React from 'react';
import PropTypes from 'prop-types';
import {QueryRenderer, graphql} from 'react-relay';
import {Disposable} from 'event-kit';

import {autobind, CHECK_SUITE_PAGE_SIZE, CHECK_RUN_PAGE_SIZE} from '../helpers';
import {SearchPropType, EndpointPropType} from '../prop-types';
import IssueishListController, {BareIssueishListController} from '../controllers/issueish-list-controller';
import RelayNetworkLayerManager from '../relay-network-layer-manager';

export default class IssueishSearchContainer extends React.Component {
  static propTypes = {
    // Connection information
    endpoint: EndpointPropType.isRequired,
    token: PropTypes.string.isRequired,

    // Search model
    limit: PropTypes.number,
    search: SearchPropType.isRequired,

    // Action methods
    onOpenIssueish: PropTypes.func.isRequired,
    onOpenSearch: PropTypes.func.isRequired,
    onOpenReviews: PropTypes.func.isRequired,
  }

  static defaultProps = {
    limit: 20,
  }

  constructor(props) {
    super(props);
    autobind(this, 'renderQueryResult');

    this.sub = new Disposable();
  }

  render() {
    const environment = RelayNetworkLayerManager.getEnvironmentForHost(this.props.endpoint, this.props.token);

    if (this.props.search.isNull()) {
      return (
        <BareIssueishListController
          isLoading={false}
          {...this.controllerProps()}
        />
      );
    }

    const query = graphql`
      query issueishSearchContainerQuery(
        $query: String!
        $first: Int!
        $checkSuiteCount: Int!
        $checkSuiteCursor: String
        $checkRunCount: Int!
        $checkRunCursor: String
      ) {
        search(first: $first, query: $query, type: ISSUE) {
          issueCount
          nodes {
            ...issueishListController_results @arguments(
              checkSuiteCount: $checkSuiteCount
              checkSuiteCursor: $checkSuiteCursor
              checkRunCount: $checkRunCount
              checkRunCursor: $checkRunCursor
            )
          }
        }
      }
    `;
    const variables = {
      query: this.props.search.createQuery(),
      first: this.props.limit,
      checkSuiteCount: CHECK_SUITE_PAGE_SIZE,
      checkSuiteCursor: null,
      checkRunCount: CHECK_RUN_PAGE_SIZE,
      checkRunCursor: null,
    };

    return (
      <QueryRenderer
        environment={environment}
        variables={variables}
        query={query}
        render={this.renderQueryResult}
      />
    );
  }

  renderQueryResult({error, props}) {
    if (error) {
      return (
        <BareIssueishListController
          isLoading={false}
          error={error}
          {...this.controllerProps()}
        />
      );
    }

    if (props === null) {
      return (
        <BareIssueishListController
          isLoading={true}
          {...this.controllerProps()}
        />
      );
    }

    return (
      <IssueishListController
        total={props.search.issueCount}
        results={props.search.nodes}
        isLoading={false}
        {...this.controllerProps()}
      />
    );
  }

  componentWillUnmount() {
    this.sub.dispose();
  }

  controllerProps() {
    return {
      title: this.props.search.getName(),

      onOpenIssueish: this.props.onOpenIssueish,
      onOpenReviews: this.props.onOpenReviews,
      onOpenMore: () => this.props.onOpenSearch(this.props.search),
    };
  }
}
