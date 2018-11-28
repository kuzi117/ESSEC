'''
Holds utility functions for analysing data.
'''
import sys
if __name__ == '__main__':
  print('Run analyse.py not analyseUtil.py')
  sys.exit(1)

import random
import os

def createColor():
  r = "{:02X}".format(random.randint(20, 200))
  g = "{:02X}".format(random.randint(20, 200))
  b = "{:02X}".format(random.randint(20, 200))
  return "#" + r + g + b

def pickLastAgent(data):
  '''
  Picks the agent who died last.
  '''
  return max((agentId for agentId in data), key=lambda i: data[i][5])

def pickLongestAgent(data):
  '''
  Picks the agent who lived longest.
  '''
  return max((agentId for agentId in data), key=lambda i: data[i][2])

def extractFamily(agentId, data, includeChildren):
  '''
  Extract a family tree starting with this agent. If include children is true
  then we pass downwards to find children.
  (parent, partner, age, generation, reward_avg, death_tick)
  '''
  # The result.
  family = {agentId}
  
  # Get ancestors family members (up pass).
  toSee = [agentId]
  while toSee:
    a = toSee.pop(0)
    parent = data[a][0]
    partner = data[a][1]
    if parent not in family and parent >= 0:
      family.add(parent)
      toSee.append(parent)
    if partner not in family and partner >= 0:
      family.add(partner)
      toSee.append(partner)

  # Get children family members (down pass). This is much more expensive
  # because we need to scan every agent now and build a reverse mapping.
  # Children becomes a dictionary with value of tuple(set, set). Where
  # the first set is children it was parent for and second set is
  # children it was partner for.
  if includeChildren:
    children = {a: (set(), set()) for a in data}
    for a in data:
      parent = data[a][0]
      partner = data[a][1]

      # Add to parent map.
      if parent <= 0:
        pass # Do nothing for top level agents
      else:
        children[parent][0].add(a)

      # Add to partner map.
      if partner <= 0:
        pass # Do nothing for top level agents
      else:
        children[partner][1].add(a)

    # We start by looking at children for which this agent was the parent for.
    toSee = children[agentId][0].copy()
    while toSee:
      # Add this agent to the family.
      a = toSee.pop()
      family.add(a)

      toSee |= children[a][0] - family
    
  return family

def gatherPcks(path):
  # Sanity.
  assert os.path.exists(path), 'Gather pcks path does not exist'
  assert os.path.isdir(path), 'Gather pcks not in dir.'

  # Keep only pck files.
  dirFiles = []
  for f in os.listdir(path):
    d = os.path.join(path, f)
    if os.path.isfile(d) and os.path.splitext(d)[1] == '.pck':
      dirFiles.append(d)

  return dirFiles
