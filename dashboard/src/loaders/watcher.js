const EventEmitter = require('events');
const fs = require('fs');
const path = require('path');
const { specsPath } = require('../../../scripts/lib/project-runtime');

let chokidar;
try {
  chokidar = require('chokidar');
} catch (err) {
  chokidar = null;
}

function watch(projectRoot) {
  const emitter = new EventEmitter();
  const debounceTimers = {};

  function notifyChange(file) {
    const key = file;
    if (debounceTimers[key]) {
      clearTimeout(debounceTimers[key]);
    }
    debounceTimers[key] = setTimeout(() => {
      emitter.emit('change', { file, data: null });
      delete debounceTimers[key];
    }, 300);
  }

  if (chokidar) {
    const filesToWatch = [
      specsPath(projectRoot, 'state.yaml'),
      specsPath(projectRoot, 'execution-status.yaml'),
      specsPath(projectRoot, 'metrics', 'cycle-times.yaml'),
      specsPath(projectRoot, 'epics')
    ];

    const watcher = chokidar.watch(filesToWatch, {
      persistent: true,
      awaitWriteFinish: {
        stabilityThreshold: 100,
        pollInterval: 100
      }
    });

    watcher.on('change', (file) => {
      notifyChange(file);
    });

    watcher.on('add', (file) => {
      notifyChange(file);
    });

    emitter.close = () => watcher.close();
  } else {
    const fileStats = {};
    const filesToWatch = [
      specsPath(projectRoot, 'state.yaml'),
      specsPath(projectRoot, 'execution-status.yaml'),
      specsPath(projectRoot, 'metrics', 'cycle-times.yaml')
    ];

    const pollInterval = setInterval(() => {
      filesToWatch.forEach((file) => {
        try {
          const stat = fs.statSync(file);
          const mtime = stat.mtime.getTime();

          if (!fileStats[file]) {
            fileStats[file] = mtime;
          } else if (fileStats[file] !== mtime) {
            fileStats[file] = mtime;
            notifyChange(file);
          }
        } catch (err) {
          // File doesn't exist yet or was deleted
          if (fileStats[file]) {
            delete fileStats[file];
            notifyChange(file);
          }
        }
      });

      // Check the configured epics directory.
      const epicsDir = specsPath(projectRoot, 'epics');
      try {
        const entries = fs.readdirSync(epicsDir);
        entries.forEach((entry) => {
          const fullPath = path.join(epicsDir, entry);
          const stat = fs.statSync(fullPath);
          const mtime = stat.mtime.getTime();

          if (!fileStats[fullPath]) {
            fileStats[fullPath] = mtime;
          } else if (fileStats[fullPath] !== mtime) {
            fileStats[fullPath] = mtime;
            notifyChange(fullPath);
          }
        });
      } catch (err) {
        // epics directory doesn't exist yet
      }
    }, 200);

    emitter.close = () => clearInterval(pollInterval);
  }

  return emitter;
}

module.exports = { watch };
