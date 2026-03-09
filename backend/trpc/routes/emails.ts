import { z } from "zod";
import { createTRPCRouter, publicProcedure } from "../create-context";
import { EmailCategoryEnum } from "../../db";
import prisma from "../../prisma";

export const emailsRouter = createTRPCRouter({
  list: publicProcedure
    .input(
      z.object({
        entityId: z.string().uuid().optional(),
        subjectId: z.string().uuid().optional(),
        category: EmailCategoryEnum.optional(),
      }).optional()
    )
    .query(async ({ input }) => {
      const scopedId = input?.subjectId ?? input?.entityId;
      return prisma.email.findMany({
        where: {
          ...(scopedId ? { entityId: scopedId } : {}),
          ...(input?.category ? { category: input.category } : {}),
        },
        orderBy: { timestamp: "desc" },
      });
    }),

  markRead: publicProcedure
    .input(z.object({ id: z.string().uuid() }))
    .mutation(async ({ input }) => {
      return prisma.email.update({
        where: { id: input.id },
        data: { isRead: true },
      });
    }),

  toggleFlag: publicProcedure
    .input(z.object({ id: z.string().uuid() }))
    .mutation(async ({ input }) => {
      const current = await prisma.email.findUnique({ where: { id: input.id } });
      if (!current) throw new Error("Email not found");
      return prisma.email.update({
        where: { id: input.id },
        data: { isFlagged: !current.isFlagged },
      });
    }),

  send: publicProcedure
    .input(
      z.object({
        entityId: z.string().uuid(),
        subject: z.string(),
        content: z.string(),
        to: z.string(),
      })
    )
    .mutation(async ({ input }) => {
      const entity = await prisma.entity.findUnique({ where: { id: input.entityId } });
      if (!entity) throw new Error("Entity not found");

      return prisma.email.create({
        data: {
          entityId: entity.id,
          entityName: entity.name,
          sender: "Nexus System",
          senderAddress: "system@nexus.local",
          subject: input.subject,
          snippet: input.content.substring(0, 100),
          category: "General",
          timestamp: new Date(),
          isRead: true,
          isFlagged: false,
          containsDollarAmount: input.content.includes("$"),
          alias: input.to,
        }
      });
    }),

  syncMailbox: publicProcedure
    .mutation(async () => {
      // Mock mailbox sync integration
      // In a real scenario, this would connect to IMAP/Exchange
      const syncedCount = Math.floor(Math.random() * 5);
      return { success: true, syncedCount, message: `Synced ${syncedCount} new emails from remote mailbox.` };
    }),
});