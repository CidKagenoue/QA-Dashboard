import { Router, Request, Response } from 'express';
import { NotificationType } from '@prisma/client';
import * as multer from 'multer';
import * as XLSX from 'xlsx';
import { store, GppStoreEntry, JapStoreEntry } from './jap-gpp-store';

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

function createGppFromImportRow(
  row: unknown[],
  indexes: Record<string, number>,
  startYear: number,
  endYear: number,
): GppStoreEntry {
  const startFromDate = parseExcelDate(row[indexes.startdatum]);
  const endFromDate = parseExcelDate(row[indexes.einddatum]);

  return {
    id: Date.now() + Math.floor(Math.random() * 1000000),
    startJaar: startYear,
    eindJaar: endYear,
    doelstellingMaatregel: readCell(row, indexes.doelstellingMaatregel),
    domein: readCell(row, indexes.domein) || 'Vul aan',
    risicoveld: readCell(row, indexes.risicoveld) || 'Algemeen',
    prioriteit: parsePriority(readCell(row, indexes.prioriteit)),
    realisatie: parseRealisatie(readCell(row, indexes.realisatie)),
    uitvoerder: readCell(row, indexes.uitvoerder),
    middelenBudgetWerkuren: readCell(row, indexes.middelenBudgetWerkuren),
    startdatum: coerceDateForYear(row[indexes.startdatum], startYear, `01.01.${startYear}`),
    einddatum: coerceDateForYear(row[indexes.einddatum], endYear, `31.12.${endYear}`),
    opmerking: readCell(row, indexes.opmerking),
  };
}

function buildGeneratedJapEntry(gpp: GppStoreEntry, year: number): JapStoreEntry {
  return {
    id: Date.now() + Math.floor(Math.random() * 1000000),
    jaar: year,
    doelstellingMaatregel: gpp.doelstellingMaatregel,
    domein: gpp.domein,
    risicoveld: gpp.risicoveld ?? 'Algemeen',
    prioriteit: gpp.prioriteit ?? 'laag',
    realisatie: gpp.realisatie ?? 'vul_aan',
    uitvoerder: gpp.uitvoerder ?? '',
    middelenBudgetWerkuren: gpp.middelenBudgetWerkuren ?? '',
    startdatum: buildDateForYear(gpp.startdatum ?? '', year, `01.01.${year}`),
    einddatum: buildDateForYear(gpp.einddatum ?? '', year, `31.12.${year}`),
    opmerking: gpp.opmerking ?? '',
    generatedFromGppId: gpp.id,
  };
}

function buildImportedJapEntry(
  masterGpp: GppStoreEntry,
  row: unknown[],
  year: number,
  indexes: Record<string, number>,
): JapStoreEntry {
  const startFromDate = parseExcelDate(row[indexes.startdatum]);
  const endFromDate = parseExcelDate(row[indexes.einddatum]);

  return {
    id: Date.now() + Math.floor(Math.random() * 1000000),
    jaar: year,
    doelstellingMaatregel: readCell(row, indexes.doelstellingMaatregel),
    domein: readCell(row, indexes.domein) || masterGpp.domein,
    risicoveld: readCell(row, indexes.risicoveld) || masterGpp.risicoveld || 'Algemeen',
    prioriteit: parsePriority(readCell(row, indexes.prioriteit)),
    realisatie: parseRealisatie(readCell(row, indexes.realisatie)),
    uitvoerder: readCell(row, indexes.uitvoerder),
    middelenBudgetWerkuren: readCell(row, indexes.middelenBudgetWerkuren),
    startdatum: startFromDate || `01.01.${year}`,
    einddatum: endFromDate || `31.12.${year}`,
    opmerking: readCell(row, indexes.opmerking),
    generatedFromGppId: masterGpp.id,
  };
}

function syncGeneratedJapEntriesForGpp(gpp: GppStoreEntry): void {
  const [startYear, endYear] = normaliseYearRange(gpp.startJaar, gpp.eindJaar);
  const expectedYears = new Set<number>();
  for (let year = startYear; year <= endYear; year += 1) {
    expectedYears.add(year);
  }

  const existingForGpp = store.japEntries.filter((e) => e.generatedFromGppId === gpp.id);

  for (const year of expectedYears) {
    const alreadyExists = existingForGpp.some((e) => e.jaar === year);
    if (!alreadyExists) {
      store.japEntries.push(buildGeneratedJapEntry(gpp, year));
    }
  }

  store.japEntries = store.japEntries
    .filter((entry) => entry.generatedFromGppId !== gpp.id || expectedYears.has(entry.jaar))
    .map((entry) => {
      if (entry.generatedFromGppId !== gpp.id) return entry;
      return {
        ...entry,
        doelstellingMaatregel: gpp.doelstellingMaatregel,
        domein: gpp.domein,
        risicoveld: gpp.risicoveld ?? entry.risicoveld,
        prioriteit: gpp.prioriteit ?? entry.prioriteit,
        realisatie: gpp.realisatie ?? entry.realisatie,
        uitvoerder: gpp.uitvoerder ?? entry.uitvoerder,
        middelenBudgetWerkuren: gpp.middelenBudgetWerkuren ?? entry.middelenBudgetWerkuren,
        startdatum: buildDateForYear(gpp.startdatum ?? '', entry.jaar, entry.startdatum ?? `01.01.${entry.jaar}`),
        einddatum: buildDateForYear(gpp.einddatum ?? '', entry.jaar, entry.einddatum ?? `31.12.${entry.jaar}`),
        opmerking: gpp.opmerking ?? entry.opmerking,
      };
    });
}

