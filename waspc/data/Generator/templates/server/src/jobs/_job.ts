{{={= =}=}}
import prisma from '../dbClient.js'
import type { JSONValue } from '../_types/serialization.js'
import { createJob, type JobFn } from './{= jobExecutorRelativePath =}'
{=& jobPerformFnImportStatement =}

const entities = {
  {=# entities =}
  {= name =}: prisma.{= prismaIdentifier =},
  {=/ entities =}
};

export type {= typeName =}<Input extends object, Output extends JSONValue | void> = JobFn<Input, Output, typeof entities>

export const {= jobName =} = createJob({
  jobName: "{= jobName =}",
  jobFn: {= jobPerformFnName =},
  defaultJobOptions: {=& jobPerformOptions =},
  jobSchedule: {=& jobSchedule =},
  entities,
})
