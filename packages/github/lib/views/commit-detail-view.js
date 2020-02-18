import React from 'react';
import PropTypes from 'prop-types';
import {emojify} from 'node-emoji';
import moment from 'moment';

import MultiFilePatchController from '../controllers/multi-file-patch-controller';
import Commands, {Command} from '../atom/commands';
import RefHolder from '../models/ref-holder';

export default class CommitDetailView extends React.Component {
  static drilledPropTypes = {
    // Model properties
    repository: PropTypes.object.isRequired,
    commit: PropTypes.object.isRequired,
    currentRemote: PropTypes.object.isRequired,
    isCommitPushed: PropTypes.bool.isRequired,
    itemType: PropTypes.func.isRequired,

    // Atom environment
    workspace: PropTypes.object.isRequired,
    commands: PropTypes.object.isRequired,
    keymaps: PropTypes.object.isRequired,
    tooltips: PropTypes.object.isRequired,
    config: PropTypes.object.isRequired,

    // Action functions
    destroy: PropTypes.func.isRequired,
    surfaceCommit: PropTypes.func.isRequired,
  }

  static propTypes = {
    ...CommitDetailView.drilledPropTypes,

    // Controller state
    messageCollapsible: PropTypes.bool.isRequired,
    messageOpen: PropTypes.bool.isRequired,

    // Action functions
    toggleMessage: PropTypes.func.isRequired,
  }

  constructor(props) {
    super(props);

    this.refRoot = new RefHolder();
  }

  render() {
    const commit = this.props.commit;

    return (
      <div className="github-CommitDetailView" ref={this.refRoot.setter}>
        {this.renderCommands()}
        <div className="github-CommitDetailView-header native-key-bindings" tabIndex="-1">
          <div className="github-CommitDetailView-commit">
            <h3 className="github-CommitDetailView-title">
              {emojify(commit.getMessageSubject())}
            </h3>
            <div className="github-CommitDetailView-meta">
              {this.renderAuthors()}
              <span className="github-CommitDetailView-metaText">
                {this.getAuthorInfo()} committed {this.humanizeTimeSince(commit.getAuthorDate())}
              </span>
              <div className="github-CommitDetailView-sha">
                {this.renderDotComLink()}
              </div>
            </div>
            {this.renderShowMoreButton()}
            {this.renderCommitMessageBody()}
          </div>
        </div>
        <MultiFilePatchController
          multiFilePatch={commit.getMultiFileDiff()}
          surface={this.props.surfaceCommit}
          {...this.props}
        />
      </div>
    );
  }

  renderCommands() {
    return (
      <Commands registry={this.props.commands} target={this.refRoot}>
        <Command command="github:surface" callback={this.props.surfaceCommit} />
      </Commands>
    );
  }

  renderCommitMessageBody() {
    const collapsed = this.props.messageCollapsible && !this.props.messageOpen;

    return (
      <pre className="github-CommitDetailView-moreText">
        {collapsed ? this.props.commit.abbreviatedBody() : this.props.commit.getMessageBody()}
      </pre>
    );
  }

  renderShowMoreButton() {
    if (!this.props.messageCollapsible) {
      return null;
    }

    const buttonText = this.props.messageOpen ? 'Show Less' : 'Show More';
    return (
      <button className="github-CommitDetailView-moreButton" onClick={this.props.toggleMessage}>{buttonText}</button>
    );
  }

  humanizeTimeSince(date) {
    return moment(date * 1000).fromNow();
  }

  renderDotComLink() {
    const remote = this.props.currentRemote;
    const sha = this.props.commit.getSha();
    if (remote.isGithubRepo() && this.props.isCommitPushed) {
      const repoUrl = `https://github.com/${remote.getOwner()}/${remote.getRepo()}`;
      return (
        <a href={`${repoUrl}/commit/${sha}`}
          title={`open commit ${sha} on GitHub.com`}>
          {sha}
        </a>
      );
    } else {
      return (<span>{sha}</span>);
    }
  }

  getAuthorInfo() {
    const commit = this.props.commit;
    const coAuthorCount = commit.getCoAuthors().length;
    if (coAuthorCount === 0) {
      return commit.getAuthorName();
    } else if (coAuthorCount === 1) {
      return `${commit.getAuthorName()} and ${commit.getCoAuthors()[0].getFullName()}`;
    } else {
      return `${commit.getAuthorName()} and ${coAuthorCount} others`;
    }
  }

  renderAuthor(author) {
    const email = author.getEmail();
    const avatarUrl = author.getAvatarUrl();

    return (
      <img className="github-CommitDetailView-avatar github-RecentCommit-avatar"
        key={email}
        src={avatarUrl}
        title={email}
        alt={`${email}'s avatar'`}
      />
    );
  }

  renderAuthors() {
    const coAuthors = this.props.commit.getCoAuthors();
    const authors = [this.props.commit.getAuthor(), ...coAuthors];

    return (
      <span className="github-CommitDetailView-authors github-RecentCommit-authors">
        {authors.map(this.renderAuthor)}
      </span>
    );
  }
}
