import sys
import os
import pickle
import matplotlib.pyplot as plt

import analyseMany as am
import analyseOne as ao
import analyseUtil as util

def oneFile():
  pckFilePath = sys.argv[1]
  with open(pckFilePath, 'rb') as f:
    eulogies = pickle.load(f)

  ao.drawFamilyTree(eulogies)

  agentId = util.pickLastAgent(eulogies)
  print(agentId, eulogies[agentId])
  ao.drawOneFamilyTree(eulogies, agentId)

  agentId = util.pickLongestAgent(eulogies)
  print(agentId, eulogies[agentId])
  ao.drawOneFamilyTree(eulogies, agentId)

  ao.plotGenerationAges(eulogies)
  ao.plotGenerationRewards(eulogies)
  ao.plotAgeGeneration(eulogies)
  ao.plotBDPerTick(eulogies)

  plt.show()

def manyFiles():
  '''
  Filename will automatically be appended with pdf for rasterised images.
  '''
  dirs = [d for d in sys.argv[1:] if os.path.isdir(d)]
  if not dirs:
    print('No files to analyse')
    return

  am.plotPopulationStatistics(dirs)
  am.plotPopulationDeclines(dirs)

  plt.show()

if __name__ == '__main__':
  argc = len(sys.argv)
  if argc <= 1:
    print("Missing args!")
  elif argc == 2:
    oneFile()
  else:
    manyFiles() 
