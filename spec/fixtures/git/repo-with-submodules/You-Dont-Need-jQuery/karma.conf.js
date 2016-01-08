// Karma configuration
// Generated on Sun Nov 22 2015 22:10:47 GMT+0800 (CST)
require('babel-core/register');

module.exports = function(config) {
  config.set({
    // base path that will be used to resolve all patterns (eg. files, exclude)
    basePath: '.',

    // frameworks to use
    // available frameworks: https://npmjs.org/browse/keyword/karma-adapter
    frameworks: ['mocha'],

    // list of files / patterns to load in the browser
    files: [
      './test/**/*.spec.js'
    ],

    // list of files to exclude
    exclude: [
    ],

    // preprocess matching files before serving them to the browser
    // available preprocessors: https://npmjs.org/browse/keyword/karma-preprocessor
    preprocessors: {
      'test/**/*.spec.js': ['webpack', 'sourcemap']
    },

    // test results reporter to use
    // possible values: 'dots', 'progress'
    // available reporters: https://npmjs.org/browse/keyword/karma-reporter
    reporters: ['progress'],

    coverageReporter: {
      reporters: [
        {type: 'text'},
        {type: 'html', dir: 'coverage'},
      ]
    },

    webpackMiddleware: {
      stats: 'minimal'
    },

    webpack: {
      cache: true,
      devtool: 'inline-source-map',
      module: {
        loaders: [{
          test: /\.jsx?$/,
          loader: 'babel-loader',
          exclude: /node_modules/
        }],
        postLoaders: [{
          test: /\.js/,
          exclude: /(test|node_modules)/,
          loader: 'istanbul-instrumenter'
        }],
      },
      resolve: {
        extensions: ['', '.js', '.jsx']
      }
    },

    // web server port
    port: 9876,

    // enable / disable colors in the output (reporters and logs)
    colors: true,

    // level of logging
    // possible values: config.LOG_DISABLE || config.LOG_ERROR || config.LOG_WARN || config.LOG_INFO || config.LOG_DEBUG
    logLevel: config.LOG_INFO,

    // enable / disable watching file and executing tests whenever any file changes
    autoWatch: true,

    // start these browsers
    // available browser launchers: https://npmjs.org/browse/keyword/karma-launcher
    browsers: ['Firefox'],

    // Continuous Integration mode
    // if true, Karma captures browsers, runs the tests and exits
    // singleRun: false,

    // Concurrency level
    // how many browser should be started simultanous
    // concurrency: Infinity,

    // plugins: ['karma-phantomjs-launcher', 'karma-sourcemap-loader', 'karma-webpack']
  })
}
