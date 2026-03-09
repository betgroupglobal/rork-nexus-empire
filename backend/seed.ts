import prisma from "./prisma";
import { db } from "./db";

async function main() {
  console.log("Starting seed...");
  await prisma.entity.deleteMany();
  await prisma.communication.deleteMany();
  await prisma.email.deleteMany();
  await prisma.nexusAlert.deleteMany();

  for (const e of db.entities) {
    const { applications, ...entityData } = e;
    const { id, ...data } = entityData;
    
    await prisma.entity.create({
      data: {
        id,
        ...data,
        applications: {
          create: applications.map(app => ({
            id: app.id,
            bank: app.bank,
            product: app.product,
            status: app.status,
            progressPercent: app.progressPercent,
            submittedDate: app.submittedDate,
            lastUpdateDate: app.lastUpdateDate,
            nextAction: app.nextAction,
            documents: app.documents
          }))
        }
      }
    });
  }

  for (const c of db.communications) {
    await prisma.communication.create({ data: c });
  }

  for (const e of db.emails) {
    await prisma.email.create({ data: e });
  }

  for (const a of db.alerts) {
    await prisma.nexusAlert.create({ data: a });
  }

  console.log("Seed complete");
}

main()
  .then(async () => {
    await prisma.$disconnect();
  })
  .catch(async (e) => {
    console.error(e);
    await prisma.$disconnect();
    process.exit(1);
  });
