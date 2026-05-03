const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

(async () => {
  const rows = await prisma.notification.findMany({
    where: { type: { in: ['JAP_NEW','JAP_STATUS_CHANGE'] } },
    orderBy: { createdAt: 'desc' },
    take: 10,
    select: { id: true, recipientUserId: true, type: true, title: true, body:true, isRead: true, createdAt: true },
  });

  console.log(JSON.stringify(rows, null, 2));
  await prisma.$disconnect();
})();
