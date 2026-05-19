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

  // GET /jap/generated/:year - genereer JAP entries on-the-fly vanuit GPP rows voor export/print
  router.get('/generated/:year', async (req: Request, res: Response) => {
    try {
      const year = Number(req.params.year);
      if (!Number.isInteger(year) || year < 1900 || year > 3000) {
        return res.status(400).json({ message: 'Ongeldig jaar' });
      }

      // Find GPP entries that cover this year
      const gppEntries = await prismaService.japGppEntry.findMany({
        where: {
          source: 'GPP',
          startYear: { lte: year },
          endYear: { gte: year },
        },
        include: { domain: true, comments: true },
        orderBy: [{ startYear: 'desc' }, { id: 'desc' }],
      });

      // Map GPP -> JAP-like structure for the given year
      const generated = gppEntries.map((e: any) => ({
        id: -e.id, // negative id to indicate generated
        jaar: year,
        doelstellingMaatregel: e.goalMeasure,
        domein: e.domain?.name,
        risicoveld: e.riskField,
        prioriteit: e.priority,
        realisatie: e.realisation,
        uitvoerder: e.executor,
        middelenBudgetWerkuren: e.resourcesBudget,
        startdatum: e.startDate,
        einddatum: e.endDate,
        opmerking: e.remark,
        comments: e.comments?.map((c: any) => ({ id: c.id, author: c.author, text: c.text, createdAt: c.createdAt.toISOString() })) ?? [],
      }));

      res.json({ entries: generated });
    } catch (error) {
      console.error('Error generating JAP entries for year:', error);
      res.status(500).json({ message: 'Fout bij genereren JAP entries' });
    }
  });

  // GET /jap/:id/comments
  // Comments for JAP entries are handled via GPP routes; no DB-backed JAP comments endpoint here.

  // Comment creation for GPP is available via `/gpp/:id/comments`.

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

  // Creating DB-backed JAP entries is disabled; use GPP and the generated endpoints instead.

  // Updating DB-backed JAP entries is disabled.

  // Deleting DB-backed JAP entries is disabled via this route.

  return router;
}