/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
'use strict';
Object.defineProperty(exports, "__esModule", { value: true });
const es = require("event-stream");
const util = require("gulp-util");
const appInsights = require("applicationinsights");
class Entry {
    constructor(name, totalCount, totalSize) {
        this.name = name;
        this.totalCount = totalCount;
        this.totalSize = totalSize;
    }
    toString(pretty) {
        if (!pretty) {
            if (this.totalCount === 1) {
                return `${this.name}: ${this.totalSize} bytes`;
            }
            else {
                return `${this.name}: ${this.totalCount} files with ${this.totalSize} bytes`;
            }
        }
        else {
            if (this.totalCount === 1) {
                return `Stats for '${util.colors.grey(this.name)}': ${Math.round(this.totalSize / 1204)}KB`;
            }
            else {
                const count = this.totalCount < 100
                    ? util.colors.green(this.totalCount.toString())
                    : util.colors.red(this.totalCount.toString());
                return `Stats for '${util.colors.grey(this.name)}': ${count} files, ${Math.round(this.totalSize / 1204)}KB`;
            }
        }
    }
}
const _entries = new Map();
function createStatsStream(group, log) {
    const entry = new Entry(group, 0, 0);
    _entries.set(entry.name, entry);
    return es.through(function (data) {
        const file = data;
        if (typeof file.path === 'string') {
            entry.totalCount += 1;
            if (Buffer.isBuffer(file.contents)) {
                entry.totalSize += file.contents.length;
            }
            else if (file.stat && typeof file.stat.size === 'number') {
                entry.totalSize += file.stat.size;
            }
            else {
                // funky file...
            }
        }
        this.emit('data', data);
    }, function () {
        if (log) {
            if (entry.totalCount === 1) {
                util.log(`Stats for '${util.colors.grey(entry.name)}': ${Math.round(entry.totalSize / 1204)}KB`);
            }
            else {
                const count = entry.totalCount < 100
                    ? util.colors.green(entry.totalCount.toString())
                    : util.colors.red(entry.totalCount.toString());
                util.log(`Stats for '${util.colors.grey(entry.name)}': ${count} files, ${Math.round(entry.totalSize / 1204)}KB`);
            }
        }
        this.emit('end');
    });
}
exports.createStatsStream = createStatsStream;
function submitAllStats(productJson, commit) {
    const sorted = [];
    // move entries for single files to the front
    _entries.forEach(value => {
        if (value.totalCount === 1) {
            sorted.unshift(value);
        }
        else {
            sorted.push(value);
        }
    });
    // print to console
    for (const entry of sorted) {
        console.log(entry.toString(true));
    }
    // send data as telementry event when the
    // product is configured to send telemetry
    if (!productJson || !productJson.aiConfig || typeof productJson.aiConfig.asimovKey !== 'string') {
        return Promise.resolve(false);
    }
    return new Promise(resolve => {
        try {
            const sizes = {};
            const counts = {};
            for (const entry of sorted) {
                sizes[entry.name] = entry.totalSize;
                counts[entry.name] = entry.totalCount;
            }
            appInsights.setup(productJson.aiConfig.asimovKey)
                .setAutoCollectConsole(false)
                .setAutoCollectExceptions(false)
                .setAutoCollectPerformance(false)
                .setAutoCollectRequests(false)
                .setAutoCollectDependencies(false)
                .setAutoDependencyCorrelation(false)
                .start();
            appInsights.defaultClient.config.endpointUrl = 'https://vortex.data.microsoft.com/collect/v1';
            /* __GDPR__
                "monacoworkbench/packagemetrics" : {
                    "commit" : {"classification": "SystemMetaData", "purpose": "PerformanceAndHealth" },
                    "size" : {"classification": "SystemMetaData", "purpose": "PerformanceAndHealth" },
                    "count" : {"classification": "SystemMetaData", "purpose": "PerformanceAndHealth" }
                }
            */
            appInsights.defaultClient.trackEvent({
                name: 'monacoworkbench/packagemetrics',
                properties: { commit, size: JSON.stringify(sizes), count: JSON.stringify(counts) }
            });
            appInsights.defaultClient.flush({
                callback: () => {
                    appInsights.dispose();
                    resolve(true);
                }
            });
        }
        catch (err) {
            console.error('ERROR sending build stats as telemetry event!');
            console.error(err);
            resolve(false);
        }
    });
}
exports.submitAllStats = submitAllStats;
