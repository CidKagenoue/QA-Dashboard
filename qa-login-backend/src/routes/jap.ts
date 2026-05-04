import { Router, Request, Response } from 'express';
import { NotificationType } from '@prisma/client';

// Export a factory so we can use Nest services (NotificationService + PrismaService)
export default function createJapRouter(
  notificationsService: any,
  prismaService: any,
) {
  const router = Router();

  // Tijdelijke in-memory opslag (later vervangen door database)
  let japEntries: any[] = [];

  // GET /jap - haal alle entries op
  router.get('/', (req: Request, res: Response) => {
    const { search } = req.query;

    let result = japEntries;

    if (search && typeof search === 'string') {
      const q = search.toLowerCase();
      result = japEntries.filter(
        (e) =>
          e.doelstellingMaatregel?.toLowerCase().includes(q) ||
          e.domein?.toLowerCase().includes(q),
      );
    }

    res.json({ entries: result });
  });

  // POST /jap - maak nieuwe entry aan
  router.post('/', async (req: Request, res: Response) => {
    const entry = {
      jaar: new Date().getFullYear(),
      ...req.body,
      id: Date.now(),
    };
    japEntries.push(entry);

    // Notify relevant users: admins + users with japGppAccess
    try {
      const users = await prismaService.user.findMany({
        where: {
          OR: [{ isAdmin: true }, { japGppAccess: true }],
        },
        select: { id: true },
      });
      const recipientIds = users.map((u: any) => u.id);
      if (recipientIds.length > 0) {
        await notificationsService.notifyUsers({
          recipientUserIds: recipientIds,
          type: NotificationType.JAP_NEW,
          title: `Nieuwe JAP entry toegevoegd`,
          body: `${entry.doelstellingMaatregel ?? 'Nieuwe JAP'}`,
          metadata: { entryId: entry.id, module: 'JAP' },
        });
      }
    } catch (err) {
      // log but do not fail creation
      // eslint-disable-next-line no-console
      console.warn('Failed to notify users for JAP creation', err);
    }

    res.status(201).json({ entry });
  });

  // PATCH /jap/:id - update een entry
  router.patch('/:id', async (req: Request, res: Response) => {
    const id = Number(req.params.id);
    const index = japEntries.findIndex((e) => e.id === id);

    if (index === -1) {
      return res.status(404).json({ message: 'Entry niet gevonden' });
    }

    const previous = { ...japEntries[index] };
    japEntries[index] = { ...japEntries[index], ...req.body };
    const updated = japEntries[index];

    // If a remark/comment was added, notify relevant users
    if (req.body && typeof req.body.opmerking === 'string' && req.body.opmerking.trim() !== '') {
      try {
        const users = await prismaService.user.findMany({
          where: {
            OR: [{ isAdmin: true }, { japGppAccess: true }],
          },
          select: { id: true },
        });
        const recipientIds = users.map((u: any) => u.id);
        if (recipientIds.length > 0) {
          await notificationsService.notifyUsers({
            recipientUserIds: recipientIds,
            type: NotificationType.JAP_COMMENT,
            title: `Nieuwe opmerking op JAP`,
            body: req.body.opmerking.toString().slice(0, 200),
            metadata: { entryId: updated.id, module: 'JAP' },
          });
        }
      } catch (err) {
        // eslint-disable-next-line no-console
        console.warn('Failed to notify users for JAP comment', err);
      }
    }

    // If status changed, notify relevant users
    try {
      const prevStatus = (previous.status ?? '').toString();
      const nextStatus = (updated.status ?? '').toString();
      if (prevStatus !== nextStatus) {
        const users = await prismaService.user.findMany({
          where: {
            OR: [{ isAdmin: true }, { japGppAccess: true }],
          },
          select: { id: true },
        });
        const recipientIds = users.map((u: any) => u.id);
        if (recipientIds.length > 0) {
          await notificationsService.notifyUsers({
            recipientUserIds: recipientIds,
            type: NotificationType.JAP_STATUS_CHANGE,
            title: `JAP status gewijzigd`,
            body: `Status veranderde van ${prevStatus} naar ${nextStatus}`,
            metadata: { entryId: updated.id, previousStatus: prevStatus, nextStatus, module: 'JAP' },
          });
        }
      }
    } catch (err) {
      // eslint-disable-next-line no-console
      console.warn('Failed to notify users for JAP status change', err);
    }

    res.json({ entry: japEntries[index] });
  });

  // DELETE /jap/:id - verwijder een entry
  router.delete('/:id', (req: Request, res: Response) => {
    const id = Number(req.params.id);
    japEntries = japEntries.filter((e) => e.id !== id);
    res.status(204).send();
  });

  return router;
}