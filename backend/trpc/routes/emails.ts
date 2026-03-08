import { z } from "zod";
import { createTRPCRouter, publicProcedure } from "../create-context";
import { db, EmailCategoryEnum } from "../../db";

export const emailsRouter = createTRPCRouter({
  list: publicProcedure
    .input(
      z.object({
        entityId: z.string().uuid().optional(),
        subjectId: z.string().uuid().optional(),
        category: EmailCategoryEnum.optional(),
      }).optional()
    )
    .query(({ input }) => {
      let emails = db.emails;
      const scopedId = input?.subjectId ?? input?.entityId;
      if (scopedId) {
        emails = emails.filter((e) => e.entityId === scopedId);
      }
      if (input?.category) {
        emails = emails.filter((e) => e.category === input.category);
      }
      return emails.sort(
        (a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime()
      );
    }),

  markRead: publicProcedure
    .input(z.object({ id: z.string().uuid() }))
    .mutation(({ input }) => {
      const idx = db.emails.findIndex((e) => e.id === input.id);
      if (idx === -1) throw new Error("Email not found");
      db.emails[idx]!.isRead = true;
      return db.emails[idx]!;
    }),

  toggleFlag: publicProcedure
    .input(z.object({ id: z.string().uuid() }))
    .mutation(({ input }) => {
      const idx = db.emails.findIndex((e) => e.id === input.id);
      if (idx === -1) throw new Error("Email not found");
      db.emails[idx]!.isFlagged = !db.emails[idx]!.isFlagged;
      return db.emails[idx]!;
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
    .mutation(({ input }) => {
      const entity = db.entities.find((e) => e.id === input.entityId);
      if (!entity) throw new Error("Entity not found");

      const newEmail = {
        id: crypto.randomUUID(),
        entityId: entity.id,
        entityName: entity.name,
        sender: "Nexus System",
        senderAddress: "system@nexus.local",
        subject: input.subject,
        snippet: input.content.substring(0, 100),
        category: "General" as const,
        timestamp: new Date().toISOString(),
        isRead: true,
        isFlagged: false,
        containsDollarAmount: input.content.includes("$"),
        alias: input.to,
      };

      db.emails.unshift(newEmail);
      return newEmail;
    }),

  syncMailbox: publicProcedure
    .mutation(async () => {
      // Mock mailbox sync integration
      // In a real scenario, this would connect to IMAP/Exchange
      const syncedCount = Math.floor(Math.random() * 5);
      return { success: true, syncedCount, message: `Synced ${syncedCount} new emails from remote mailbox.` };
    }),
});
