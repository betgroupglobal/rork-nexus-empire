import { z } from "zod";
import { createTRPCRouter, publicProcedure } from "../create-context";
import { CommTypeEnum } from "../../db";
import prisma from "../../prisma";

export const communicationsRouter = createTRPCRouter({
  list: publicProcedure
    .input(
      z.object({
        entityId: z.string().uuid().optional(),
        subjectId: z.string().uuid().optional(),
        type: CommTypeEnum.optional(),
      }).optional()
    )
    .query(async ({ input }) => {
      const scopedId = input?.subjectId ?? input?.entityId;
      return prisma.communication.findMany({
        where: {
          ...(scopedId ? { entityId: scopedId } : {}),
          ...(input?.type ? { type: input.type } : {}),
        },
        orderBy: { timestamp: "desc" },
      });
    }),

  markRead: publicProcedure
    .input(z.object({ id: z.string().uuid() }))
    .mutation(async ({ input }) => {
      return prisma.communication.update({
        where: { id: input.id },
        data: { isRead: true },
      });
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
    .mutation(async ({ input }) => {
      const linkedId = input.subjectId ?? input.entityId;
      const linkedName = input.subjectName ?? input.entityName;
      if (!linkedId || !linkedName) {
        throw new Error("subjectId/entityId and subjectName/entityName are required");
      }

      return prisma.communication.create({
        data: {
          entityId: linkedId,
          entityName: linkedName,
          type: input.type,
          sender: input.sender,
          content: input.content,
          phoneNumber: input.phoneNumber,
          timestamp: new Date(),
          isRead: false,
          duration: input.duration ?? null,
          transcription: input.transcription ?? null,
        }
      });
    }),
});