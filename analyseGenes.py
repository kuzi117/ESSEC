import itertools
import numpy as np
import pickle
import _pickle

# Create names and info for producing mapping names.
actionNames = ('move', 'right', 'left', 'mate', 'eat')
stateNames = ('bias', 'energy', 'θs', 'Δs', 'θw', 'Δw', 'θg', 'Δg', 'pref', 'childAge')
profileSize = 30

# Produce name mappings for all of the weights.
actionWeightNames = tuple('{}TO{}'.format(s, a) for s in stateNames for a in actionNames)
valueWeightNames = tuple('{}TOval'.format(s) for s in stateNames)
genomeWeightNames = tuple(itertools.chain(valueWeightNames, actionWeightNames))
profileWeightNames = tuple('({})TO{}'.format(w, o)
                           for w in genomeWeightNames
                           for o in range(profileSize))

# Profile input info.
genomeSize = len(genomeWeightNames)

#for i in range(len(profileWeightNames)):
#  assert genomeWeightNames[i // profileSize] in profileWeightNames[i]

def getLastData(files):
  # Extract last agent data from files.
  data = []
  for i, path in enumerate(files):
    if i % 100 == 0:
      print(i, end=' ')
    with open(path, 'rb') as f:
      # Apparently some files didn't finish dumping.
      try:
        genes = pickle.load(f)
      except EOFError:
        print('{} was malformed, skipping (eof).'.format(path))
      except _pickle.UnpicklingError:
        print('{} was malformed, skipping (unpickling error).'.format(path))

      # Get last agent.
      lastAgent = max(genes.keys())
      lastData = genes[lastAgent]

      # Sanity check.
      assert len(lastData['initial_action_net'].flat) == len(actionWeightNames)
      assert len(lastData['evaluation_net'].flat) == len(valueWeightNames)
      assert len(lastData['profile_net'].flat) == len(profileWeightNames)

      data.append(lastData)
      
  return data

def rankMaxPreference(data):
  counts = np.zeros((genomeSize, ), dtype=np.int32)
  
  print(len(data))
  for d in data:
    prof = d['profile_net'].flat
    prof = np.abs(prof)
    inds = np.argsort(-prof) # Make all values negative in the arg sort for reverse order
    
    counts[inds[0] // profileSize] += 1

  print(counts)
  cInds = np.argsort(-counts)
  for i, w in enumerate(cInds[:10]):
    print('Rank: {}, Name: {}, Count: {}'.format(i, genomeWeightNames[w], counts[w]))

def rankAllPreferences(data):
  # First index is a weight, second index is the number of times that it appeared in that
  # place in the sorted absolute weights.
  n = len(profileWeightNames)
  counts = np.zeros((n, n), dtype=np.int32)

  for d in data:
    prof = d['profile_net'].flat
    prof = np.abs(prof)
    inds = np.argsort(-prof) # Make all values negative in the arg sort for reverse order

    # The wth weight was sorted into the ith position.
    for i, w in enumerate(inds):
      counts[w, i] += 1

  cInds = np.lexsort(np.rot90(-counts))
  for i in cInds[:10]:
    print('Rank: {}, Name: {}, Count: {}'.format(i, profileWeightNames[i], counts[i][:10]))
