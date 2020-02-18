import React from 'react';
import PropTypes from 'prop-types';
import moment from 'moment';
import cx from 'classnames';
import {emojify} from 'node-emoji';

import Commands, {Command} from '../atom/commands';
import RefHolder from '../models/ref-holder';

import CommitView from './commit-view';
import Timeago from './timeago';

class RecentCommitView extends React.Component {
  static propTypes = {
    commands: PropTypes.object.isRequired,
    clipboard: PropTypes.object.isRequired,
    commit: PropTypes.object.isRequired,
    undoLastCommit: PropTypes.func.isRequired,
    isMostRecent: PropTypes.bool.isRequired,
    openCommit: PropTypes.func.isRequired,
    isSelected: PropTypes.bool.isRequired,
  };

  constructor(props) {
    super(props);

    this.refRoot = new RefHolder();
  }

  componentDidMount() {
    if (this.props.isSelected) {
      this.refRoot.map(root => root.scrollIntoViewIfNeeded(false));
    }
  }

  componentDidUpdate(prevProps) {
    if (this.props.isSelected && !prevProps.isSelected) {
      this.refRoot.map(root => root.scrollIntoViewIfNeeded(false));
    }
  }

  render() {
    const authorMoment = moment(this.props.commit.getAuthorDate() * 1000);
    const fullMessage = this.props.commit.getFullMessage();

    return (
      <li
        ref={this.refRoot.setter}
        className={cx('github-RecentCommit', {
          'most-recent': this.props.isMostRecent,
          'is-selected': this.props.isSelected,
        })}
        onClick={this.props.openCommit}>
        <Commands registry={this.props.commands} target={this.refRoot}>
          <Command command="github:copy-commit-sha" callback={this.copyCommitSha} />
          <Command command="github:copy-commit-subject" callback={this.copyCommitSubject} />
        </Commands>
        {this.renderAuthors()}
        <span
          className="github-RecentCommit-message"
          title={emojify(fullMessage)}>
          {emojify(this.props.commit.getMessageSubject())}
        </span>
        {this.props.isMostRecent && (
          <button
            className="btn github-RecentCommit-undoButton"
            onClick={this.undoLastCommit}>
            Undo
          </button>
        )}
        <Timeago
          className="github-RecentCommit-time"
          type="time"
          displayStyle="short"
          time={authorMoment}
          title={authorMoment.format('MMM Do, YYYY')}
        />
      </li>
    );
  }

  renderAuthor(author) {
    const email = author.getEmail();
    const avatarUrl = author.getAvatarUrl();

    return (
      <img className="github-RecentCommit-avatar"
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
      <span className="github-RecentCommit-authors">
        {authors.map(this.renderAuthor)}
      </span>
    );
  }

  copyCommitSha = event => {
    event.stopPropagation();
    const {commit, clipboard} = this.props;
    clipboard.write(commit.sha);
  }

  copyCommitSubject = event => {
    event.stopPropagation();
    const {commit, clipboard} = this.props;
    clipboard.write(commit.messageSubject);
  }

  undoLastCommit = event => {
    event.stopPropagation();
    this.props.undoLastCommit();
  }
}

export default class RecentCommitsView extends React.Component {
  static propTypes = {
    // Model state
    commits: PropTypes.arrayOf(PropTypes.object).isRequired,
    isLoading: PropTypes.bool.isRequired,
    selectedCommitSha: PropTypes.string.isRequired,

    // Atom environment
    clipboard: PropTypes.object.isRequired,
    commands: PropTypes.object.isRequired,

    // Action methods
    undoLastCommit: PropTypes.func.isRequired,
    openCommit: PropTypes.func.isRequired,
    selectNextCommit: PropTypes.func.isRequired,
    selectPreviousCommit: PropTypes.func.isRequired,
  };

  static focus = {
    RECENT_COMMIT: Symbol('recent_commit'),
  };

  static firstFocus = RecentCommitsView.focus.RECENT_COMMIT;

  static lastFocus = RecentCommitsView.focus.RECENT_COMMIT;

  constructor(props) {
    super(props);
    this.refRoot = new RefHolder();
  }

  setFocus(focus) {
    if (focus === this.constructor.focus.RECENT_COMMIT) {
      return this.refRoot.map(element => {
        element.focus();
        return true;
      }).getOr(false);
    }

    return false;
  }

  getFocus(element) {
    return this.refRoot.map(e => e.contains(element)).getOr(false)
      ? this.constructor.focus.RECENT_COMMIT
      : null;
  }

  render() {
    return (
      <div className="github-RecentCommits" tabIndex="-1" ref={this.refRoot.setter}>
        <Commands registry={this.props.commands} target={this.refRoot}>
          <Command command="core:move-down" callback={this.props.selectNextCommit} />
          <Command command="core:move-up" callback={this.props.selectPreviousCommit} />
          <Command command="github:dive" callback={this.openSelectedCommit} />
        </Commands>
        {this.renderCommits()}
      </div>
    );
  }

  renderCommits() {
    if (this.props.commits.length === 0) {
      if (this.props.isLoading) {
        return (
          <div className="github-RecentCommits-message">
            Recent commits
          </div>
        );
      } else {
        return (
          <div className="github-RecentCommits-message">
            Make your first commit
          </div>
        );
      }
    } else {
      return (
        <ul className="github-RecentCommits-list">
          {this.props.commits.map((commit, i) => {
            return (
              <RecentCommitView
                key={commit.getSha()}
                commands={this.props.commands}
                clipboard={this.props.clipboard}
                isMostRecent={i === 0}
                commit={commit}
                undoLastCommit={this.props.undoLastCommit}
                openCommit={() => this.props.openCommit({sha: commit.getSha(), preserveFocus: true})}
                isSelected={this.props.selectedCommitSha === commit.getSha()}
              />
            );
          })}
        </ul>
      );
    }
  }

  openSelectedCommit = () => this.props.openCommit({sha: this.props.selectedCommitSha, preserveFocus: false})

  advanceFocusFrom(focus) {
    if (focus === this.constructor.focus.RECENT_COMMIT) {
      return Promise.resolve(this.constructor.focus.RECENT_COMMIT);
    }

    return Promise.resolve(null);
  }

  retreatFocusFrom(focus) {
    if (focus === this.constructor.focus.RECENT_COMMIT) {
      return Promise.resolve(CommitView.lastFocus);
    }

    return Promise.resolve(null);
  }
}
