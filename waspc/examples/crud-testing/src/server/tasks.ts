import HttpError from "@wasp/core/HttpError.js";
import type { GetQuery, GetAllQuery, CreateAction } from "@wasp/crud/tasks";
import { Task, User } from "@wasp/entities";
import { simplePrintJob } from "@wasp/jobs/simplePrintJob.js";

export const getTask = (async (args, context) => {
  return context.entities.Task.findUnique({
    where: { id: args.id },
    include: {
      user: { select: { username: true } },
    },
  });
}) satisfies GetQuery<
  { id: Task["id"] },
  | (Task & {
      user: Pick<User, "username">;
    })
  | null
>;

export const getAllTasks = (async (args, context) => {
  const result = await simplePrintJob.submit({
    name: "moje ime",
  });
  let i = 0;
  while (i < 3) {
    console.log(result);
    await new Promise((resolve) => setTimeout(resolve, 1000));
    i++;
  }
  return context.entities.Task.findMany({
    orderBy: { id: "desc" },
    select: {
      id: true,
      title: true,
      user: {
        select: {
          username: true,
        },
      },
    },
  });
}) satisfies GetAllQuery<{}, {}>;

export const createTask = (async (args, context) => {
  if (!context.user) {
    throw new HttpError(401, "You must be logged in to create a task.");
  }
  if (!args.title) {
    throw new HttpError(400, "Task title is required.");
  }
  return context.entities.Task.create({
    data: {
      title: args.title!,
      user: {
        connect: {
          id: context.user.id,
        },
      },
    },
  });
}) satisfies CreateAction<{ title: Task["title"] }, Task>;
