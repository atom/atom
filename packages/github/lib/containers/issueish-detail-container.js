import React from 'react';
import PropTypes from 'prop-types';
import yubikiri from 'yubikiri';
import {QueryRenderer, graphql} from 'react-relay';

import {PAGE_SIZE, CHECK_SUITE_PAGE_SIZE, CHECK_RUN_PAGE_SIZE} from '../helpers';
import RelayNetworkLayerManager from '../relay-network-layer-manager';
import {GithubLoginModelPropType, ItemTypePropType, EndpointPropType, RefHolderPropType} from '../prop-types';
import {UNAUTHENTICATED, INSUFFICIENT} from '../shared/keytar-strategy';
import GithubLoginView from '../views/github-login-view';
import LoadingView from '../views/loading-view';
import QueryErrorView from '../views/query-error-view';
import ErrorView from '../views/error-view';
import ObserveModel from '../views/observe-model';
import RelayEnvironment from '../views/relay-environment';
import AggregatedReviewsContainer from './aggregated-reviews-container';
import IssueishDetailController from '../controllers/issueish-detail-controller';

export default class IssueishDetailContainer extends React.Component {
  static propTypes = {
    // Connection
    endpoint: EndpointPropType.isRequired,

    // Issueish selection criteria
    owner: PropTypes.string.isRequired,
    repo: PropTypes.string.isRequired,
    issueishNumber: PropTypes.number.isRequired,

    // For opening files changed tab
    initChangedFilePath: PropTypes.string,
    initChangedFilePosition: PropTypes.number,
    selectedTab: PropTypes.number.isRequired,
    onTabSelected: PropTypes.func.isRequired,
    onOpenFilesTab: PropTypes.func.isRequired,

    // Package models
    repository: PropTypes.object.isRequired,
    loginModel: GithubLoginModelPropType.isRequired,

    // Atom environment
    workspace: PropTypes.object.isRequired,
    commands: PropTypes.object.isRequired,
    keymaps: PropTypes.object.isRequired,
    tooltips: PropTypes.object.isRequired,
    config: PropTypes.object.isRequired,

    // Action methods
    switchToIssueish: PropTypes.func.isRequired,
    onTitleChange: PropTypes.func.isRequired,
    destroy: PropTypes.func.isRequired,
    reportRelayError: PropTypes.func.isRequired,

    // Item context
    itemType: ItemTypePropType.isRequired,
    refEditor: RefHolderPropType.isRequired,
  }

  render() {
    return (
      <ObserveModel model={this.props.loginModel} fetchData={this.fetchToken}>
        {this.renderWithToken}
      </ObserveModel>
    );
  }

  renderWithToken = tokenData => {
    const token = tokenData && tokenData.token;

    if (token instanceof Error) {
      return (
        <QueryErrorView
          error={token}
          login={this.handleLogin}
          retry={this.handleTokenRetry}
          logout={this.handleLogout}
        />
      );
    }

    if (token === UNAUTHENTICATED) {
      return <GithubLoginView onLogin={this.handleLogin} />;
    }

    if (token === INSUFFICIENT) {
      return (
        <GithubLoginView onLogin={this.handleLogin}>
          <p>
            Your token no longer has sufficient authorizations. Please re-authenticate and generate a new one.
          </p>
        </GithubLoginView>
      );
    }

    return (
      <ObserveModel model={this.props.repository} fetchData={this.fetchRepositoryData}>
        {repoData => this.renderWithRepositoryData(token, repoData)}
      </ObserveModel>
    );
  }

