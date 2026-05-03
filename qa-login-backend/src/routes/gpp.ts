import { Router, Request, Response } from 'express';
import { NotificationType } from '@prisma/client';

export default function createGppRouter(
  notificationsService: any,
  prismaService: any,
) {
  const router = Router();

  let gppEntries: any[] = [];

  router.get('/', (req: Request, res: Response) => {
    const { search } = req.query;
    let result = gppEntries;

    if (search && typeof search === 'string') {
      const q = search.toLowerCase();
      result = gppEntries.filter(
        (e) =>
          e.doelstellingMaatregel?.toLowerCase().includes(q) ||
          e.domein?.toLowerCase().includes(q),
      );
    }

    res.json({ entries: result });
  });

  router.post('/', async (req: Request, res: Response) => {
    const entry = {
      id: Date.now(),
      startJaar: new Date().getFullYear(),
      eindJaar: new Date().getFullYear() + 5,
      ...req.body,
    };
    gppEntries.push(entry);

    // Notify relevant users: admins + users with japGppAccess
    try {
      const users = await prismaService.user.findMany({
        where: { OR: [{ isAdmin: true }, { japGppAccess: true }] },
        select: { id: true },
      });
      const recipientIds = users.map((u: any) => u.id);
      if (recipientIds.length > 0) {
        await notificationsService.notifyUsers({
          recipientUserIds: recipientIds,
          type: NotificationType.JAP_NEW,
          title: `Nieuwe GPP entry toegevoegd`,
          body: `${entry.doelstellingMaatregel ?? 'Nieuwe GPP'}`,
          metadata: { entryId: entry.id, module: 'GPP' },
        });
      }
    } catch (err) {
      // eslint-disable-next-line no-console
      console.warn('Failed to notify users for GPP creation', err);
    }

    res.status(201).json({ entry });
  });

  router.patch('/:id', async (req: Request, res: Response) => {
    const id = parseInt(req.params.id);
    const index = gppEntries.findIndex((e) => e.id === id);
    if (index === -1) return res.status(404).json({ message: 'Entry niet gevonden' });
    const previous = { ...gppEntries[index] };
    gppEntries[index] = { ...gppEntries[index], ...req.body };
    const updated = gppEntries[index];

    // If a remark/comment was added, notify relevant users
    if (req.body && typeof req.body.opmerking === 'string' && req.body.opmerking.trim() !== '') {
      try {
        const users = await prismaService.user.findMany({
          where: { OR: [{ isAdmin: true }, { japGppAccess: true }] },
          select: { id: true },
        });
        const recipientIds = users.map((u: any) => u.id);
        if (recipientIds.length > 0) {
          await notificationsService.notifyUsers({
            recipientUserIds: recipientIds,
            type: NotificationType.JAP_COMMENT,
            title: `Nieuwe opmerking op GPP`,
            body: req.body.opmerking.toString().slice(0, 200),
            metadata: { entryId: updated.id, module: 'GPP' },
          });
        }
      } catch (err) {
        // eslint-disable-next-line no-console
        console.warn('Failed to notify users for GPP comment', err);
      }
    }

    try {
      const prevStatus = (previous.status ?? '').toString();
      const nextStatus = (updated.status ?? '').toString();
      if (prevStatus !== nextStatus) {
        const users = await prismaService.user.findMany({
          where: { OR: [{ isAdmin: true }, { japGppAccess: true }] },
          select: { id: true },
        });
        const recipientIds = users.map((u: any) => u.id);
        if (recipientIds.length > 0) {
          await notificationsService.notifyUsers({
            recipientUserIds: recipientIds,
            type: NotificationType.JAP_STATUS_CHANGE,
            title: `GPP status gewijzigd`,
            body: `Status veranderde van ${prevStatus} naar ${nextStatus}`,
            metadata: { entryId: updated.id, previousStatus: prevStatus, nextStatus, module: 'GPP' },
          });
        }
      }
    } catch (err) {
      // eslint-disable-next-line no-console
      console.warn('Failed to notify users for GPP status change', err);
    }

    res.json({ entry: gppEntries[index] });
  });

  router.delete('/:id', (req: Request, res: Response) => {
    const id = parseInt(req.params.id);
    gppEntries = gppEntries.filter((e) => e.id !== id);
    res.status(204).send();
  });

  return router;
}