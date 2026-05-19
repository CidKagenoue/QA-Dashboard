require('dotenv/config');

const { Pool } = require('pg');
const { PrismaPg } = require('@prisma/adapter-pg');
const { PrismaClient } = require('@prisma/client');

const databaseUrl = process.env.DATABASE_URL;

if (!databaseUrl) {
  throw new Error('DATABASE_URL is required');
}

const pool = new Pool({ connectionString: databaseUrl });
const prisma = new PrismaClient({ adapter: new PrismaPg(pool) });

(async () => {
  const rows = await prisma.notification.findMany({
    where: { type: { in: ['JAP_NEW','JAP_STATUS_CHANGE'] } },
    orderBy: { createdAt: 'desc' },
    take: 10,
    select: { id: true, recipientUserId: true, type: true, title: true, body:true, isRead: true, createdAt: true },
  });

  console.log(JSON.stringify(rows, null, 2));
  await prisma.$disconnect();
  await pool.end();
})();
