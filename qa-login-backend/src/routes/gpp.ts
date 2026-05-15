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
    uitvoerder: ['uitvoerder', 'verantwoordelijke'],
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
  // If Excel stores as a serial number, parse to day/month/year then return ISO yyyy-mm-dd
  if (typeof value === 'number' && Number.isFinite(value)) {
    const date = XLSX.SSF.parse_date_code(value);
    if (!date) return '';
    const day = String(date.d).padStart(2, '0');
    const month = String(date.m).padStart(2, '0');
    const year = String(date.y).padStart(4, '0');
    return `${year}-${month}-${day}`;
  }

  const text = String(value).trim();
  // dd.mm.yyyy or dd/mm/yyyy or dd-mm-yyyy -> convert to ISO
  if (/^\d{1,2}[./-]\d{1,2}[./-]\d{4}$/.test(text)) {
    const parts = text.replace(/\//g, '.').replace(/-/g, '.').split('.');
    const d = parts[0].padStart(2, '0');
    const m = parts[1].padStart(2, '0');
    const y = parts[2];
    return `${y}-${m}-${d}`;
  }
  // yyyy-mm-dd or yyyy.mm.dd -> normalize to yyyy-mm-dd
  if (/^\d{4}[./-]\d{1,2}[./-]\d{1,2}$/.test(text)) {
    const iso = text.replace(/\./g, '-').replace(/\//g, '-');
    const [y, m, d] = iso.split('-');
    return `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
  }
  return text;
}

function coerceDateForYear(value: unknown, year: number, fallback: string): string {
  const parsed = parseExcelDate(value);
  if (!parsed) return fallback;
  // parsed is ISO yyyy-mm-dd
  const match = parsed.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!match) return fallback;

  const parsedYear = Number(match[1]);
  if (parsedYear < 1900 || parsedYear > 2100) return fallback;

  const day = match[3];
  const month = match[2];
  return `${day}.${month}.${String(year)}`;
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
  const normalized = base.replace(/\./g, '-').replace(/\//g, '-');
  // Accept either ISO yyyy-mm-dd or dd-mm-yyyy
  const isoMatch = normalized.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (isoMatch) {
    const day = isoMatch[3].padStart(2, '0');
    const month = isoMatch[2].padStart(2, '0');
    return `${day}.${month}.${year}`;
  }
  const dmyMatch = normalized.match(/^(\d{1,2})-(\d{1,2})-(\d{4})$/);
  if (dmyMatch) {
    const day = dmyMatch[1].padStart(2, '0');
    const month = dmyMatch[2].padStart(2, '0');
    return `${day}.${month}.${year}`;
  }
  return fallback;
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

async function ensureExecutor(prismaService: any, executorName: string | null | undefined) {
  const normalized = String(executorName ?? '').trim();
  if (!normalized) return;

  await prismaService.executor.upsert({
    where: { name: normalized },
    create: { name: normalized },
    update: {},
  });
}

export default function createGppRouter(
  notificationsService: any,
  prismaService: any,
) {
  const router = Router();

  // Previously this helper created per-year JAP rows from a GPP entry.
  // That behavior is intentionally removed: JAP is a generated view only.

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
        const parsedStartYear = startFromDate && /^\d{4}-/.test(startFromDate) ? Number(startFromDate.slice(0, 4)) : Number(startFromDate.slice(-4));
        const parsedEndYear = endFromDate && /^\d{4}-/.test(endFromDate) ? Number(endFromDate.slice(0, 4)) : Number(endFromDate.slice(-4));
        const startYear = range?.[0] ?? (parsedStartYear || new Date().getFullYear());
        const endYear = range?.[1] ?? (parsedEndYear || startYear);
        const [normalizedStart, normalizedEnd] = normaliseYearRange(startYear, endYear);

        // Build Date objects for startDate/endDate. Prefer explicit cell dates; fallback to year boundaries.
        const startDateObj = startFromDate ? new Date(startFromDate) : new Date(normalizedStart, 0, 1);
        const endDateObj = endFromDate ? new Date(endFromDate) : new Date(normalizedEnd, 11, 31);

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
            startDate: startDateObj,
            endDate: endDateObj,
            remark: readCell(row, indexes.opmerking),
          },
        });

        await ensureExecutor(prismaService, gppEntry.executor);

        importedGppCount++;

        // Do not generate per-year JAP entries on import — keep only the GPP row
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

      // Determine startDate/endDate as real Date objects. Prefer explicit date input; fall back to year boundaries.
      const parsedStartIso = parseExcelDate(startdatum);
      const parsedEndIso = parseExcelDate(einddatum);
      const finalStartDate = parsedStartIso && /^\d{4}-\d{2}-\d{2}$/.test(parsedStartIso)
        ? new Date(parsedStartIso)
        : new Date(startYear, 0, 1);
      const finalEndDate = parsedEndIso && /^\d{4}-\d{2}-\d{2}$/.test(parsedEndIso)
        ? new Date(parsedEndIso)
        : new Date(endYear, 11, 31);

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
          startDate: finalStartDate,
          endDate: finalEndDate,
          remark: opmerking,
        },
        include: {
          domain: true,
          comments: true,
        },
      });

      await ensureExecutor(prismaService, uitvoerder);

      // Do not generate per-year JAP entries when creating a GPP — only the GPP row is created

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

      // compute updated start/end Date values as Date objects
      const providedStartIso = startdatum !== undefined ? parseExcelDate(startdatum) : null;
      const providedEndIso = einddatum !== undefined ? parseExcelDate(einddatum) : null;
      const startDateValue = startdatum !== undefined
        ? (providedStartIso && /^\d{4}-\d{2}-\d{2}$/.test(providedStartIso) ? new Date(providedStartIso) : null)
        : undefined; // keep existing
      const endDateValue = einddatum !== undefined
        ? (providedEndIso && /^\d{4}-\d{2}-\d{2}$/.test(providedEndIso) ? new Date(providedEndIso) : null)
        : undefined;

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
          startDate: startDateValue !== undefined ? startDateValue : undefined,
          endDate: endDateValue !== undefined ? endDateValue : undefined,
          remark: opmerking !== undefined ? opmerking : undefined,
        },
        include: {
          domain: true,
          comments: true,
        },
      });

      await ensureExecutor(prismaService, uitvoerder);

      // Do not generate/sync per-year JAP entries when updating a GPP — keep only the GPP row

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
