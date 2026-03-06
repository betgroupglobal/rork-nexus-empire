import { createTRPCRouter } from "./create-context";
import { entitiesRouter } from "./routes/entities";
import { communicationsRouter } from "./routes/communications";
import { emailsRouter } from "./routes/emails";
import { alertsRouter } from "./routes/alerts";
import { authRouter } from "./routes/auth";

export const appRouter = createTRPCRouter({
  auth: authRouter,
  entities: entitiesRouter,
  communications: communicationsRouter,
  emails: emailsRouter,
  alerts: alertsRouter,
});

export type AppRouter = typeof appRouter;
