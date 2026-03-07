import { z } from "zod";
import { createTRPCRouter, publicProcedure } from "../create-context";
import { db, EntityTypeEnum, EntityStatusEnum } from "../../db";

export const entitiesRouter = createTRPCRouter({
  list: publicProcedure.query(() => {
    return db.entities;
  }),

  getById: publicProcedure
    .input(z.object({ id: z.string().uuid() }))
    .query(({ input }) => {
      const entity = db.entities.find((e) => e.id === input.id);
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
      })
    )
    .mutation(({ input }) => {
      const entity = {
        id: crypto.randomUUID(),
        name: input.name,
        type: input.type,
        status: "Active" as const,
        healthScore: 75,
        creditLimit: input.creditLimit,
        utilisationPercent: 0,
        monthlyBurn: 25,
        assignedPhone: input.assignedPhone,
        assignedEmail: input.assignedEmail,
        clearScore: 750,
        lastActivityDate: new Date().toISOString(),
        isFlagged: false,
        notes: input.notes ?? "",
        createdDate: new Date().toISOString(),
        dateOfBirth: "",
        address: "",
        idNumber: "",
        applications: [],
      };
      db.entities.push(entity);
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
      })
    )
    .mutation(({ input }) => {
      const idx = db.entities.findIndex((e) => e.id === input.id);
      if (idx === -1) throw new Error("Entity not found");
      const { id, ...updates } = input;
      const filtered = Object.fromEntries(
        Object.entries(updates).filter(([_, v]) => v !== undefined)
      );
      db.entities[idx] = { ...db.entities[idx]!, ...filtered, lastActivityDate: new Date().toISOString() };
      return db.entities[idx]!;
    }),

  archive: publicProcedure
    .input(z.object({ id: z.string().uuid() }))
    .mutation(({ input }) => {
      const idx = db.entities.findIndex((e) => e.id === input.id);
      if (idx === -1) throw new Error("Entity not found");
      db.entities[idx]!.status = "Archived";
      return db.entities[idx]!;
    }),

  toggleFlag: publicProcedure
    .input(z.object({ id: z.string().uuid() }))
    .mutation(({ input }) => {
      const idx = db.entities.findIndex((e) => e.id === input.id);
      if (idx === -1) throw new Error("Entity not found");
      db.entities[idx]!.isFlagged = !db.entities[idx]!.isFlagged;
      return db.entities[idx]!;
    }),

  dashboard: publicProcedure.query(() => {
    const active = db.entities.filter((e) => e.status !== "Archived");
    const activeStatuses = new Set(["Submitted", "In Review", "Docs Needed", "Stalled"]);

    const totalFirepower = active.reduce(
      (sum, e) => sum + e.creditLimit * (1 - e.utilisationPercent / 100),
      0
    );
    const monthlyBurn = active.reduce((sum, e) => sum + e.monthlyBurn, 0);
    const urgentAlerts = db.alerts.filter(
      (a) => !a.isRead && a.priority === "Critical"
    );

    const applicationRows = active.flatMap((subject) =>
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

    return {
      totalFirepower,
      monthlyBurn,
      activeCount: active.filter((e) => e.status === "Active").length,
      totalCount: db.entities.length,
      urgentCount: urgentAlerts.length,
      unreadComms: db.communications.filter((c) => !c.isRead).length,
      unreadEmails: db.emails.filter((e) => !e.isRead).length,
      currentApplicationsTotal,
      longestActive: longestActive
        ? {
            subjectId: longestActive.subject.id,
            subjectName: longestActive.subject.name,
            bank: longestActive.application.bank,
            submittedDate: longestActive.application.submittedDate,
          }
        : null,
    };
  }),
});
