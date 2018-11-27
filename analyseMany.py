'''
Contains code for analysing many data files at once.
'''
import sys
if __name__ == '__main__':
  print('Run analyse.py not analyseMany.py')
  sys.exit(1)

import analyseUtil as util

import os
import pickle
import numpy as np
import matplotlib.pyplot as plt

def plotPopulationDeclines(inputFiles, filename=None):
  if filename is None:
    filename = 'popDecline'

  deathTimes = []
  
  # Get all population death times.
  for pckFilePath in inputFiles:
    with open(pckFilePath, 'rb') as f:
      eulogies = pickle.load(f)
      agentId = util.pickLastAgent(eulogies)
      deathTimes.append(eulogies[agentId][5])
  deathTimes.sort()

  # Get plot.
  fig = plt.figure()
  ax = fig.add_subplot(1, 1, 1)
  
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
  ax.plot(xs, ys)

  # Quartile data.
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

  # Plot setup.
  ax.set_xlim([0, deathTimes[-1] * 1.01])
  ax.set_ylim([0, len(deathTimes) + 1])
  ax.set_xlabel('Age (ticks)')
  ax.set_ylabel('Populations Surviving')
  ax.set_title('Populations Surviving Over Time')

  # Save and show.
  fig.savefig(filename + '.pdf', bbox_inches='tight')
  plt.show()

def printSweepStatistics(dirs):
  '''
  Given a list of directories, this will print populations statistics for comparison.
  '''
  # Get files.
  files = {}
  for d in dirs:
    # Skip non-directories.
    if not os.path.isdir(d):
      continue

    # Keep only pck files.
    dirFiles = []
    for f in os.listdir(d):
      path = os.path.join(d, f)
      if os.path.isfile(path) and os.path.splitext(path)[1] == '.pck':
        dirFiles.append(path)

    # Save files for dir.
    files[d] = dirFiles

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

  # Plot dump.
  means = [np.mean(data[d]) for d in data]
  meds = [np.median(data[d]) for d in data]
  maxes = [max(data[d]) for d in data]
  rects = []
  for i, m in enumerate([means, meds, maxes]):
    rect = ax.bar(ind + i * width, m, width=width)
    rects.append(rect)

  # Plot setup.
  ax.set_xticks(ind + width)
  ax.set_xticklabels([os.path.split(d)[-1] for d in dirs], rotation=45)
  ax.set_ylabel('Age (ticks)')
  ax.legend(rects, ('Mean', 'Median', 'Max'))
  fig.tight_layout()
