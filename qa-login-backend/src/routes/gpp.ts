import { Router, Request, Response } from 'express';
import { NotificationType } from '@prisma/client';
import * as multer from 'multer';
import * as XLSX from 'xlsx';

const upload = multer({ storage: multer.memoryStorage() });

const NORMALISED_HEADER_ALIASES: Record<string, string[]> = {
  jaar: ['jaar'],
  doelstellingMaatregel: ['doelstellingmaatregel', 'doelstelling-maatregel', 'doelstelling'],
  domein: ['domein', 'e'],
  risicoveld: ['risicoveld'],
  prioriteit: ['prioriteit', 'prioriteittijdsplanning'],
  uitvoerder: ['uitvoerder'],
  middelenBudgetWerkuren: ['middelenbudgetofwerkuren', 'middelenbudgetwerkuren', 'middelen'],
  startdatum: ['startdatum'],
  realisatie: ['realisatie'],
  einddatum: ['einddatum'],
  opmerking: ['opmerkingen', 'opmerking'],
};

function normaliseHeader(value: unknown): string {
  return String(value ?? '')
    .toLowerCase()
    .replace(/\s+/g, '')
    .replace(/[\-_/]/g, '')
    .replace(/[^a-z0-9]/g, '');
}

function findHeaderRow(rows: unknown[][]): number {
  for (let i = 0; i < rows.length; i += 1) {
    const row = rows[i] ?? [];
    const joined = row.map(normaliseHeader).join('|');
    if (joined.includes('doelstelling') && joined.includes('risicoveld')) {
      return i;
    }
  }
  return -1;
}

function findColumnIndexes(headerRow: unknown[]): Record<string, number> {
  const indexes: Record<string, number> = {};
  headerRow.forEach((cell, idx) => {
    const key = normaliseHeader(cell);
    for (const [target, aliases] of Object.entries(NORMALISED_HEADER_ALIASES)) {
      const matches = aliases.some((alias) => (
        alias.length === 1 ? key === alias : key.includes(alias)
      ));
      if (matches && indexes[target] == null) {
        indexes[target] = idx;
      }
    }
  });
  return indexes;
}

function pickDelimiter(text: string): string {
  const sample = text.split(/\r?\n/).slice(0, 8).join('\n');
  const candidates = ['\t', ';', ','];
  return candidates
    .map((delimiter) => ({
      delimiter,
      count: sample.split(delimiter).length - 1,
    }))
    .sort((a, b) => b.count - a.count)[0]?.delimiter ?? '\t';
}

