'''
Contains code for analysing a single data file.
'''
import sys
if __name__ == '__main__':
  print('Run analyse.py not analyseOne.py')
  sys.exit(1)

import analyseUtil as util

import math
import itertools
import numpy as np
from scipy import optimize
import matplotlib.pyplot as plt

def drawFamilyTree(data, keys=None, filename=None):
  '''
  (parent, partner, age, generation, reward_avg)
  '''
  # Initial setup.
  if filename is None:
    filename = 'familyTree.dot'
  if keys is None:
    keys = data.keys()

  with open(filename, 'w') as f:
    f.write('digraph familyTree {\n')
    f.write('  rankdir="TB";\n')
    f.write('  ordering="out";\n')

    # Generate colors for every generation.
    genClr = {}
    for i in range(max(data[a][3] for a in data) + 1):
        genClr[i] = util.createColor()
      
    # Attributes.
    attStr = '  {0} [label="{0},{1}st,g{3}" style="filled" color="{2}" fillcolor="{2}"];\n'
    for i in keys:
      # Get data.
      d = data[i]
      gen = d[3]
      clr = genClr[gen]

      f.write(attStr.format(i, d[2], clr, gen))

    # Relationships
    relStr = '  {} -> {} [constraint="true"];\n'
    matStr = '  {} -> {} [style="dotted" dir="both" color="red" constraint="false"];\n'
    extras = []
    childRels = []
    parentRels = []
    for i in keys:
      # Get data.
      d = data[i]
      parent = d[0]
      partner = d[1]

      # Draw relationships.
      if parent >= 0:
        childRels.append(relStr.format(d[0], i))
      if partner >= 0:
        childRels.append(relStr.format(d[1], i))
      if parent >= 0 and partner >= 0:
        parentRels.append(matStr.format(parent, partner))

      # Save parent who is not in keys.
      if parent not in keys and parent >= 0:
        extras.append(parent)
      if partner not in keys and partner >= 0:
        extras.append(partner)

    # Dump relationships.
    for line in itertools.chain(childRels, parentRels):
      f.write(line)
    del childRels
    del parentRels

    # Ranking.
    f.write(' // Manual ranking.\n')

    # Hackily use the genNumbers from genClr.
    rankStrs = {}
    for i in genClr:
      rankStr = ""
      rankStr += '  // Rank {}.\n'.format(i)
      rankStr += '  {\n    rank = "same";\n'
      rankStrs[i] = rankStr

    for i in keys:
      rankStrs[data[i][3]] += '  {};\n'.format(i)

    for i in extras:
      rankStrs[data[i][3]] += '  {};\n'.format(i)

    for i in genClr:
      rankStrs[i] += '  }\n'
      f.write(rankStrs[i])
      del rankStrs[i]

    f.write('}\n')

def drawOneFamilyTree(data, agentId, filename=None, children=False):
  '''
  Convenience function for printing one family tree.
  '''
  if filename is None:
    filename = '{}FamilyTree.dot'.format(agentId)
  drawFamilyTree(data, keys=util.extractFamily(agentId, data, children), 
                 filename=filename)

