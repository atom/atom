import React from 'react';
import PropTypes from 'prop-types';
import {parse as parseDiff} from 'what-the-diff';

import {toNativePathSep} from '../helpers';
import {EndpointPropType} from '../prop-types';
import {filter as filterDiff} from '../models/patch/filter';
import {buildMultiFilePatch} from '../models/patch';

export default class PullRequestPatchContainer extends React.Component {
  static propTypes = {
    // Pull request properties
    owner: PropTypes.string.isRequired,
    repo: PropTypes.string.isRequired,
    number: PropTypes.number.isRequired,

    // Connection properties
    endpoint: EndpointPropType.isRequired,
    token: PropTypes.string.isRequired,

    // Fetching and parsing
    refetch: PropTypes.bool,
    largeDiffThreshold: PropTypes.number,

    // Render prop. Called with (error or null, multiFilePatch or null)
    children: PropTypes.func.isRequired,
  }

  state = {
    multiFilePatch: null,
    error: null,
    last: {url: null, patch: null, etag: null},
  }

  componentDidMount() {
    this.mounted = true;
    this.fetchDiff(this.state.last);
  }

  componentDidUpdate(prevProps) {
    const explicitRefetch = this.props.refetch && !prevProps.refetch;
    const requestedURLChange = this.state.last.url !== this.getDiffURL();

    if (explicitRefetch || requestedURLChange) {
      const {last} = this.state;
      this.setState({
        multiFilePatch: null,
        error: null,
        last: {url: this.getDiffURL(), patch: null, etag: null},
      });
      this.fetchDiff(last);
    }
  }

  componentWillUnmount() {
    this.mounted = false;
  }

  render() {
    return this.props.children(this.state.error, this.state.multiFilePatch);
  }

  // Generate a v3 GitHub API REST URL for the pull request resource.
  // Example: https://api.github.com/repos/atom/github/pulls/1829
  getDiffURL() {
    return this.props.endpoint.getRestURI('repos', this.props.owner, this.props.repo, 'pulls', this.props.number);
  }

  buildPatch(rawDiff) {
    const {filtered, removed} = filterDiff(rawDiff);
    const diffs = parseDiff(filtered).map(diff => {
    // diff coming from API will have the defaul git diff prefixes a/ and b/ and use *nix-style / path separators.
    // e.g. a/dir/file1.js and b/dir/file2.js
    // see https://git-scm.com/docs/git-diff#_generating_patches_with_p
      return {
        ...diff,
        newPath: diff.newPath ? toNativePathSep(diff.newPath.replace(/^[a|b]\//, '')) : diff.newPath,
        oldPath: diff.oldPath ? toNativePathSep(diff.oldPath.replace(/^[a|b]\//, '')) : diff.oldPath,
      };
    });
    const options = {
      preserveOriginal: true,
      removed,
    };
    if (this.props.largeDiffThreshold) {
      options.largeDiffThreshold = this.props.largeDiffThreshold;
    }
    const mfp = buildMultiFilePatch(diffs, options);
    return mfp;
  }

  async fetchDiff(last) {
    const url = this.getDiffURL();
    let response;

    try {
      const headers = {
        Accept: 'application/vnd.github.v3.diff',
        Authorization: `bearer ${this.props.token}`,
      };

      if (url === last.url && last.etag !== null) {
        headers['If-None-Match'] = last.etag;
      }

      response = await fetch(url, {headers});
    } catch (err) {
      return this.reportDiffError(`Network error encountered fetching the patch: ${err.message}.`, err);
    }

    if (response.status === 304) {
      // Not modified.
      if (!this.mounted) {
        return null;
      }

      return new Promise(resolve => this.setState({
        multiFilePatch: last.patch,
        error: null,
        last,
      }));
    }

    if (!response.ok) {
      return this.reportDiffError(`Unable to fetch the diff for this pull request: ${response.statusText}.`);
    }

    try {
      const etag = response.headers.get('ETag');
      const rawDiff = await response.text();
      if (!this.mounted) {
        return null;
      }

      const multiFilePatch = this.buildPatch(rawDiff);
      return new Promise(resolve => this.setState({
        multiFilePatch,
        error: null,
        last: {url, patch: multiFilePatch, etag},
      }, resolve));
    } catch (err) {
      return this.reportDiffError('Unable to parse the diff for this pull request.', err);
    }
  }

  reportDiffError(message, error) {
    if (!this.mounted) {
      return null;
    }

    return new Promise(resolve => {
      if (error) {
        // eslint-disable-next-line no-console
        console.error(error);
      }

      if (!this.mounted) {
        resolve();
        return;
      }

      this.setState({error: message}, resolve);
    });
  }
}
