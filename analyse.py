import sys
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

  plt.show()

def manyFiles(filename=None):
  '''
  Filename will automatically be append with pdf for rasterised images.
  '''
  am.plotPopulationDeclines(sys.argv[1:])

  plt.show()

if __name__ == '__main__':
  argc = len(sys.argv)
  if argc <= 1:
    print("Missing args!")
  elif argc == 2:
    oneFile()
  else:
    manyFiles() 
