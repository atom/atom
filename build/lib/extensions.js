"use strict";
/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
Object.defineProperty(exports, "__esModule", { value: true });
const es = require("event-stream");
const fs = require("fs");
const glob = require("glob");
const gulp = require("gulp");
const path = require("path");
const File = require("vinyl");
const vsce = require("vsce");
const stats_1 = require("./stats");
const util2 = require("./util");
const remote = require("gulp-remote-src");
const vzip = require('gulp-vinyl-zip');
const filter = require("gulp-filter");
const rename = require("gulp-rename");
const util = require('gulp-util');
const buffer = require('gulp-buffer');
const json = require("gulp-json-editor");
const webpack = require('webpack');
const webpackGulp = require('webpack-stream');
const root = path.resolve(path.join(__dirname, '..', '..'));
function fromLocal(extensionPath, sourceMappingURLBase) {
    const webpackFilename = path.join(extensionPath, 'extension.webpack.config.js');
    if (fs.existsSync(webpackFilename)) {
        return fromLocalWebpack(extensionPath, sourceMappingURLBase);
    }
    else {
        return fromLocalNormal(extensionPath);
    }
}
function fromLocalWebpack(extensionPath, sourceMappingURLBase) {
    const result = es.through();
    const packagedDependencies = [];
    const packageJsonConfig = require(path.join(extensionPath, 'package.json'));
    if (packageJsonConfig.dependencies) {
        const webpackRootConfig = require(path.join(extensionPath, 'extension.webpack.config.js'));
        for (const key in webpackRootConfig.externals) {
            if (key in packageJsonConfig.dependencies) {
                packagedDependencies.push(key);
            }
        }
    }
    vsce.listFiles({ cwd: extensionPath, packageManager: vsce.PackageManager.Yarn, packagedDependencies }).then(fileNames => {
        const files = fileNames
            .map(fileName => path.join(extensionPath, fileName))
            .map(filePath => new File({
            path: filePath,
            stat: fs.statSync(filePath),
            base: extensionPath,
            contents: fs.createReadStream(filePath)
        }));
        const filesStream = es.readArray(files);
        // check for a webpack configuration files, then invoke webpack
        // and merge its output with the files stream. also rewrite the package.json
        // file to a new entry point
        const webpackConfigLocations = glob.sync(path.join(extensionPath, '/**/extension.webpack.config.js'), { ignore: ['**/node_modules'] });
        const packageJsonFilter = filter(f => {
            if (path.basename(f.path) === 'package.json') {
                // only modify package.json's next to the webpack file.
                // to be safe, use existsSync instead of path comparison.
                return fs.existsSync(path.join(path.dirname(f.path), 'extension.webpack.config.js'));
            }
            return false;
        }, { restore: true });
        const patchFilesStream = filesStream
            .pipe(packageJsonFilter)
            .pipe(buffer())
            .pipe(json((data) => {
            if (data.main) {
                // hardcoded entry point directory!
                data.main = data.main.replace('/out/', /dist/);
            }
            return data;
        }))
            .pipe(packageJsonFilter.restore);
        const webpackStreams = webpackConfigLocations.map(webpackConfigPath => () => {
            const webpackDone = (err, stats) => {
                util.log(`Bundled extension: ${util.colors.yellow(path.join(path.basename(extensionPath), path.relative(extensionPath, webpackConfigPath)))}...`);
                if (err) {
                    result.emit('error', err);
                }
                const { compilation } = stats;
                if (compilation.errors.length > 0) {
                    result.emit('error', compilation.errors.join('\n'));
                }
                if (compilation.warnings.length > 0) {
                    result.emit('error', compilation.warnings.join('\n'));
                }
            };
            const webpackConfig = Object.assign({}, require(webpackConfigPath), { mode: 'production' });
            const relativeOutputPath = path.relative(extensionPath, webpackConfig.output.path);
            return webpackGulp(webpackConfig, webpack, webpackDone)
                .pipe(es.through(function (data) {
                data.stat = data.stat || {};
                data.base = extensionPath;
                this.emit('data', data);
            }))
                .pipe(es.through(function (data) {
                // source map handling:
                // * rewrite sourceMappingURL
                // * save to disk so that upload-task picks this up
                if (sourceMappingURLBase) {
                    const contents = data.contents.toString('utf8');
                    data.contents = Buffer.from(contents.replace(/\n\/\/# sourceMappingURL=(.*)$/gm, function (_m, g1) {
                        return `\n//# sourceMappingURL=${sourceMappingURLBase}/extensions/${path.basename(extensionPath)}/${relativeOutputPath}/${g1}`;
                    }), 'utf8');
                    if (/\.js\.map$/.test(data.path)) {
                        if (!fs.existsSync(path.dirname(data.path))) {
                            fs.mkdirSync(path.dirname(data.path));
                        }
                        fs.writeFileSync(data.path, data.contents);
                    }
                }
                this.emit('data', data);
            }));
        });
        es.merge(sequence(webpackStreams), patchFilesStream)
            // .pipe(es.through(function (data) {
            // 	// debug
            // 	console.log('out', data.path, data.contents.length);
            // 	this.emit('data', data);
            // }))
            .pipe(result);
    }).catch(err => {
        console.error(extensionPath);
        console.error(packagedDependencies);
        result.emit('error', err);
    });
    return result.pipe(stats_1.createStatsStream(path.basename(extensionPath)));
}
function fromLocalNormal(extensionPath) {
    const result = es.through();
    vsce.listFiles({ cwd: extensionPath, packageManager: vsce.PackageManager.Yarn })
        .then(fileNames => {
        const files = fileNames
            .map(fileName => path.join(extensionPath, fileName))
            .map(filePath => new File({
            path: filePath,
            stat: fs.statSync(filePath),
            base: extensionPath,
            contents: fs.createReadStream(filePath)
        }));
        es.readArray(files).pipe(result);
    })
        .catch(err => result.emit('error', err));
    return result.pipe(stats_1.createStatsStream(path.basename(extensionPath)));
}
const baseHeaders = {
    'X-Market-Client-Id': 'VSCode Build',
    'User-Agent': 'VSCode Build',
    'X-Market-User-Id': '291C1CD0-051A-4123-9B4B-30D60EF52EE2',
};
function fromMarketplace(extensionName, version, metadata) {
    const [publisher, name] = extensionName.split('.');
    const url = `https://marketplace.visualstudio.com/_apis/public/gallery/publishers/${publisher}/vsextensions/${name}/${version}/vspackage`;
    util.log('Downloading extension:', util.colors.yellow(`${extensionName}@${version}`), '...');
    const options = {
        base: url,
        requestOptions: {
            gzip: true,
            headers: baseHeaders
        }
    };
    const packageJsonFilter = filter('package.json', { restore: true });
    return remote('', options)
        .pipe(vzip.src())
        .pipe(filter('extension/**'))
        .pipe(rename(p => p.dirname = p.dirname.replace(/^extension\/?/, '')))
        .pipe(packageJsonFilter)
        .pipe(buffer())
        .pipe(json({ __metadata: metadata }))
        .pipe(packageJsonFilter.restore);
}
exports.fromMarketplace = fromMarketplace;
const excludedExtensions = [
    'vscode-api-tests',
    'vscode-colorize-tests',
    'ms-vscode.node-debug',
    'ms-vscode.node-debug2',
];
const builtInExtensions = require('../builtInExtensions.json');
/**
 * We're doing way too much stuff at once, with webpack et al. So much stuff
 * that while downloading extensions from the marketplace, node js doesn't get enough
 * stack frames to complete the download in under 2 minutes, at which point the
 * marketplace server cuts off the http request. So, we sequentialize the extensino tasks.
 */
