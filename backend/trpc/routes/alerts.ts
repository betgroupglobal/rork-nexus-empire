import { z } from "zod";
import { createTRPCRouter, publicProcedure } from "../create-context";
import { AlertTypeEnum } from "../../db";
import prisma from "../../prisma";

export const alertsRouter = createTRPCRouter({
  list: publicProcedure
    .input(
      z.object({
        type: AlertTypeEnum.optional(),
      }).optional()
    )
    .query(async ({ input }) => {
      return prisma.nexusAlert.findMany({
        where: input?.type ? { type: input.type } : undefined,
        orderBy: { timestamp: "desc" },
      });
    }),

  markRead: publicProcedure
    .input(z.object({ id: z.string().uuid() }))
    .mutation(async ({ input }) => {
      const alert = await prisma.nexusAlert.update({
        where: { id: input.id },
        data: { isRead: true },
      });
      return alert;
    }),

  markAllRead: publicProcedure.mutation(async () => {
    await prisma.nexusAlert.updateMany({
      where: { isRead: false },
      data: { isRead: true },
    });
    return { success: true };
  }),
});