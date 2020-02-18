// API endpoint for a GitHub instance, either dotcom or an Enterprise installation.
class Endpoint {
  constructor(host, apiHost, apiRouteParts) {
    this.host = host;
    this.apiHost = apiHost;
    this.apiRoute = apiRouteParts.map(encodeURIComponent).join('/');
  }

  getRestURI(...parts) {
    const sep = parts.length > 0 ? '/' : '';
    return this.getRestRoot() + sep + parts.map(encodeURIComponent).join('/');
  }

  getGraphQLRoot() {
    return this.getRestURI('graphql');
  }

  getRestRoot() {
    const sep = this.apiRoute !== '' ? '/' : '';
    return `https://${this.apiHost}${sep}${this.apiRoute}`;
  }

  getHost() {
    return this.host;
  }

  getLoginAccount() {
    return `https://${this.apiHost}`;
  }
}

// API endpoint for GitHub.com
const dotcomEndpoint = new Endpoint('github.com', 'api.github.com', []);

export function getEndpoint(host) {
  if (host === 'github.com') {
    return dotcomEndpoint;
  } else {
    return new Endpoint(host, host, ['api', 'v3']);
  }
}
