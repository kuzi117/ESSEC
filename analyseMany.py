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
  print(dataFiles)
  dataFiles = {d: rnd.sample(dataFiles[d], minLen) for d in dataFiles}
  print(dataFiles)

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
  plt.show()

def plotSweepStatistics(dirs):
  '''
  Given a list of directories, this will print populations statistics for comparison.
  '''
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

  # Text dump.
  for d in data:
    dirData = data[d]
    print("{} = MEAN: {}, MEDIAN: {}, MAX: {}"
          .format(d, np.mean(dirData), np.median(dirData), max(dirData)))

  # Plot parameters.
  width = 0.25
  ind = np.arange(len(data))

  # Get plot.
  fig = plt.figure()
  ax = fig.add_subplot(1, 1, 1)

  # Plot data.
  means = []
  meds = []
  maxes = []
  names = []
  for d in data:
    # Data.
    means.append(np.mean(data[d]))
    meds.append(np.median(data[d]))
    maxes.append(max(data[d]))

    # Make a name for this.
    for w in reversed(os.path.split(d)):
      if w:
        names.append(w)
        break
    else:
      assert False, 'Couldn\'t find a name for the population'

  # Plot dump.
  rects = []
  for i, m in enumerate([means, meds, maxes]):
    rect = ax.bar(ind + i * width, m, width=width)
    rects.append(rect)

  # Plot setup.
  ax.set_xticks(ind + width)
  ax.set_xticklabels(names, rotation=90)
  ax.set_ylabel('Age (ticks)')
  ax.set_xlabel('Population')
  ax.set_title('Population Survival Time Statistics')
  ax.legend(rects, ('Mean', 'Median', 'Max'))
  fig.tight_layout()