function sequence(streamProviders) {
    const result = es.through();
    function pop() {
        if (streamProviders.length === 0) {
            result.emit('end');
        }
        else {
            const fn = streamProviders.shift();
            fn()
                .on('end', function () { setTimeout(pop, 0); })
                .pipe(result, { end: false });
        }
    }
    pop();
    return result;
}
function packageExtensionsStream(optsIn) {
    const opts = optsIn || {};
    const localExtensionDescriptions = glob.sync('extensions/*/package.json')
        .map(manifestPath => {
        const extensionPath = path.dirname(path.join(root, manifestPath));
        const extensionName = path.basename(extensionPath);
        return { name: extensionName, path: extensionPath };
    })
        .filter(({ name }) => excludedExtensions.indexOf(name) === -1)
        .filter(({ name }) => opts.desiredExtensions ? opts.desiredExtensions.indexOf(name) >= 0 : true)
        .filter(({ name }) => builtInExtensions.every(b => b.name !== name));
    const localExtensions = () => sequence([...localExtensionDescriptions.map(extension => () => {
            return fromLocal(extension.path, opts.sourceMappingURLBase)
                .pipe(rename(p => p.dirname = `extensions/${extension.name}/${p.dirname}`));
        })]);
    const localExtensionDependencies = () => gulp.src('extensions/node_modules/**', { base: '.' });
    const marketplaceExtensions = () => es.merge(...builtInExtensions
        .filter(({ name }) => opts.desiredExtensions ? opts.desiredExtensions.indexOf(name) >= 0 : true)
        .map(extension => {
        return fromMarketplace(extension.name, extension.version, extension.metadata)
            .pipe(rename(p => p.dirname = `extensions/${extension.name}/${p.dirname}`));
    }));
    return sequence([localExtensions, localExtensionDependencies, marketplaceExtensions])
        .pipe(util2.setExecutableBit(['**/*.sh']))
        .pipe(filter(['**', '!**/*.js.map']));
}
exports.packageExtensionsStream = packageExtensionsStream;
