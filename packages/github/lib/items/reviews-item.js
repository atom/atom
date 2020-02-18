import React from 'react';
import PropTypes from 'prop-types';
import {Emitter} from 'event-kit';

import {GithubLoginModelPropType, WorkdirContextPoolPropType} from '../prop-types';
import Repository from '../models/repository';
import {getEndpoint} from '../models/endpoint';
import ReviewsContainer from '../containers/reviews-container';

export default class ReviewsItem extends React.Component {
  static propTypes = {
    // Parsed from URI
    host: PropTypes.string.isRequired,
    owner: PropTypes.string.isRequired,
    repo: PropTypes.string.isRequired,
    number: PropTypes.number.isRequired,
    workdir: PropTypes.string.isRequired,

    // Package models
    workdirContextPool: WorkdirContextPoolPropType.isRequired,
    loginModel: GithubLoginModelPropType.isRequired,

    // Atom environment
    workspace: PropTypes.object.isRequired,
    config: PropTypes.object.isRequired,
    commands: PropTypes.object.isRequired,
    tooltips: PropTypes.object.isRequired,
    confirm: PropTypes.func.isRequired,

    // Action methods
    reportRelayError: PropTypes.func.isRequired,
  }

  static uriPattern = 'atom-github://reviews/{host}/{owner}/{repo}/{number}?workdir={workdir}'

  static buildURI({host, owner, repo, number, workdir}) {
    return 'atom-github://reviews/' +
      encodeURIComponent(host) + '/' +
      encodeURIComponent(owner) + '/' +
      encodeURIComponent(repo) + '/' +
      encodeURIComponent(number) +
      '?workdir=' + encodeURIComponent(workdir || '');
  }

  constructor(props) {
    super(props);

    this.emitter = new Emitter();
    this.isDestroyed = false;

    this.state = {
      initThreadID: null,
    };
  }

  render() {
    const endpoint = getEndpoint(this.props.host);

    const repository = this.props.workdir.length > 0
      ? this.props.workdirContextPool.add(this.props.workdir).getRepository()
      : Repository.absent();

    return (
      <ReviewsContainer
        endpoint={endpoint}
        repository={repository}
        initThreadID={this.state.initThreadID}
        {...this.props}
      />
    );
  }

  getTitle() {
    return `Reviews #${this.props.number}`;
  }

  getDefaultLocation() {
    return 'right';
  }

  getPreferredWidth() {
    return 400;
  }

  destroy() {
    /* istanbul ignore else */
    if (!this.isDestroyed) {
      this.emitter.emit('did-destroy');
      this.isDestroyed = true;
    }
  }

  onDidDestroy(callback) {
    return this.emitter.on('did-destroy', callback);
  }

  serialize() {
    return {
      deserializer: 'ReviewsStub',
      uri: ReviewsItem.buildURI({
        host: this.props.host,
        owner: this.props.owner,
        repo: this.props.repo,
        number: this.props.number,
        workdir: this.props.workdir,
      }),
    };
  }

  async jumpToThread(id) {
    if (this.state.initThreadID === id) {
      await new Promise(resolve => this.setState({initThreadID: null}, resolve));
    }

    return new Promise(resolve => this.setState({initThreadID: id}, resolve));
  }
}
