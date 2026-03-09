import { z } from "zod";
import { createTRPCRouter, publicProcedure } from "../create-context";
import { EntityTypeEnum, EntityStatusEnum } from "../../db";
import prisma from "../../prisma";

export const entitiesRouter = createTRPCRouter({
  list: publicProcedure.query(async () => {
    return prisma.entity.findMany({
      include: { applications: true },
    });
  }),

  getById: publicProcedure
    .input(z.object({ id: z.string().uuid() }))
    .query(async ({ input }) => {
      const entity = await prisma.entity.findUnique({
        where: { id: input.id },
        include: { applications: true },
      });
      if (!entity) throw new Error("Entity not found");
      return entity;
    }),

  create: publicProcedure
    .input(
      z.object({
        name: z.string().min(1),
        type: EntityTypeEnum,
        creditLimit: z.number().min(0),
        assignedPhone: z.string(),
        assignedEmail: z.string(),
        notes: z.string().optional(),
        dateOfBirth: z.string().optional(),
        address: z.string().optional(),
        idNumber: z.string().optional(),
        dlNumber: z.string().optional(),
        dlCardNumber: z.string().optional(),
        dlExpiry: z.string().optional(),
        medicareNumber: z.string().optional(),
        medicareExpiry: z.string().optional(),
        passportNumber: z.string().optional(),
        passportExpiry: z.string().optional(),
        clearScore: z.number().int().optional(),
        creditNotes: z.string().optional(),
      })
    )
    .mutation(async ({ input }) => {
      const entity = await prisma.entity.create({
        data: {
          name: input.name,
          type: input.type,
          status: "Active",
          healthScore: 75,
          creditLimit: input.creditLimit,
          utilisationPercent: 0,
          monthlyBurn: 25,
          assignedPhone: input.assignedPhone,
          assignedEmail: input.assignedEmail,
          clearScore: input.clearScore ?? 750,
          lastActivityDate: new Date(),
          isFlagged: false,
          notes: input.notes ?? "",
          dateOfBirth: input.dateOfBirth ?? "",
          address: input.address ?? "",
          idNumber: input.idNumber ?? "",
          dlNumber: input.dlNumber,
          dlCardNumber: input.dlCardNumber,
          dlExpiry: input.dlExpiry,
          medicareNumber: input.medicareNumber,
          medicareExpiry: input.medicareExpiry,
          passportNumber: input.passportNumber,
          passportExpiry: input.passportExpiry,
          creditNotes: input.creditNotes,
        },
        include: { applications: true },
      });
      return entity;
    }),

  update: publicProcedure
    .input(
      z.object({
        id: z.string().uuid(),
        name: z.string().optional(),
        type: EntityTypeEnum.optional(),
        status: EntityStatusEnum.optional(),
        healthScore: z.number().int().min(0).max(100).optional(),
        creditLimit: z.number().optional(),
        utilisationPercent: z.number().optional(),
        monthlyBurn: z.number().optional(),
        assignedPhone: z.string().optional(),
        assignedEmail: z.string().optional(),
        clearScore: z.number().int().optional(),
        isFlagged: z.boolean().optional(),
        notes: z.string().optional(),
        dateOfBirth: z.string().optional(),
        address: z.string().optional(),
        idNumber: z.string().optional(),
        dlNumber: z.string().optional(),
        dlCardNumber: z.string().optional(),
        dlExpiry: z.string().optional(),
        medicareNumber: z.string().optional(),
        medicareExpiry: z.string().optional(),
        passportNumber: z.string().optional(),
        passportExpiry: z.string().optional(),
        creditNotes: z.string().optional(),
      })
    )
    .mutation(async ({ input }) => {
      const { id, ...updates } = input;
      const filtered = Object.fromEntries(
        Object.entries(updates).filter(([_, v]) => v !== undefined)
      );
      
      const entity = await prisma.entity.update({
        where: { id },
        data: { ...filtered, lastActivityDate: new Date() },
        include: { applications: true },
      });
      return entity;
    }),

  archive: publicProcedure
    .input(z.object({ id: z.string().uuid() }))
    .mutation(async ({ input }) => {
      const entity = await prisma.entity.update({
        where: { id: input.id },
        data: { status: "Archived" },
        include: { applications: true },
      });
      return entity;
    }),

  toggleFlag: publicProcedure
    .input(z.object({ id: z.string().uuid() }))
    .mutation(async ({ input }) => {
      const current = await prisma.entity.findUnique({ where: { id: input.id } });
      if (!current) throw new Error("Entity not found");
      
      const entity = await prisma.entity.update({
        where: { id: input.id },
        data: { isFlagged: !current.isFlagged },
        include: { applications: true },
      });
      return entity;
    }),

  dashboard: publicProcedure.query(async () => {
    const activeEntities = await prisma.entity.findMany({
      where: { status: { not: "Archived" } },
      include: { applications: true },
    });
    const allEntitiesCount = await prisma.entity.count();
    
    const activeStatuses = new Set(["Submitted", "In Review", "Docs Needed", "Stalled"]);

    const totalFirepower = activeEntities.reduce(
      (sum, e) => sum + e.creditLimit * (1 - e.utilisationPercent / 100),
      0
    );
    const monthlyBurn = activeEntities.reduce((sum, e) => sum + e.monthlyBurn, 0);
    
    const urgentAlertsCount = await prisma.nexusAlert.count({
      where: { isRead: false, priority: "Critical" }
    });

    const applicationRows = activeEntities.flatMap((subject) =>
      subject.applications.map((application) => ({ subject, application }))
    );
    const currentApplicationsTotal = applicationRows.filter(({ application }) =>
      activeStatuses.has(application.status)
    ).length;

    const longestActive = applicationRows
      .filter(({ application }) => activeStatuses.has(application.status))
      .sort(
        (a, b) =>
          new Date(a.application.submittedDate).getTime() -
          new Date(b.application.submittedDate).getTime()
      )[0];

    const unreadComms = await prisma.communication.count({ where: { isRead: false } });
    const unreadEmails = await prisma.email.count({ where: { isRead: false } });

    return {
      totalFirepower,
      monthlyBurn,
      activeCount: activeEntities.filter((e) => e.status === "Active").length,
      totalCount: allEntitiesCount,
      urgentCount: urgentAlertsCount,
      unreadComms,
      unreadEmails,
      currentApplicationsTotal,
      longestActive: longestActive
        ? {
            subjectId: longestActive.subject.id,
            subjectName: longestActive.subject.name,
            bank: longestActive.application.bank,
            submittedDate: longestActive.application.submittedDate.toISOString(),
          }
        : null,
    };
  }),
});