def plotGenerationAges(data, keys=None, filename=None):
  '''
  Filename will automatically be append with pdf for rasterised images.
  '''
  # Initial setup.
  if keys is None:
    keys = data.keys()
  if filename is None:
    filename = 'genAges'

  # Get figure.
  fig = plt.figure()
  ax = fig.add_subplot(1, 1, 1)
 
  # All points data plot.
  age = []
  gen = []
  for i in data:
    d = data[i]
    g = d[3]
    age.append(d[2])
    gen.append(g)
  agePlot = ax.scatter(gen, age, color='blue', s=1)

  # Average life times plot.
  maxGen = max(data[a][3] for a in data)
  genX = np.array(range(maxGen + 1))
  genAges = [[data[a][2] for a in data if data[a][3] == g] for g in genX]
  avgAges = np.array([sum(ga)/len(ga) for ga in genAges])
  avgPlot = ax.scatter(genX, avgAges, color='red', marker='+', s=30)

  # LoBF for averages.
  line = np.polyfit(genX, avgAges, 1)
  curve = np.polyfit(genX, avgAges, 2)
  linear, = ax.plot(genX, [x * line[0] + line[1] for x in genX], color='green')
  quad, = ax.plot(genX, [x ** 2 * curve[0] + x * curve[1] + curve[2] for x in genX],
                 color='black')

  # LoBF sine.
  #f = lambda x, a, b, c, d: a * np.sin(b * x + c) + d
  #(a, b, c, d), _ = optimize.curve_fit(f, genX, avgAges, p0=((max(avgAges) - np.mean(avgAges)) / 3, 1/8, 5, np.mean(avgAges)))
  #(a, b, c, d) = ((max(avgAges) - np.mean(avgAges)) / 3, 1/8, 5, np.mean(avgAges))
  #sine = ax.plot(genX, [f(x, a, b, c, d) for x in genX], color='#FFFF00')

  # Plot setup.
  ax.set_xlabel('Generation')
  ax.set_ylabel('Age (ticks)')
  ax.set_title('Agent Ages Across Generations')
  ax.legend((agePlot, avgPlot, linear, quad),
            ('Agent Age', 'Generation Average Age',
             'Linear Best Fit', 'Quadratic Best Fit'))

  # Save.
  fig.savefig(filename + '.pdf', bbox_inches='tight')
  
def plotGenerationRewards(data, keys=None, filename=None):
  '''
  Filename will automatically be append with pdf for rasterised images.
  '''
  # Initial setup.
  if keys is None:
    keys = data.keys()
  if filename is None:
    filename = 'genRwds'

  # Get figure.
  fig = plt.figure()
  ax = fig.add_subplot(1, 1, 1)
 
  # All points data plot.
  rwd = []
  gen = []
  for i in data:
    d = data[i]
    g = d[3]
    rwd.append(d[4])
    gen.append(g)
  rwdPlot = ax.scatter(gen, rwd, color='blue', s=1)

  # Average rewards plot.
  maxGen = max(data[a][3] for a in data)
  genX = np.array(range(maxGen + 1))
  genRwds = [[data[a][4] for a in data if data[a][3] == g] for g in genX]
  avgRwds = np.array([sum(gr)/len(gr) for gr in genRwds])
  avgPlot = ax.scatter(genX, avgRwds, color='red', marker='+', s=30)

  # LoBF for averages.
  line = np.polyfit(genX, avgRwds, 1)
  curve = np.polyfit(genX, avgRwds, 2)
  linear, = ax.plot(genX, [x * line[0] + line[1] for x in genX], color='green')
  quad, = ax.plot(genX, [x ** 2 * curve[0] + x * curve[1] + curve[2] for x in genX],
                 color='black')

  # Plot setup.
  ax.set_xlabel('Generation')
  ax.set_ylabel('Reward')
  ax.set_title('Agent Rewards Across Generations')
  ax.legend((rwdPlot, avgPlot, linear, quad),
            ('Agent Average Lifetime Reward', 'Generation Average Average Reward',
             'Linear Best Fit', 'Quadratic Best Fit'))
  ax.set_xlim([0, maxGen])
  ax.set_ylim([min(data[a][4] for a in data), max(data[a][4] for a in data)])

  # Save.
  fig.savefig(filename + '.pdf', bbox_inches='tight')

def plotAgeGeneration(data, keys=None, filename=None):
  '''
  Filename will automatically be append with pdf for rasterised images.
  '''
  # Initial setup.
  if keys is None:
    keys = data.keys()
  if filename is None:
    filename = 'ageGen'
  
  # Data setup.
  age = []
  gen = []
  for i in data:
    d = data[i]
    age.append(d[2])
    gen.append(d[3])

  reorder = sorted(range(len(age)), key=lambda i: age[i], reverse=True)
  age = [age[i] for i in reorder]
  gen = [gen[i] * 4for i in reorder]
  
  fig = plt.figure()
  ax = fig.add_subplot(1, 1, 1)

  ax.scatter(range(len(gen)), gen)
