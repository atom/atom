/** @babel */

import Chart from 'chart.js'
import glob from 'glob'
import fs from 'fs-plus'
import path from 'path'

export default async function (benchmarkPaths) {
  document.body.style.backgroundColor = '#ffffff'
  document.body.style.overflow = 'auto'

  let paths = []
  for (const benchmarkPath of benchmarkPaths) {
    if (fs.isDirectorySync(benchmarkPath)) {
      paths = paths.concat(glob.sync(path.join(benchmarkPath, '**', '*.bench.js')))
    } else {
      paths.push(benchmarkPath)
    }
  }

  while (paths.length > 0) {
    const benchmark = require(paths.shift())()
    let results
    if (benchmark instanceof Promise) {
      results = await benchmark
    } else {
      results = benchmark
    }

    const dataByBenchmarkName = {}
    for (const {name, duration, x} of results) {
      dataByBenchmarkName[name] = dataByBenchmarkName[name] || {points: []}
      dataByBenchmarkName[name].points.push({x, y: duration})
    }

    const benchmarkContainer = document.createElement('div')
    document.body.appendChild(benchmarkContainer)
    for (const key in dataByBenchmarkName) {
      const data = dataByBenchmarkName[key]
      if (data.points.length > 1) {
        const canvas = document.createElement('canvas')
        benchmarkContainer.appendChild(canvas)
        const chart = new Chart(canvas, {
          type: 'line',
          data: {
            labels: data.points.map((p) => p.x),
            datasets: [{label: key, fill: false, data: data.points}]
          }
        })
      } else {
        const title = document.createElement('h2')
        title.textContent = key
        benchmarkContainer.appendChild(title)
        const duration = document.createElement('p')
        duration.textContent = `${data.points[0].y}ms`
        benchmarkContainer.appendChild(duration)
      }

      global.atom.reset()
    }
  }
}
