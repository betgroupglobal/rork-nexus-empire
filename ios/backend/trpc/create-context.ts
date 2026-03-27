import { initTRPC } from "@trpc/server";
import superjson from "superjson";

export const createContext = async (opts: { req: Request; resHeaders: Headers }) => {
  return {
    req: opts.req,
  };
};

export type Context = Awaited<ReturnType<typeof createContext>>;

const t = initTRPC.context<Context>().create({
  transformer: superjson,
});

export const createTRPCRouter = t.router;
export const publicProcedure = t.procedure;
