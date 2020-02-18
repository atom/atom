import React from 'react';
import PropTypes from 'prop-types';
import {AuthorPropType} from '../prop-types';
import GithubTabHeaderView from '../views/github-tab-header-view';

export default class GithubTabHeaderController extends React.Component {
  static propTypes = {
    user: AuthorPropType.isRequired,

    // Workspace
    currentWorkDir: PropTypes.string,
    contextLocked: PropTypes.bool.isRequired,
    changeWorkingDirectory: PropTypes.func.isRequired,
    setContextLock: PropTypes.func.isRequired,
    getCurrentWorkDirs: PropTypes.func.isRequired,

    // Event Handlers
    onDidChangeWorkDirs: PropTypes.func.isRequired,
  }

  constructor(props) {
    super(props);

    this.state = {
      currentWorkDirs: [],
      changingLock: null,
      changingWorkDir: null,
    };
  }

  static getDerivedStateFromProps(props) {
    return {
      currentWorkDirs: props.getCurrentWorkDirs(),
    };
  }

  componentDidMount() {
    this.disposable = this.props.onDidChangeWorkDirs(this.resetWorkDirs);
  }

  componentDidUpdate(prevProps) {
    if (prevProps.onDidChangeWorkDirs !== this.props.onDidChangeWorkDirs) {
      if (this.disposable) {
        this.disposable.dispose();
      }
      this.disposable = this.props.onDidChangeWorkDirs(this.resetWorkDirs);
    }
  }

  render() {
    return (
      <GithubTabHeaderView
        user={this.props.user}

        // Workspace
        workdir={this.getWorkDir()}
        workdirs={this.state.currentWorkDirs}
        contextLocked={this.getContextLocked()}
        changingWorkDir={this.state.changingWorkDir !== null}
        changingLock={this.state.changingLock !== null}

        handleWorkDirChange={this.handleWorkDirChange}
        handleLockToggle={this.handleLockToggle}
      />
    );
  }

  resetWorkDirs = () => {
    this.setState(() => ({
      currentWorkDirs: [],
    }));
  }

  handleLockToggle = async () => {
    if (this.state.changingLock !== null) {
      return;
    }

    const nextLock = !this.props.contextLocked;
    try {
      this.setState({changingLock: nextLock});
      await this.props.setContextLock(this.state.changingWorkDir || this.props.currentWorkDir, nextLock);
    } finally {
      await new Promise(resolve => this.setState({changingLock: null}, resolve));
    }
  }

  handleWorkDirChange = async e => {
    if (this.state.changingWorkDir !== null) {
      return;
    }

    const nextWorkDir = e.target.value;
    try {
      this.setState({changingWorkDir: nextWorkDir});
      await this.props.changeWorkingDirectory(nextWorkDir);
    } finally {
      await new Promise(resolve => this.setState({changingWorkDir: null}, resolve));
    }
  }

  getWorkDir() {
    return this.state.changingWorkDir !== null ? this.state.changingWorkDir : this.props.currentWorkDir;
  }

  getContextLocked() {
    return this.state.changingLock !== null ? this.state.changingLock : this.props.contextLocked;
  }

  componentWillUnmount() {
    this.disposable.dispose();
  }
}
