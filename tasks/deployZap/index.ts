import { Task, TaskRunOptions } from '../../hardhat'
import { DeploymentInputs } from './input'

function getTimestampInSeconds(offset = 0) {
  return Math.floor(Date.now() / 1000) + offset
}

export default async (task: Task, { force, from }: TaskRunOptions = {}): Promise<void> => {
  const input = task.input() as DeploymentInputs
  const args = [input.WNATIVE, input.GNANATreasury]
  await task.deployAndVerify('ApeSwapZapFullV5', args, from, force)
}
