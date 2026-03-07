import { z } from "zod";
import { createTRPCRouter, publicProcedure } from "../create-context";
import { db, CommTypeEnum } from "../../db";

export const communicationsRouter = createTRPCRouter({
  list: publicProcedure
    .input(
      z.object({
        entityId: z.string().uuid().optional(),
        subjectId: z.string().uuid().optional(),
        type: CommTypeEnum.optional(),
      }).optional()
    )
    .query(({ input }) => {
      let comms = db.communications;
      const scopedId = input?.subjectId ?? input?.entityId;
      if (scopedId) {
        comms = comms.filter((c) => c.entityId === scopedId);
      }
      if (input?.type) {
        comms = comms.filter((c) => c.type === input.type);
      }
      return comms.sort(
        (a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime()
      );
    }),

  markRead: publicProcedure
    .input(z.object({ id: z.string().uuid() }))
    .mutation(({ input }) => {
      const idx = db.communications.findIndex((c) => c.id === input.id);
      if (idx === -1) throw new Error("Communication not found");
      db.communications[idx]!.isRead = true;
      return db.communications[idx]!;
    }),

  create: publicProcedure
    .input(
      z.object({
        entityId: z.string().uuid().optional(),
        subjectId: z.string().uuid().optional(),
        entityName: z.string().optional(),
        subjectName: z.string().optional(),
        type: CommTypeEnum,
        sender: z.string(),
        content: z.string(),
        phoneNumber: z.string(),
        duration: z.number().nullable().optional(),
        transcription: z.string().nullable().optional(),
      })
    )
    .mutation(({ input }) => {
      const linkedId = input.subjectId ?? input.entityId;
      const linkedName = input.subjectName ?? input.entityName;
      if (!linkedId || !linkedName) {
        throw new Error("subjectId/entityId and subjectName/entityName are required");
      }

      const comm = {
        id: crypto.randomUUID(),
        entityId: linkedId,
        entityName: linkedName,
        type: input.type,
        sender: input.sender,
        content: input.content,
        phoneNumber: input.phoneNumber,
        timestamp: new Date().toISOString(),
        isRead: false,
        duration: input.duration ?? null,
        transcription: input.transcription ?? null,
      };
      db.communications.push(comm);
      return comm;
    }),
});
