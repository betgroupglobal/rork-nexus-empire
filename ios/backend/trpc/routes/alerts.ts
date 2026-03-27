import { z } from "zod";
import { createTRPCRouter, publicProcedure } from "../create-context";
import { db, AlertTypeEnum } from "../../db";

export const alertsRouter = createTRPCRouter({
  list: publicProcedure
    .input(
      z.object({
        type: AlertTypeEnum.optional(),
      }).optional()
    )
    .query(({ input }) => {
      let alerts = db.alerts;
      if (input?.type) {
        alerts = alerts.filter((a) => a.type === input.type);
      }
      return alerts.sort(
        (a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime()
      );
    }),

  markRead: publicProcedure
    .input(z.object({ id: z.string().uuid() }))
    .mutation(({ input }) => {
      const idx = db.alerts.findIndex((a) => a.id === input.id);
      if (idx === -1) throw new Error("Alert not found");
      db.alerts[idx]!.isRead = true;
      return db.alerts[idx]!;
    }),

  markAllRead: publicProcedure.mutation(() => {
    db.alerts.forEach((a) => (a.isRead = true));
    return { success: true };
  }),
});
