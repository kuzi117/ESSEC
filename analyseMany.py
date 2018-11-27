'''
Contains code for analysing many data files at once.
'''
import sys
if __name__ == '__main__':
  print('Run analyse.py not analyseMany.py')
  sys.exit(1)

import analyseUtil as util

import pickle
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