function parseDelimitedRows(text: string): string[][] {
  const delimiter = pickDelimiter(text);
  const rows: string[][] = [];
  let row: string[] = [];
  let cell = '';
  let inQuotes = false;

  for (let i = 0; i < text.length; i += 1) {
    const char = text[i];
    const next = text[i + 1];

    if (char === '"') {
      if (inQuotes && next === '"') {
        cell += '"';
        i += 1;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }

    if (!inQuotes && char === delimiter) {
      row.push(cell);
      cell = '';
      continue;
    }

    if (!inQuotes && (char === '\n' || char === '\r')) {
      row.push(cell);
      rows.push(row);
      row = [];
      cell = '';
      if (char === '\r' && next === '\n') i += 1;
      continue;
    }

    cell += char;
  }

  row.push(cell);
  if (row.some((value) => value.trim() !== '')) rows.push(row);
  return rows;
}

function readImportRows(file: any): { rows: unknown[][]; sourceName: string } {
  const fileName = file.originalname || 'GPP import';
  const lowerName = fileName.toLowerCase();

  if (lowerName.endsWith('.xlsx') || lowerName.endsWith('.xls')) {
    const workbook = XLSX.read(file.buffer, { type: 'buffer', cellDates: true });
    const gppSheetName = workbook.SheetNames.find((name) => name.toLowerCase().includes('gpp'));

    if (!gppSheetName) {
      throw new Error('Geen GPP sheet gevonden in het Excel bestand.');
    }

    const sheet = workbook.Sheets[gppSheetName];
    return {
      rows: XLSX.utils.sheet_to_json(sheet, { header: 1, defval: '', raw: true }) as unknown[][],
      sourceName: gppSheetName,
    };
  }

  return {
    rows: parseDelimitedRows(file.buffer.toString('utf8')),
    sourceName: fileName,
  };
}

function readCell(row: unknown[], idx: number | undefined): string {
  if (idx == null) return '';
  return String(row[idx] ?? '').trim();
}

function parseExcelDate(value: unknown): string {
  if (value == null || value === '') return '';
  if (typeof value === 'number' && Number.isFinite(value)) {
    const date = XLSX.SSF.parse_date_code(value);
    if (!date) return '';
    const day = String(date.d).padStart(2, '0');
    const month = String(date.m).padStart(2, '0');
    const year = String(date.y).padStart(4, '0');
    return `${day}.${month}.${year}`;
  }
  const text = String(value).trim();
  if (/^\d{1,2}[./-]\d{1,2}[./-]\d{4}$/.test(text)) {
    return text.replace(/\//g, '.').replace(/-/g, '.');
  }
  return text;
}

function coerceDateForYear(value: unknown, year: number, fallback: string): string {
  const parsed = parseExcelDate(value);
  const normalized = parsed.replace(/\//g, '.').replace(/-/g, '.');
  const match = normalized.match(/^(\d{1,2})\.(\d{1,2})\.(\d{4})$/);
  if (!match) return fallback;

  const parsedYear = Number(match[3]);
  if (parsedYear < 1900 || parsedYear > 2100) return fallback;

  const day = match[1].padStart(2, '0');
  const month = match[2].padStart(2, '0');
  return `${day}.${month}.${year}`;
}

function parseYearRangeFromText(text: string): [number, number] | null {
  const match = text.match(/(20\d{2})\s*[-–]\s*(20\d{2})/);
  if (match) {
    return [Number(match[1]), Number(match[2])];
  }

  const singleYear = text.match(/^(20\d{2})$/);
  if (singleYear) {
    const year = Number(singleYear[1]);
    return [year, year];
  }

  return null;
}

function parsePriority(value: string): string {
  const text = value.toLowerCase();
  if (text.includes('hoog') || text.startsWith('a')) return 'hoog';
  if (text.includes('middel') || text.startsWith('b')) return 'middel';
  return 'laag';
}

function parseRealisatie(value: string): string {
  const text = value.toLowerCase();
  if (text.includes('nog') && text.includes('niet')) return 'neg_niet_uitgevoerd';
  if (text.includes('uitgevoerd') && !text.includes('niet')) return 'uitgevoerd';
  if (text.includes('uitvoering')) return 'in_uitvoering';
  return 'vul_aan';
}

function buildDateForYear(base: string, year: number, fallback: string): string {
  const normalized = base.replace(/\//g, '.').replace(/-/g, '.');
  const match = normalized.match(/^(\d{1,2})\.(\d{1,2})\.(\d{4})$/);
  if (!match) return fallback;
  const day = match[1].padStart(2, '0');
  const month = match[2].padStart(2, '0');
  return `${day}.${month}.${year}`;
}

function normaliseYearRange(startYear: number, endYear: number): [number, number] {
  if (startYear <= endYear) return [startYear, endYear];
  return [endYear, startYear];
}

function formatGppEntry(entry: any) {
  return {
    id: entry.id,
    startJaar: entry.startYear,
    eindJaar: entry.endYear,
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
  };
}

export default function createGppRouter(
  notificationsService: any,
  prismaService: any,
) {
  const router = Router();

  // Helper to sync generated JAP entries for a GPP entry
  const syncGeneratedJapEntriesForGpp = async (gpp: any) => {
    const [startYear, endYear] = normaliseYearRange(gpp.startYear, gpp.endYear);
    const expectedYears = new Set<number>();
    for (let year = startYear; year <= endYear; year += 1) {
      expectedYears.add(year);
    }

    // Delete JAP entries that are no longer in the expected range
    await prismaService.japGppEntry.deleteMany({
      where: {
        AND: [
          { generatedFromGppId: gpp.id },
          { year: { notIn: Array.from(expectedYears) } },
        ],
      },
    });

    // Create or update JAP entries for each year
    for (const year of expectedYears) {
      const existing = await prismaService.japGppEntry.findFirst({
        where: {
          generatedFromGppId: gpp.id,
          year,
        },
      });

      if (existing) {
        // Update existing
        await prismaService.japGppEntry.update({
          where: { id: existing.id },
          data: {
            goalMeasure: gpp.goalMeasure,
            domainId: gpp.domainId,
            riskField: gpp.riskField,
            priority: gpp.priority,
            realisation: gpp.realisation,
            executor: gpp.executor,
            resourcesBudget: gpp.resourcesBudget,
            startDate: gpp.startDate,
            endDate: gpp.endDate,
            remark: gpp.remark,
          },
        });
      } else {
        // Create new
        await prismaService.japGppEntry.create({
          data: {
            source: 'JAP',
            year,
            goalMeasure: gpp.goalMeasure,
            domainId: gpp.domainId,
            riskField: gpp.riskField,
            priority: gpp.priority,
            realisation: gpp.realisation,
            executor: gpp.executor,
            resourcesBudget: gpp.resourcesBudget,
            startDate: gpp.startDate,
            endDate: gpp.endDate,
            remark: gpp.remark,
            generatedFromGppId: gpp.id,
          },
        });
      }
    }
  };

  router.post('/import-excel', upload.single('file'), async (req: Request, res: Response) => {
    try {
      const file = (req as any).file;
      if (!file?.buffer) {
        return res.status(400).json({ message: 'Importbestand ontbreekt (field: file)' });
      }

      const shouldClear = String(req.query.clearExisting ?? 'true').toLowerCase() !== 'false';
      if (shouldClear) {
        // Delete generated JAP entries
        await prismaService.japGppEntry.deleteMany({
          where: {
            generatedFromGppId: { not: null },
          },
        });
        // Delete GPP entries
        await prismaService.japGppEntry.deleteMany({
          where: { source: 'GPP' },
        });
      }

      const { rows, sourceName } = readImportRows(file);
      const headerIndex = findHeaderRow(rows);

      if (headerIndex < 0) {
        return res.status(400).json({ message: 'Kon geen geldige header rij vinden in het GPP bestand.' });
      }

      const indexes = findColumnIndexes(rows[headerIndex]);
      const dataRows = rows.slice(headerIndex + 1).filter((row) => (row ?? []).some((cell) => String(cell ?? '').trim() !== ''));

      let importedGppCount = 0;
      let generatedJapCount = 0;

      for (const row of dataRows) {
        const doelstelling = readCell(row, indexes.doelstellingMaatregel);
        if (!doelstelling) continue;

        const jaarText = readCell(row, indexes.jaar);
        const range = parseYearRangeFromText(jaarText);
        const startFromDate = parseExcelDate(row[indexes.startdatum]);
        const endFromDate = parseExcelDate(row[indexes.einddatum]);
        const parsedStartYear = Number(startFromDate.slice(-4));
        const parsedEndYear = Number(endFromDate.slice(-4));
        const startYear = range?.[0] ?? (parsedStartYear || new Date().getFullYear());
        const endYear = range?.[1] ?? (parsedEndYear || startYear);
        const [normalizedStart, normalizedEnd] = normaliseYearRange(startYear, endYear);

        // Find or create domain
        let domainId = null;
        const domeinName = readCell(row, indexes.domein);
        if (domeinName && domeinName !== 'Vul aan') {
          let domain = await prismaService.domain.findUnique({
            where: { name: domeinName },
          });
          if (!domain) {
            domain = await prismaService.domain.create({
              data: { name: domeinName },
            });
          }
          domainId = domain.id;
        }

        // Create GPP entry
        const gppEntry = await prismaService.japGppEntry.create({
          data: {
            source: 'GPP',
            startYear: normalizedStart,
            endYear: normalizedEnd,
            goalMeasure: doelstelling,
            domainId,
            riskField: readCell(row, indexes.risicoveld) || 'Algemeen',
            priority: parsePriority(readCell(row, indexes.prioriteit)),
            realisation: parseRealisatie(readCell(row, indexes.realisatie)),
            executor: readCell(row, indexes.uitvoerder),
            resourcesBudget: readCell(row, indexes.middelenBudgetWerkuren),
            startDate: startFromDate ? new Date(startFromDate.replace(/(\d{2})\.(\d{2})\.(\d{4})/, '$3-$2-$1')) : null,
            endDate: endFromDate ? new Date(endFromDate.replace(/(\d{2})\.(\d{2})\.(\d{4})/, '$3-$2-$1')) : null,
            remark: readCell(row, indexes.opmerking),
          },
        });

        importedGppCount++;

        // Generate JAP entries for each year in the range
        for (let year = normalizedStart; year <= normalizedEnd; year += 1) {
          await prismaService.japGppEntry.create({
            data: {
              source: 'JAP',
              year,
              goalMeasure: doelstelling,
              domainId,
              riskField: readCell(row, indexes.risicoveld) || 'Algemeen',
              priority: parsePriority(readCell(row, indexes.prioriteit)),
              realisation: parseRealisatie(readCell(row, indexes.realisatie)),
              executor: readCell(row, indexes.uitvoerder),
              resourcesBudget: readCell(row, indexes.middelenBudgetWerkuren),
              startDate: startFromDate ? new Date(startFromDate.replace(/(\d{2})\.(\d{2})\.(\d{4})/, '$3-$2-$1')) : null,
              endDate: endFromDate ? new Date(endFromDate.replace(/(\d{2})\.(\d{2})\.(\d{4})/, '$3-$2-$1')) : null,
              remark: readCell(row, indexes.opmerking),
              generatedFromGppId: gppEntry.id,
            },
          });
          generatedJapCount++;
        }
      }

      return res.status(201).json({
        message: `Import gelukt vanuit ${sourceName}`,
        importedGppCount,
        importedJapCount: generatedJapCount,
        totalGeneratedJapCount: generatedJapCount,
      });
    } catch (error: any) {
      return res.status(500).json({
        message: 'Excel import mislukt',
        details: error?.message ?? 'Onbekende fout',
      });
    }
  });

  router.get('/', async (req: Request, res: Response) => {
    try {
      const { search } = req.query;
      const where: any = { source: 'GPP' };

      if (search && typeof search === 'string') {
        const q = search.toLowerCase();
        where.OR = [
          { goalMeasure: { contains: q, mode: 'insensitive' } },
          { domain: { name: { contains: q, mode: 'insensitive' } } },
        ];
      }

      const entries = await prismaService.japGppEntry.findMany({
        where,
        include: {
          domain: true,
          comments: true,
        },
        orderBy: [{ startYear: 'desc' }, { id: 'desc' }],
      });

      const result = entries.map(formatGppEntry);
      res.json({ entries: result });
    } catch (error) {
      console.error('Error fetching GPP entries:', error);
      res.status(500).json({ message: 'Fout bij ophalen GPP entries' });
    }
  });

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

  router.post('/:id/comments', async (req: Request, res: Response) => {
    try {
      const id = Number(req.params.id);
      const { author, text } = req.body;

      if (!text?.trim()) {
        return res.status(400).json({ message: 'Tekst is verplicht' });
      }

      const entry = await prismaService.japGppEntry.findUnique({
        where: { id },
      });

      if (!entry) {
        return res.status(404).json({ message: 'Entry niet gevonden' });
      }

      const comment = await prismaService.japComment.create({
        data: {
          entryId: id,
          author: author?.trim() || 'Onbekend',
          text: text.trim(),
        },
      });

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
            title: 'Nieuwe opmerking op GPP',
            body: text.trim().slice(0, 200),
            metadata: { entryId: id, module: 'GPP' },
          });
        }
      } catch (notifyError) {
        console.warn('Failed to notify users for GPP comment', notifyError);
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

  router.post('/', async (req: Request, res: Response) => {
    try {
      const {
        startJaar,
        eindJaar,
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

      const [startYear, endYear] = normaliseYearRange(
        Number(startJaar) || new Date().getFullYear(),
        Number(eindJaar) || new Date().getFullYear(),
      );

      // Find or create domain
      let domainId = null;
      if (domein) {
        let domain = await prismaService.domain.findUnique({
          where: { name: domein },
        });
        if (!domain) {
          domain = await prismaService.domain.create({
            data: { name: domein },
          });
        }
        domainId = domain.id;
      }

      const gppEntry = await prismaService.japGppEntry.create({
        data: {
          source: 'GPP',
          startYear,
          endYear,
          goalMeasure: doelstellingMaatregel,
          domainId,
          riskField: risicoveld || 'Algemeen',
          priority: prioriteit || 'laag',
          realisation: realisatie || 'vul_aan',
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

      // Generate JAP entries
      for (let year = startYear; year <= endYear; year += 1) {
        await prismaService.japGppEntry.create({
          data: {
            source: 'JAP',
            year,
            goalMeasure: doelstellingMaatregel,
            domainId,
            riskField: risicoveld || 'Algemeen',
            priority: prioriteit || 'laag',
            realisation: realisatie || 'vul_aan',
            executor: uitvoerder,
            resourcesBudget: middelenBudgetWerkuren,
            startDate: startdatum ? new Date(startdatum) : null,
            endDate: einddatum ? new Date(einddatum) : null,
            remark: opmerking,
            generatedFromGppId: gppEntry.id,
          },
        });
      }

      // Notify
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
            body: `${doelstellingMaatregel ?? 'Nieuwe GPP'}`,
            metadata: { entryId: gppEntry.id, module: 'GPP' },
          });
        }
      } catch (err) {
        console.warn('Failed to notify users for GPP creation', err);
      }

      res.status(201).json({ entry: formatGppEntry(gppEntry) });
    } catch (error) {
      console.error('Error creating GPP entry:', error);
      res.status(500).json({ message: 'Fout bij aanmaken GPP entry' });
    }
  });

  router.patch('/:id', async (req: Request, res: Response) => {
    try {
      const id = Number(req.params.id);

      const previous = await prismaService.japGppEntry.findUnique({
        where: { id },
      });

      if (!previous) {
        return res.status(404).json({ message: 'Entry niet gevonden' });
      }

      const {
        startJaar,
        eindJaar,
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

      let domainId = previous.domainId;
      if (domein !== undefined) {
        if (domein) {
          let domain = await prismaService.domain.findUnique({
            where: { name: domein },
          });
          if (!domain) {
            domain = await prismaService.domain.create({
              data: { name: domein },
            });
          }
          domainId = domain.id;
        } else {
          domainId = null;
        }
      }

      const startYear = startJaar !== undefined ? Number(startJaar) : previous.startYear;
      const endYear = eindJaar !== undefined ? Number(eindJaar) : previous.endYear;
      const [normalizedStart, normalizedEnd] = normaliseYearRange(startYear, endYear);

      const updated = await prismaService.japGppEntry.update({
        where: { id },
        data: {
          startYear: normalizedStart,
          endYear: normalizedEnd,
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

      // Sync generated JAP entries
      await syncGeneratedJapEntriesForGpp(updated);

      // Notify if remark was added
      if (opmerking && opmerking.trim() !== '' && (!previous.remark || previous.remark.trim() === '')) {
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
              body: opmerking.toString().slice(0, 200),
              metadata: { entryId: updated.id, module: 'GPP' },
            });
          }
        } catch (err) {
          console.warn('Failed to notify users for GPP comment', err);
        }
      }

      res.json({ entry: formatGppEntry(updated) });
    } catch (error) {
      console.error('Error updating GPP entry:', error);
      res.status(500).json({ message: 'Fout bij bijwerken GPP entry' });
    }
  });

  router.delete('/:id', async (req: Request, res: Response) => {
    try {
      const id = Number(req.params.id);
      // Delete generated JAP entries
      await prismaService.japGppEntry.deleteMany({
        where: { generatedFromGppId: id },
      });
      // Delete GPP entry
      await prismaService.japGppEntry.delete({
        where: { id },
      });
      res.status(204).send();
    } catch (error: any) {
      if (error.code === 'P2025') {
        return res.status(404).json({ message: 'Entry niet gevonden' });
      }
      console.error('Error deleting GPP entry:', error);
      res.status(500).json({ message: 'Fout bij verwijderen GPP entry' });
    }
  });

  return router;
}
