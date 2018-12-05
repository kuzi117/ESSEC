'''
Contains code for analysing many data files at once.
'''
import sys
if __name__ == '__main__':
  print('Run analyse.py not analyseMany.py')
  sys.exit(1)

import analyseUtil as util

import os
import random
import pickle
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

def _plotPopDecl(inputFiles, ax, color, qts=True):
  '''
  Helper function that plots one population decline. Returns info for legend.
  '''
  deathTimes = []
  
  # Get all population death times.
  for pckFilePath in inputFiles:
    with open(pckFilePath, 'rb') as f:
      eulogies = pickle.load(f)
      agentId = util.pickLastAgent(eulogies)
      deathTimes.append(eulogies[agentId][5])
  deathTimes.sort()
  
  # Death times data.
  curY = len(deathTimes)
  xs = [0]
  ys = [curY]

  # Plot death times.
  for d in deathTimes:
    ys.append(curY)
    xs.append(d)
    curY -= 1
    ys.append(curY)
    xs.append(d)
  curve, = ax.plot(xs, ys, color=color)

  # Quartile data.
  if qts:
    qtData = []
    for i in range(1, 4):
      p = round(len(deathTimes) * (i / 4))
      height = len(deathTimes) - p - 1
      dTime = deathTimes[p]
      qtData.append(([0, dTime], [height, height]))
      qtData.append(([dTime, dTime], [0, height]))

    # Plot Quartiles.
    for x, y in qtData:
      ax.plot(x, y, color='r', linestyle='--', linewidth=0.5)

  return ((0, deathTimes[-1] * 1.01), (0, len(deathTimes) + 1), curve)

def plotPopulationDeclines(inputDirs, filename=None):
  if filename is None:
    filename = 'popDecline'

  # Data setup.
  dataFiles = {}
  for d in inputDirs:
    dataFiles[d] = util.gatherPcks(d)

  # Same random sample out.
  rnd = random.Random(x=1)
  minLen = min([len(dataFiles[d]) for d in dataFiles])
  dataFiles = {d: rnd.sample(dataFiles[d], minLen) for d in dataFiles}

  # Get plot.
  fig = plt.figure(figsize=(5, 3.75))
  ax = fig.add_subplot(1, 1, 1)
  sns.set_style('ticks')
  palette = sns.color_palette('colorblind')

  # Plotting.
  oxb = (float('inf'), float('-inf'))
  oyb = (float('inf'), float('-inf'))
  curves = []
  names = []
  for i, d in enumerate(dataFiles):
    xb, yb, curve = _plotPopDecl(dataFiles[d], ax, palette[i], qts=False)
    #xb, yb, curve = _plotPopDecl(dataFiles[d], ax, util.createColor(), qts=False)
    oxb = (min(oxb[0], xb[0]), max(oxb[1], xb[1]))
    oyb = (min(oyb[0], yb[0]), max(oyb[1], yb[1]))
    curves.append(curve)
    
    # Make a name for this.
    for w in reversed(os.path.split(d)):
      if w:
        names.append(w.replace('_', ' ').title())
        break
    else:
      assert False, 'Couldn\'t find a name for the population'

  # Plot setup.
  ax.set_xlim(oxb)
  ax.set_ylim(oyb)
  ax.set_xlabel('Population Age (ticks)', labelpad=10)
  ax.set_ylabel('Populations Surviving', labelpad=10)
  ax.legend(curves, names, frameon=False)

  # Save and show.
  fig.tight_layout()
  fig.savefig(filename + '.pdf', bbox_inches='tight')

def plotPopulationStatistics(dirs, filename=None):
  '''
  Given a list of directories, this will print populations statistics for comparison.
  '''
  if filename is None:
    filename = 'popStats'

  # Get files.
  files = {}
  for d in dirs:
    # Skip non-directories.
    if not os.path.isdir(d):
      continue

    # Save files for dir.
    files[d] = util.gatherPcks(d)

  # Get data.
  data = {}
  for d in files:
    dirData = []
    for path in files[d]:
      with open(path, 'rb') as f:
        eulogies = pickle.load(f)
        agentId = util.pickLastAgent(eulogies)
        dirData.append(eulogies[agentId][5])
    data[d] = dirData

  # Same random sample out.
  rnd = random.Random(x=1)
  minLen = min([len(data[d]) for d in data])
  data = {d: rnd.sample(data[d], minLen) for d in data}

  # Text dump.
  for d in data:
    dirData = data[d]
    print("{} = MEAN: {}, MEDIAN: {}, MAX: {}"
          .format(d, np.mean(dirData), np.median(dirData), max(dirData)))

  # Plot parameters.
  width = 0.25
  ind = np.arange(len(data))

  # Get plot.
  fig = plt.figure(figsize=(5, 2.5))
  ax = fig.add_subplot(1, 1, 1)

  # Names.
  names = []
  for d in data:
    # Make a name for this.
    for w in reversed(os.path.split(d)):
      if w:
        names.append(w.replace('_', ' ').title())
        break
    else:
      assert False, 'Couldn\'t find a name for the population'

  # Box plot.
  sns.set(style="ticks")
  boxData = [data[d] for d in data]
  sns.boxplot(data=boxData, ax=ax, orient='h', showmeans=True, palette='muted')

  # Plot setup.
  ax.set_yticklabels(names)
  ax.set_xlabel('Population Age (ticks)', labelpad=10)
  
  # Figure setup.
  fig.tight_layout()
  fig.savefig(filename + '.pdf', bbox_inches='tight')

def plotMeans(dirs, filename=None):
  '''
  Given a list of directories, this will plot mean and standard deviation
  '''
  if filename is None:
    filename = 'popMean'

  # Get files.
  files = {}
  for d in dirs:
    # Skip non-directories.
    if not os.path.isdir(d):
      continue

    # Save files for dir.
    files[d] = util.gatherPcks(d)

  # Get data.
  data = {}
  for d in files:
    dirData = []
    for path in files[d]:
      with open(path, 'rb') as f:
        eulogies = pickle.load(f)
        agentId = util.pickLastAgent(eulogies)
        dirData.append(eulogies[agentId][5])
    data[d] = dirData

  # Same random sample out.
  rnd = random.Random(x=1)
  minLen = min([len(data[d]) for d in data])
  data = {d: rnd.sample(data[d], minLen) for d in data}

  # Names.
  names = []
  for d in data:
    # Make a name for this.
    for w in reversed(os.path.split(d)):
      if w:
        names.append(w.replace('_', ' ').title())
        break
    else:
      assert False, 'Couldn\'t find a name for the population'

  # Get plot data.
  means = []
  errors = []
  for d in data:
    mean = np.mean(data[d])
    error = np.std(data[d]) / np.sqrt(len(data[d]))

    print("{}: MEAN={}, ERR={}".format(d, mean, error))

    means.append(mean)
    errors.append(error)


  # Get plot.
  #fig = plt.figure(figsize=(5, 2.5))
  fig = plt.figure()
  ax = fig.add_subplot(1, 1, 1)

  # Error plot.
  sns.set(style="ticks")
  ax.errorbar(names, means, errors, linestyle='None', marker='o')

  # Plot setup.
  #ax.set_yticklabels(names)
  ax.set_xlabel('Population Age (ticks)', labelpad=10)
  ax.set_xticklabels(names, rotation=90)

  # Figure setup.
  fig.tight_layout()
  fig.savefig(filename + '.pdf', bbox_inches='tight')
