import { Router, Request, Response } from 'express';
import { NotificationType } from '@prisma/client';

// Export a factory so we can use Nest services (NotificationService + PrismaService)
export default function createJapRouter(
  notificationsService: any,
  prismaService: any,
) {
  const router = Router();

  // Helper to convert database model to API response format
  const formatJapEntry = (entry: any) => ({
    id: entry.id,
    jaar: entry.year,
    doelstellingMaatregel: entry.goalMeasure,
    domein: entry.domain?.name,
    risicoveld: entry.riskField,
    prioriteit: entry.priority,
    realisatie: entry.realisation,
    uitvoerder: entry.executor,
    middelenBudgetWerkuren: entry.resourcesBudget,
    startdatum: entry.startDate,
    einddatum: entry.endDate,
    opmerking: entry.remark,
    comments: entry.comments?.map((c: any) => ({
      id: c.id,
      author: c.author,
      text: c.text,
      createdAt: c.createdAt.toISOString(),
    })) ?? [],
  });

  // GET /jap - haal alle entries op
  router.get('/', async (req: Request, res: Response) => {
    try {
      const { search, groupBy } = req.query;

      const where: any = {
        source: 'JAP',
      };

      if (search && typeof search === 'string') {
        const q = search.toLowerCase();
        where.OR = [
          { goalMeasure: { contains: q, mode: 'insensitive' } },
          { domain: { name: { contains: q, mode: 'insensitive' } } },
        ];
      }

      let entries = await prismaService.japGppEntry.findMany({
        where,
        include: {
          domain: true,
          comments: {
            orderBy: { createdAt: 'desc' },
          },
        },
        orderBy: { year: 'desc' },
      });

      const result = entries.map(formatJapEntry);

      if (groupBy === 'year') {
        const groupsMap = new Map<number, any[]>();
        for (const entry of result) {
          const bucket = groupsMap.get(entry.jaar) ?? [];
          bucket.push(entry);
          groupsMap.set(entry.jaar, bucket);
        }
        const groups = Array.from(groupsMap.entries())
          .sort((a, b) => b[0] - a[0])
          .map(([year, entries]) => ({ year, entries }));

        return res.json({ groups });
      }

      res.json({ entries: result });
    } catch (error) {
      console.error('Error fetching JAP entries:', error);
      res.status(500).json({ message: 'Fout bij ophalen JAP entries' });
    }
  });

  // GET /jap/:id/comments
  router.get('/:id/comments', async (req: Request, res: Response) => {
    try {
      const id = Number(req.params.id);
      const entry = await prismaService.japGppEntry.findUnique({
        where: { id },
        include: {
          comments: {
            orderBy: { createdAt: 'desc' },
          },
        },
      });

      if (!entry) {
        return res.status(404).json({ message: 'Entry niet gevonden' });
      }

      const comments = entry.comments.map((c: any) => ({
        id: c.id,
        author: c.author,
        text: c.text,
        createdAt: c.createdAt.toISOString(),
      }));

      res.json({ comments });
    } catch (error) {
      console.error('Error fetching comments:', error);
      res.status(500).json({ message: 'Fout bij ophalen commentaar' });
    }
  });

  // POST /jap/:id/comments
  router.post('/:id/comments', async (req: Request, res: Response) => {
    try {
      const id = Number(req.params.id);
      const { author, text } = req.body;

      if (!text?.trim()) {
        return res.status(400).json({ message: 'Tekst is verplicht' });
      }

      // Check if entry exists
      const entry = await prismaService.japGppEntry.findUnique({
        where: { id },
      });

      if (!entry) {
        return res.status(404).json({ message: 'Entry niet gevonden' });
      }

      // Create comment
      const comment = await prismaService.japComment.create({
        data: {
          entryId: id,
          author: author?.trim() || 'Onbekend',
          text: text.trim(),
        },
      });

      // Notify users
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
            title: 'Nieuwe opmerking op JAP',
            body: text.trim().slice(0, 200),
            metadata: { entryId: id, module: 'JAP' },
          });
        }
      } catch (notifyError) {
        console.warn('Failed to notify users for JAP comment', notifyError);
      }

      res.status(201).json({
        comment: {
          id: comment.id,
          author: comment.author,
          text: comment.text,
          createdAt: comment.createdAt.toISOString(),
        },
      });
    } catch (error) {
      console.error('Error creating comment:', error);
      res.status(500).json({ message: 'Fout bij aanmaken commentaar' });
    }
  });

  // GET /jap/recent-comments
  router.get('/recent-comments', async (req: Request, res: Response) => {
    try {
      const japEntries = await prismaService.japGppEntry.findMany({
        where: {
          source: 'JAP',
          remark: { not: null },
        },
        select: {
          id: true,
          goalMeasure: true,
          executor: true,
          remark: true,
        },
        orderBy: { updatedAt: 'desc' },
      });

      const gppEntries = await prismaService.japGppEntry.findMany({
        where: {
          source: 'GPP',
          remark: { not: null },
        },
        select: {
          id: true,
          goalMeasure: true,
          executor: true,
          remark: true,
        },
        orderBy: { updatedAt: 'desc' },
      });

      const japWithRemarks = japEntries
        .filter((e) => e.remark && e.remark.trim() !== '')
        .map((e) => ({
          id: e.id,
          module: 'JAP' as const,
          title: e.goalMeasure ?? '',
          author: e.executor ?? '',
          comment: e.remark ?? '',
        }));

      const gppWithRemarks = gppEntries
        .filter((e) => e.remark && e.remark.trim() !== '')
        .map((e) => ({
          id: e.id,
          module: 'GPP' as const,
          title: e.goalMeasure ?? '',
          author: e.executor ?? '',
          comment: e.remark ?? '',
        }));

      const combined = [...japWithRemarks, ...gppWithRemarks]
        .sort((a, b) => b.id - a.id)
        .slice(0, 3);

      res.json({ comments: combined });
    } catch (error) {
      console.error('Error fetching recent comments:', error);
      res.status(500).json({ message: 'Fout bij ophalen commentaar' });
    }
  });

  // POST /jap - maak nieuwe entry aan
  router.post('/', async (req: Request, res: Response) => {
    try {
      const {
        doelstellingMaatregel,
        domein,
        risicoveld,
        prioriteit,
        realisatie,
        uitvoerder,
        middelenBudgetWerkuren,
        startdatum,
        einddatum,
        opmerking,
      } = req.body;

      // Find or create domain if provided
      let domainId = null;
      if (domein) {
        const domain = await prismaService.domain.findUnique({
          where: { name: domein },
        });
        domainId = domain?.id ?? null;
      }

      const entry = await prismaService.japGppEntry.create({
        data: {
          source: 'JAP',
          year: new Date().getFullYear(),
          goalMeasure: doelstellingMaatregel,
          domainId,
          riskField: risicoveld,
          priority: prioriteit,
          realisation: realisatie,
          executor: uitvoerder,
          resourcesBudget: middelenBudgetWerkuren,
          startDate: startdatum ? new Date(startdatum) : null,
          endDate: einddatum ? new Date(einddatum) : null,
          remark: opmerking,
        },
        include: {
          domain: true,
          comments: true,
        },
      });

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
            body: `${doelstellingMaatregel ?? 'Nieuwe JAP'}`,
            metadata: { entryId: entry.id, module: 'JAP' },
          });
        }
      } catch (notifyError) {
        console.warn('Failed to notify users for JAP creation', notifyError);
      }

      res.status(201).json({ entry: formatJapEntry(entry) });
    } catch (error) {
      console.error('Error creating JAP entry:', error);
      res.status(500).json({ message: 'Fout bij aanmaken JAP entry' });
    }
  });

  // PATCH /jap/:id - update een entry
  router.patch('/:id', async (req: Request, res: Response) => {
    try {
      const id = Number(req.params.id);

      // Get previous version for comparison
      const previous = await prismaService.japGppEntry.findUnique({
        where: { id },
      });

      if (!previous) {
        return res.status(404).json({ message: 'Entry niet gevonden' });
      }

      const {
        doelstellingMaatregel,
        domein,
        risicoveld,
        prioriteit,
        realisatie,
        uitvoerder,
        middelenBudgetWerkuren,
        startdatum,
        einddatum,
        opmerking,
      } = req.body;

      // Find or create domain if provided
      let domainId = previous.domainId;
      if (domein !== undefined) {
        if (domein) {
          const domain = await prismaService.domain.findUnique({
            where: { name: domein },
          });
          domainId = domain?.id ?? null;
        } else {
          domainId = null;
        }
      }

      const updated = await prismaService.japGppEntry.update({
        where: { id },
        data: {
          goalMeasure: doelstellingMaatregel !== undefined ? doelstellingMaatregel : undefined,
          domainId: domein !== undefined ? domainId : undefined,
          riskField: risicoveld !== undefined ? risicoveld : undefined,
          priority: prioriteit !== undefined ? prioriteit : undefined,
          realisation: realisatie !== undefined ? realisatie : undefined,
          executor: uitvoerder !== undefined ? uitvoerder : undefined,
          resourcesBudget: middelenBudgetWerkuren !== undefined ? middelenBudgetWerkuren : undefined,
          startDate: startdatum !== undefined ? (startdatum ? new Date(startdatum) : null) : undefined,
          endDate: einddatum !== undefined ? (einddatum ? new Date(einddatum) : null) : undefined,
          remark: opmerking !== undefined ? opmerking : undefined,
        },
        include: {
          domain: true,
          comments: true,
        },
      });

      // If a remark was added, notify relevant users
      if (opmerking && opmerking.trim() !== '' && (!previous.remark || previous.remark.trim() === '')) {
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
              body: opmerking.toString().slice(0, 200),
              metadata: { entryId: updated.id, module: 'JAP' },
            });
          }
        } catch (notifyError) {
          console.warn('Failed to notify users for JAP comment', notifyError);
        }
      }

      res.json({ entry: formatJapEntry(updated) });
    } catch (error) {
      console.error('Error updating JAP entry:', error);
      res.status(500).json({ message: 'Fout bij bijwerken JAP entry' });
    }
  });

  // DELETE /jap/:id - verwijder een entry
  router.delete('/:id', async (req: Request, res: Response) => {
    try {
      const id = Number(req.params.id);
      await prismaService.japGppEntry.delete({
        where: { id },
      });
      res.status(204).send();
    } catch (error: any) {
      if (error.code === 'P2025') {
        return res.status(404).json({ message: 'Entry niet gevonden' });
      }
      console.error('Error deleting JAP entry:', error);
      res.status(500).json({ message: 'Fout bij verwijderen JAP entry' });
    }
  });

  return router;
}