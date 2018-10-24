import numpy

agent_genomes = {}
agent_preferences = {}
def get_preference(self, other):
  other_genome = np.concatenate(
          (agent_genomes[other]['evaluation_net'].flat,
           agent_genomes[other]['initial_action_net'].flat)
          ).flat

  preference = agent_genomes[self]['preference_net']

  return np.dot(other_genome, preference)[0]


# Plotting functions
# Moving window step reward.
windowLength = None
def initStepPlot(n):
  global windowLength
  windowLength = n

# Moving window average values. Amortize calculations by performing updates at
# each step.
windowQ = None

# Global average of average values.
avg = None
stepCount = None

def addStepRewards(stepReward):
  # Update rolling average if not None. If it is None then we're in the first
  # time step where we are sent all zeroes. We just skip it.
  global stepCount
  global avg
  if avg is not None and stepCount is not None:
    # Increment step count.
    stepCount += 1

    # Update moving average.
    avg = avg + (sum(stepReward) - avg) / stepCount
  else:
    stepCount = 0
    avg = 0

  # Update window if not None. If it is None then we're in the first time step
  # where we are sent all zeroes. We just skip it.
  global windowQ
  if windowQ is not None:
    # Append the new reward.
    windowQ.append(sum(stepReward))

    # Pop things off until we're the right size.
    while (len(windowQ) > windowLength):
      windowQ.pop(0)

  # Set up the queue, skipping the first iteration.
  else:
      windowQ = []


def getWindowRewardAvg():
  # We already have the sum and count tracked when maintaining the queue. Just
  # report.
  return sum(windowQ) / len(windowQ) if windowQ != None and len(windowQ) > 0 else 0

def getAllRewardAvg():
  # The rolling average is already computed when adding step info. Just return.
  return avg if stepCount != None and stepCount > 0 else 0