export default function createGppRouter(
  notificationsService: any,
  prismaService: any,
) {
  const router = Router();

  router.post('/import-excel', upload.single('file'), (req: Request, res: Response) => {
    try {
      const file = (req as any).file;
      if (!file?.buffer) {
        return res.status(400).json({ message: 'Importbestand ontbreekt (field: file)' });
      }

      const shouldClear = String(req.query.clearExisting ?? 'true').toLowerCase() !== 'false';
      if (shouldClear) {
        store.gppEntries = [];
        store.japEntries = store.japEntries.filter((e) => e.generatedFromGppId == null);
      }

      const { rows, sourceName } = readImportRows(file);
      const headerIndex = findHeaderRow(rows);

      if (headerIndex < 0) {
        return res.status(400).json({ message: 'Kon geen geldige header rij vinden in het GPP bestand.' });
      }

      const indexes = findColumnIndexes(rows[headerIndex]);
      const dataRows = rows.slice(headerIndex + 1).filter((row) => (row ?? []).some((cell) => String(cell ?? '').trim() !== ''));
      const importedGppEntries: GppStoreEntry[] = [];

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

        importedGppEntries.push(createGppFromImportRow(row, indexes, normalizedStart, normalizedEnd));
      }

      store.gppEntries.push(...importedGppEntries);
      for (const entry of importedGppEntries) {
        syncGeneratedJapEntriesForGpp(entry);
      }

      return res.status(201).json({
        message: `Import gelukt vanuit ${sourceName}`,
        importedGppCount: importedGppEntries.length,
        importedJapCount: store.japEntries.filter((e) => importedGppEntries.some((gpp) => gpp.id === e.generatedFromGppId)).length,
        totalGeneratedJapCount: store.japEntries.filter((e) => e.generatedFromGppId != null).length,
      });
    } catch (error: any) {
      return res.status(500).json({
        message: 'Excel import mislukt',
        details: error?.message ?? 'Onbekende fout',
      });
    }
  });

  router.get('/', (req: Request, res: Response) => {
    const { search } = req.query;
    let result = [...store.gppEntries];

    if (search && typeof search === 'string') {
      const q = search.toLowerCase();
      result = result.filter(
        (e) =>
          e.doelstellingMaatregel?.toLowerCase().includes(q) ||
          e.domein?.toLowerCase().includes(q),
      );
    }

    result.sort((a, b) => b.startJaar - a.startJaar || b.id - a.id);

    res.json({ entries: result });
  });

  router.post('/', async (req: Request, res: Response) => {
    const entry: GppStoreEntry = {
      ...req.body,
      id: Date.now(),
      startJaar: Number(req.body?.startJaar) || new Date().getFullYear(),
      eindJaar: Number(req.body?.eindJaar) || new Date().getFullYear(),
      risicoveld: String(req.body?.risicoveld ?? 'Algemeen'),
      prioriteit: String(req.body?.prioriteit ?? 'laag'),
      realisatie: String(req.body?.realisatie ?? 'vul_aan'),
      middelenBudgetWerkuren: String(req.body?.middelenBudgetWerkuren ?? ''),
      startdatum: String(req.body?.startdatum ?? `01.01.${Number(req.body?.startJaar) || new Date().getFullYear()}`),
      einddatum: String(req.body?.einddatum ?? `31.12.${Number(req.body?.eindJaar) || new Date().getFullYear()}`),
    };
    const [startYear, endYear] = normaliseYearRange(entry.startJaar, entry.eindJaar);
    entry.startJaar = startYear;
    entry.eindJaar = endYear;

    store.gppEntries.push(entry);
    syncGeneratedJapEntriesForGpp(entry);

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
    const id = Number(req.params.id);
    const index = store.gppEntries.findIndex((e) => e.id === id);
    if (index === -1) return res.status(404).json({ message: 'Entry niet gevonden' });
    const previous = { ...store.gppEntries[index] };
    store.gppEntries[index] = {
      ...store.gppEntries[index],
      ...req.body,
      startJaar: Number(req.body?.startJaar ?? store.gppEntries[index].startJaar),
      eindJaar: Number(req.body?.eindJaar ?? store.gppEntries[index].eindJaar),
    };
    const [startYear, endYear] = normaliseYearRange(
      store.gppEntries[index].startJaar,
      store.gppEntries[index].eindJaar,
    );
    store.gppEntries[index].startJaar = startYear;
    store.gppEntries[index].eindJaar = endYear;
    syncGeneratedJapEntriesForGpp(store.gppEntries[index]);
    const updated = store.gppEntries[index];

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

    res.json({ entry: store.gppEntries[index] });
  });

  router.delete('/:id', (req: Request, res: Response) => {
    const id = Number(req.params.id);
    store.gppEntries = store.gppEntries.filter((e) => e.id !== id);
    store.japEntries = store.japEntries.filter((e) => e.generatedFromGppId !== id);
    res.status(204).send();
  });

  return router;
}