  renderWithRepositoryData(token, repoData) {
    if (!token) {
      return <LoadingView />;
    }

    const environment = RelayNetworkLayerManager.getEnvironmentForHost(this.props.endpoint, token);
    const query = graphql`
      query issueishDetailContainerQuery
      (
        $repoOwner: String!
        $repoName: String!
        $issueishNumber: Int!
        $timelineCount: Int!
        $timelineCursor: String
        $commitCount: Int!
        $commitCursor: String
        $reviewCount: Int!
        $reviewCursor: String
        $threadCount: Int!
        $threadCursor: String
        $commentCount: Int!
        $commentCursor: String
        $checkSuiteCount: Int!
        $checkSuiteCursor: String
        $checkRunCount: Int!
        $checkRunCursor: String
      ) {
        repository(owner: $repoOwner, name: $repoName) {
          issueish: issueOrPullRequest(number: $issueishNumber) {
            __typename
            ... on PullRequest {
              ...aggregatedReviewsContainer_pullRequest @arguments(
                reviewCount: $reviewCount
                reviewCursor: $reviewCursor
                threadCount: $threadCount
                threadCursor: $threadCursor
                commentCount: $commentCount
                commentCursor: $commentCursor
              )
            }
          }

          ...issueishDetailController_repository @arguments(
            issueishNumber: $issueishNumber
            timelineCount: $timelineCount
            timelineCursor: $timelineCursor
            commitCount: $commitCount
            commitCursor: $commitCursor
            checkSuiteCount: $checkSuiteCount
            checkSuiteCursor: $checkSuiteCursor
            checkRunCount: $checkRunCount
            checkRunCursor: $checkRunCursor
          )
        }
      }
    `;
    const variables = {
      repoOwner: this.props.owner,
      repoName: this.props.repo,
      issueishNumber: this.props.issueishNumber,
      timelineCount: PAGE_SIZE,
      timelineCursor: null,
      commitCount: PAGE_SIZE,
      commitCursor: null,
      reviewCount: PAGE_SIZE,
      reviewCursor: null,
      threadCount: PAGE_SIZE,
      threadCursor: null,
      commentCount: PAGE_SIZE,
      commentCursor: null,
      checkSuiteCount: CHECK_SUITE_PAGE_SIZE,
      checkSuiteCursor: null,
      checkRunCount: CHECK_RUN_PAGE_SIZE,
      checkRunCursor: null,
    };

    return (
      <RelayEnvironment.Provider value={environment}>
        <QueryRenderer
          environment={environment}
          query={query}
          variables={variables}
          render={queryResult => this.renderWithQueryResult(token, repoData, queryResult)}
        />
      </RelayEnvironment.Provider>
    );
  }

  renderWithQueryResult(token, repoData, {error, props, retry}) {
    if (error) {
      return (
        <QueryErrorView
          error={error}
          login={this.handleLogin}
          retry={retry}
          logout={this.handleLogout}
        />
      );
    }

    if (!props || !repoData) {
      return <LoadingView />;
    }

    if (props.repository.issueish.__typename === 'PullRequest') {
      return (
        <AggregatedReviewsContainer
          pullRequest={props.repository.issueish}
          reportRelayError={this.props.reportRelayError}>
          {aggregatedReviews => this.renderWithCommentResult(token, repoData, {props, retry}, aggregatedReviews)}
        </AggregatedReviewsContainer>
      );
    } else {
      return this.renderWithCommentResult(
        token,
        repoData,
        {props, retry},
        {errors: [], commentThreads: [], loading: false},
      );
    }
  }

  renderWithCommentResult(token, repoData, {props, retry}, {errors, commentThreads, loading}) {
    const nonEmptyThreads = commentThreads.filter(each => each.comments && each.comments.length > 0);
    const totalCount = nonEmptyThreads.length;
    const resolvedCount = nonEmptyThreads.filter(each => each.thread.isResolved).length;

    if (errors && errors.length > 0) {
      const descriptions = errors.map(error => error.toString());

      return (
        <ErrorView
          title="Unable to fetch review comments"
          descriptions={descriptions}
          retry={retry}
          logout={this.handleLogout}
        />
      );
    }

    return (
      <IssueishDetailController
        {...props}
        {...repoData}
        reviewCommentsLoading={loading}
        reviewCommentsTotalCount={totalCount}
        reviewCommentsResolvedCount={resolvedCount}
        reviewCommentThreads={nonEmptyThreads}
        token={token}

        localRepository={this.props.repository}
        workdirPath={this.props.repository.getWorkingDirectoryPath()}

        issueishNumber={this.props.issueishNumber}
        onTitleChange={this.props.onTitleChange}
        switchToIssueish={this.props.switchToIssueish}
        initChangedFilePath={this.props.initChangedFilePath}
        initChangedFilePosition={this.props.initChangedFilePosition}
        selectedTab={this.props.selectedTab}
        onTabSelected={this.props.onTabSelected}
        onOpenFilesTab={this.props.onOpenFilesTab}
        endpoint={this.props.endpoint}
        reportRelayError={this.props.reportRelayError}

        workspace={this.props.workspace}
        commands={this.props.commands}
        keymaps={this.props.keymaps}
        tooltips={this.props.tooltips}
        config={this.props.config}

        itemType={this.props.itemType}
        destroy={this.props.destroy}
        refEditor={this.props.refEditor}
      />
    );
  }

  fetchToken = loginModel => {
    return yubikiri({
      token: loginModel.getToken(this.props.endpoint.getLoginAccount()),
    });
  }

  fetchRepositoryData = repository => {
    return yubikiri({
      branches: repository.getBranches(),
      remotes: repository.getRemotes(),
      isMerging: repository.isMerging(),
      isRebasing: repository.isRebasing(),
      isAbsent: repository.isAbsent(),
      isLoading: repository.isLoading(),
      isPresent: repository.isPresent(),
    });
  }

  handleLogin = token => this.props.loginModel.setToken(this.props.endpoint.getLoginAccount(), token);

  handleLogout = () => this.props.loginModel.removeToken(this.props.endpoint.getLoginAccount());

  handleTokenRetry = () => this.props.loginModel.didUpdate();
}
