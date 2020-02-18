export default class ModelObserver {
  constructor({fetchData, didUpdate}) {
    this.fetchData = fetchData || (() => {});
    this.didUpdate = didUpdate || (() => {});
    this.activeModel = null;
    this.activeModelData = null;
    this.activeModelUpdateSubscription = null;
    this.inProgress = false;
    this.pending = false;
  }

  setActiveModel(model) {
    if (model !== this.activeModel) {
      if (this.activeModelUpdateSubscription) {
        this.activeModelUpdateSubscription.dispose();
        this.activeModelUpdateSubscription = null;
      }
      this.activeModel = model;
      this.activeModelData = null;
      this.inProgress = false;
      this.pending = false;
      this.didUpdate(model);
      if (model) {
        this.activeModelUpdateSubscription = model.onDidUpdate(() => this.refreshModelData(model));
        return this.refreshModelData(model);
      }
    }
    return null;
  }

  refreshModelData(model = this.activeModel) {
    if (this.inProgress) {
      this.pending = true;
      return null;
    }
    this.lastModelDataRefreshPromise = this._refreshModelData(model);
    return this.lastModelDataRefreshPromise;
  }

  async _refreshModelData(model) {
    try {
      this.inProgress = true;
      const fetchDataPromise = this.fetchData(model);
      this.lastFetchDataPromise = fetchDataPromise;
      const modelData = await fetchDataPromise;
      // Since we re-fetch immediately when the model changes,
      // we need to ensure a fetch for an old active model
      // does not trample the newer fetch for the newer active model.
      if (fetchDataPromise === this.lastFetchDataPromise) {
        this.activeModel = model;
        this.activeModelData = modelData;
        this.didUpdate(model);
      }
    } finally {
      this.inProgress = false;
      if (this.pending) {
        this.pending = false;
        this.refreshModelData();
      }
    }
  }

  getActiveModel() {
    return this.activeModel;
  }

  getActiveModelData() {
    return this.activeModelData;
  }

  getLastModelDataRefreshPromise() {
    return this.lastModelDataRefreshPromise;
  }

  hasPendingUpdate() {
    return this.pending;
  }

  destroy() {
    if (this.activeModelUpdateSubscription) { this.activeModelUpdateSubscription.dispose(); }
  }
}
