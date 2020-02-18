import {URL} from 'url';
import moment from 'moment';

import {
  buildStatusFromStatusContext,
  buildStatusFromCheckResult,
} from './build-status';
import {GHOST_USER} from '../helpers';

export default class Issueish {
  constructor(data) {
    const author = data.author || GHOST_USER;

    this.number = data.number;
    this.title = data.title;
    this.url = new URL(data.url);
    this.authorLogin = author.login;
    this.authorAvatarURL = new URL(author.avatarUrl);
    this.createdAt = moment(data.createdAt, moment.ISO_8601);
    this.headRefName = data.headRefName;
    this.headRepositoryID = data.repository.id;
    this.latestCommit = null;
    this.statusContexts = [];
    this.checkRuns = [];

    if (data.commits.nodes.length > 0) {
      this.latestCommit = data.commits.nodes[0].commit;
    }

    if (this.latestCommit && this.latestCommit.status) {
      this.statusContexts = this.latestCommit.status.contexts;
    }
  }

  getNumber() {
    return this.number;
  }

  getTitle() {
    return this.title;
  }

  getGitHubURL() {
    return this.url.toString();
  }

  getAuthorLogin() {
    return this.authorLogin;
  }

  getAuthorAvatarURL(size = 32) {
    const u = new URL(this.authorAvatarURL.toString());
    u.searchParams.set('s', size);
    return u.toString();
  }

  getCreatedAt() {
    return this.createdAt;
  }

  getHeadRefName() {
    return this.headRefName;
  }

  getHeadRepositoryID() {
    return this.headRepositoryID;
  }

  getLatestCommit() {
    return this.latestCommit;
  }

  setCheckRuns(runsBySuite) {
    this.checkRuns = [];
    for (const [, runs] of runsBySuite) {
      for (const checkRun of runs) {
        this.checkRuns.push(checkRun);
      }
    }
  }

  getStatusCounts() {
    const buildStatuses = [];
    for (const context of this.statusContexts) {
      buildStatuses.push(buildStatusFromStatusContext(context));
    }
    for (const checkRun of this.checkRuns) {
      buildStatuses.push(buildStatusFromCheckResult(checkRun));
    }

    const counts = {
      pending: 0,
      failure: 0,
      success: 0,
      neutral: 0,
    };

    for (const {classSuffix} of buildStatuses) {
      counts[classSuffix]++;
    }

    return counts;
  }
}
