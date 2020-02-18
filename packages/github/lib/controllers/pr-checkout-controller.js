import React from 'react';
import PropTypes from 'prop-types';
import {graphql, createFragmentContainer} from 'react-relay';

import EnableableOperation from '../models/enableable-operation';
import {GitError} from '../git-shell-out-strategy';
import {RemoteSetPropType, BranchSetPropType} from '../prop-types';
import {incrementCounter} from '../reporter-proxy';

class CheckoutState {
  constructor(name) {
    this.name = name;
  }

  when(cases) {
    return cases[this.name] || cases.default;
  }
}

export const checkoutStates = {
  HIDDEN: new CheckoutState('hidden'),
  DISABLED: new CheckoutState('disabled'),
  BUSY: new CheckoutState('busy'),
  CURRENT: new CheckoutState('current'),
};

export class BarePullRequestCheckoutController extends React.Component {
  static propTypes = {
    // GraphQL response
    repository: PropTypes.shape({
      name: PropTypes.string.isRequired,
      owner: PropTypes.shape({
        login: PropTypes.string.isRequired,
      }).isRequired,
    }).isRequired,
    pullRequest: PropTypes.shape({
      number: PropTypes.number.isRequired,
      headRefName: PropTypes.string.isRequired,
      headRepository: PropTypes.shape({
        name: PropTypes.string.isRequired,
        url: PropTypes.string.isRequired,
        sshUrl: PropTypes.string.isRequired,
        owner: PropTypes.shape({
          login: PropTypes.string.isRequired,
        }),
      }),
    }).isRequired,

    // Repository model and attributes
    localRepository: PropTypes.object.isRequired,
    isAbsent: PropTypes.bool.isRequired,
    isLoading: PropTypes.bool.isRequired,
    isPresent: PropTypes.bool.isRequired,
    isMerging: PropTypes.bool.isRequired,
    isRebasing: PropTypes.bool.isRequired,
    branches: BranchSetPropType.isRequired,
    remotes: RemoteSetPropType.isRequired,

    children: PropTypes.func.isRequired,
  }

  constructor(props) {
    super(props);

    this.state = {
      checkoutInProgress: false,
    };

    this.checkoutOp = new EnableableOperation(
      () => this.checkout().catch(e => {
        if (!(e instanceof GitError)) {
          throw e;
        }
      }),
    );
    this.checkoutOp.toggleState(this, 'checkoutInProgress');
  }

  render() {
    return this.props.children(this.nextCheckoutOp());
  }

  nextCheckoutOp() {
    const {repository, pullRequest} = this.props;

    if (this.props.isAbsent) {
      return this.checkoutOp.disable(checkoutStates.HIDDEN, 'No repository found');
    }

    if (this.props.isLoading) {
      return this.checkoutOp.disable(checkoutStates.DISABLED, 'Loading');
    }

    if (!this.props.isPresent) {
      return this.checkoutOp.disable(checkoutStates.DISABLED, 'No repository found');
    }

    if (this.props.isMerging) {
      return this.checkoutOp.disable(checkoutStates.DISABLED, 'Merge in progress');
    }

    if (this.props.isRebasing) {
      return this.checkoutOp.disable(checkoutStates.DISABLED, 'Rebase in progress');
    }

    if (this.state.checkoutInProgress) {
      return this.checkoutOp.disable(checkoutStates.DISABLED, 'Checking out...');
    }

    // determine if pullRequest.headRepository is null
    // this can happen if a repository has been deleted.
    if (!pullRequest.headRepository) {
      return this.checkoutOp.disable(checkoutStates.DISABLED, 'Pull request head repository does not exist');
    }

    // Determine if we already have this PR checked out.

    const headPush = this.props.branches.getHeadBranch().getPush();
    const headRemote = this.props.remotes.withName(headPush.getRemoteName());

    // (detect checkout from pull/### refspec)
    const fromPullRefspec =
      headRemote.getOwner() === repository.owner.login &&
      headRemote.getRepo() === repository.name &&
      headPush.getShortRemoteRef() === `pull/${pullRequest.number}/head`;

    // (detect checkout from head repository)
    const fromHeadRepo =
      headRemote.getOwner() === pullRequest.headRepository.owner.login &&
      headRemote.getRepo() === pullRequest.headRepository.name &&
      headPush.getShortRemoteRef() === pullRequest.headRefName;

    if (fromPullRefspec || fromHeadRepo) {
      return this.checkoutOp.disable(checkoutStates.CURRENT, 'Current');
    }

    return this.checkoutOp.enable();
  }

  async checkout() {
    const {pullRequest} = this.props;
    const {headRepository} = pullRequest;

    const fullHeadRef = `refs/heads/${pullRequest.headRefName}`;

    let sourceRemoteName, localRefName;

    // Discover or create a remote pointing to the repo containing the pull request's head ref.
    // If the local repository already has the head repository specified as a remote, that remote will be used, so
    // that any related configuration is picked up for the fetch. Otherwise, the head repository fetch URL is used
    // directly.
    const headRemotes = this.props.remotes.matchingGitHubRepository(headRepository.owner.login, headRepository.name);
    if (headRemotes.length > 0) {
      sourceRemoteName = headRemotes[0].getName();
    } else {
      const url = {
        https: headRepository.url + '.git',
        ssh: headRepository.sshUrl,
      }[this.props.remotes.mostUsedProtocol(['https', 'ssh'])];

      // This will throw if a remote with this name already exists (and points somewhere else, or we would have found
      // it above). ¯\_(ツ)_/¯
      const remote = await this.props.localRepository.addRemote(headRepository.owner.login, url);
      sourceRemoteName = remote.getName();
    }

    // Identify an existing local ref that already corresponds to the pull request, if one exists. Otherwise, generate
    // a new local ref name.
    const pullTargets = this.props.branches.getPullTargets(sourceRemoteName, fullHeadRef);
    if (pullTargets.length > 0) {
      localRefName = pullTargets[0].getName();

      // Check out the existing local ref.
      await this.props.localRepository.checkout(localRefName);
      try {
        await this.props.localRepository.pull(fullHeadRef, {remoteName: sourceRemoteName, ffOnly: true});
      } finally {
        incrementCounter('checkout-pr');
      }

      return;
    }

    await this.props.localRepository.fetch(fullHeadRef, {remoteName: sourceRemoteName});

    // Check out the local ref and set it up to track the head ref.
    await this.props.localRepository.checkout(
      `pr-${pullRequest.number}/${headRepository.owner.login}/${pullRequest.headRefName}`,
      {createNew: true, track: true, startPoint: `refs/remotes/${sourceRemoteName}/${pullRequest.headRefName}`,
      });

    incrementCounter('checkout-pr');
  }
}

export default createFragmentContainer(BarePullRequestCheckoutController, {
  repository: graphql`
    fragment prCheckoutController_repository on Repository {
      name
      owner {
        login
      }
    }
  `,
  pullRequest: graphql`
    fragment prCheckoutController_pullRequest on PullRequest {
      number
      headRefName
      headRepository {
        name
        url
        sshUrl
        owner {
          login
        }
      }
    }
  `,
});
