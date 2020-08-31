const Chart = require('chart.js');
const glob = require('glob');
const fs = require('fs-plus');
const path = require('path');

module.exports = async ({ test, benchmarkPaths }) => {
  document.body.style.backgroundColor = '#ffffff';
  document.body.style.overflow = 'auto';

  let paths = [];
  for (const benchmarkPath of benchmarkPaths) {
    if (fs.isDirectorySync(benchmarkPath)) {
      paths = paths.concat(
        glob.sync(path.join(benchmarkPath, '**', '*.bench.js'))
      );
    } else {
      paths.push(benchmarkPath);
    }
  }

  while (paths.length > 0) {
    const benchmark = require(paths.shift())({ test });
    let results;
    if (benchmark instanceof Promise) {
      results = await benchmark;
    } else {
      results = benchmark;
    }

    const dataByBenchmarkName = {};
    for (const { name, duration, x } of results) {
      dataByBenchmarkName[name] = dataByBenchmarkName[name] || { points: [] };
      dataByBenchmarkName[name].points.push({ x, y: duration });
    }

    const benchmarkContainer = document.createElement('div');
    document.body.appendChild(benchmarkContainer);
    for (const key in dataByBenchmarkName) {
      const data = dataByBenchmarkName[key];
      if (data.points.length > 1) {
        const canvas = document.createElement('canvas');
        benchmarkContainer.appendChild(canvas);
        // eslint-disable-next-line no-new
        new Chart(canvas, {
          type: 'line',
          data: {
            datasets: [{ label: key, fill: false, data: data.points }]
          },
          options: {
            showLines: false,
            scales: { xAxes: [{ type: 'linear', position: 'bottom' }] }
          }
        });

        const textualOutput =
          `${key}:\n\n` + data.points.map(p => `${p.x}\t${p.y}`).join('\n');
        console.log(textualOutput);
      } else {
        const title = document.createElement('h2');
        title.textContent = key;
        benchmarkContainer.appendChild(title);
        const duration = document.createElement('p');
        duration.textContent = `${data.points[0].y}ms`;
        benchmarkContainer.appendChild(duration);

        const textualOutput = `${key}: ${data.points[0].y}`;
        console.log(textualOutput);
      }

      await global.atom.reset();
    }
  }

  return 0;
};
