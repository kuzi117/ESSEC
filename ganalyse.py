import os
import sys

import analyseGenes as ag
import analyseUtil as util

if __name__ == '__main__':
  argc = len(sys.argv)

  if argc <= 1:
    print('Missing arguments.')
    sys.exit(0)
  
  files = []
  for path in sys.argv[1:]:
    if os.path.isdir(path):
      files.extend(util.gatherPcks(path))
    elif os.path.isfile(path) and os.path.splitext(path)[1] == '.pck':
      files.append(path)
    else:
      print('Couldn\'t figure out {}'.format(path))

  print('Found {} files to analyse.'.format(len(files)))

  data = ag.getLastData(files)
  print('After loading, {} files were left.'.format(len(data)))

  #ag.rankMaxProfile(data)
  ag.rankMaxPrefInput(data)
