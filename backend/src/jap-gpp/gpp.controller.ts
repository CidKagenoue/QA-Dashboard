import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Res,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { NotificationType } from '@prisma/client';
import { Response } from 'express';
import * as ExcelJS from 'exceljs';
import * as multer from 'multer';
import { NotificationService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';

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
  for (let index = 0; index < rows.length; index += 1) {
    const row = rows[index] ?? [];
    const joined = row.map(normaliseHeader).join('|');
    if (joined.includes('doelstelling') && joined.includes('risicoveld')) {
      return index;
    }
  }
  return -1;
}

function findColumnIndexes(headerRow: unknown[]): Record<string, number> {
  const indexes: Record<string, number> = {};
  headerRow.forEach((cell, index) => {
    const key = normaliseHeader(cell);
    for (const [target, aliases] of Object.entries(NORMALISED_HEADER_ALIASES)) {
      const matches = aliases.some((alias) => (
        alias.length === 1 ? key === alias : key.includes(alias)
      ));
      if (matches && indexes[target] == null) {
        indexes[target] = index;
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

  for (let index = 0; index < text.length; index += 1) {
    const char = text[index];
    const next = text[index + 1];

    if (char === '"') {
      if (inQuotes && next === '"') {
        cell += '"';
        index += 1;
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
      if (char === '\r' && next === '\n') index += 1;
      continue;
    }

    cell += char;
  }

  row.push(cell);
  if (row.some((value) => value.trim() !== '')) rows.push(row);
  return rows;
}

function worksheetToRows(worksheet: ExcelJS.Worksheet): unknown[][] {
  const rows: unknown[][] = [];

  worksheet.eachRow({ includeEmpty: false }, (row) => {
    const values = Array.isArray(row.values) ? row.values.slice(1) : [];
    rows.push(values.map((value) => (
      value instanceof Date
        ? value
        : value && typeof value === 'object' && 'text' in value
          ? String((value as any).text ?? '')
          : value ?? ''
    )));
  });

  return rows;
}

async function readImportRows(file: any): Promise<{ rows: unknown[][]; sourceName: string }> {
  const fileName = file.originalname || 'GPP import';
  const lowerName = fileName.toLowerCase();

  if (lowerName.endsWith('.xlsx') || lowerName.endsWith('.xls')) {
    if (lowerName.endsWith('.xls')) {
      throw new Error('Het .xls formaat wordt niet ondersteund. Gebruik een .xlsx bestand.');
    }

    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(file.buffer);
    const gppSheet = workbook.worksheets.find((sheet) => sheet.name.toLowerCase().includes('gpp'));

    if (!gppSheet) {
      throw new Error('Geen GPP sheet gevonden in het Excel bestand.');
    }

    return {
      rows: worksheetToRows(gppSheet),
      sourceName: gppSheet.name,
    };
  }

  return {
    rows: parseDelimitedRows(file.buffer.toString('utf8')),
    sourceName: fileName,
  };
}

function readCell(row: unknown[], index: number | undefined): string {
  if (index == null) return '';
  return String(row[index] ?? '').trim();
}

function parseExcelDate(value: unknown): string {
  if (value == null || value === '') return '';
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return value.toISOString().slice(0, 10);
  }
  if (typeof value === 'number' && Number.isFinite(value)) {
    const epoch = Date.UTC(1899, 11, 30);
    const millis = Math.round(value * 86400000);
    const date = new Date(epoch + millis);
    if (Number.isNaN(date.getTime())) return '';
    const day = String(date.getUTCDate()).padStart(2, '0');
    const month = String(date.getUTCMonth() + 1).padStart(2, '0');
    const year = String(date.getUTCFullYear()).padStart(4, '0');
    return `${year}-${month}-${day}`;
  }

  const text = String(value).trim();
  if (/^\d{1,2}[./-]\d{1,2}[./-]\d{4}$/.test(text)) {
    const parts = text.replace(/\//g, '.').replace(/-/g, '.').split('.');
    const day = parts[0].padStart(2, '0');
    const month = parts[1].padStart(2, '0');
    const year = parts[2];
    return `${year}-${month}-${day}`;
  }
  if (/^\d{4}[./-]\d{1,2}[./-]\d{1,2}$/.test(text)) {
    const iso = text.replace(/\./g, '-').replace(/\//g, '-');
    const [year, month, day] = iso.split('-');
    return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
  }
  return text;
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
    comments: entry.comments?.map((comment: any) => ({
      id: comment.id,
      author: comment.author,
      text: comment.text,
      createdAt: comment.createdAt.toISOString(),
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

@Controller('gpp')
export class GppController {
  constructor(
    private readonly notificationsService: NotificationService,
    private readonly prismaService: PrismaService,
  ) {}

  @Post('import-excel')
  @UseInterceptors(FileInterceptor('file', { storage: multer.memoryStorage() }))
  async importExcel(
    @UploadedFile() file: any,
    @Query('clearExisting') clearExisting: string | undefined,
    @Res() res: Response,
  ) {
    try {
      if (!file?.buffer) {
        return res.status(400).json({ message: 'Importbestand ontbreekt (field: file)' });
      }

      const shouldClear = String(clearExisting ?? 'true').toLowerCase() !== 'false';
      if (shouldClear) {
        await this.prismaService.japGppEntry.deleteMany({
          where: {
            generatedFromGppId: { not: null },
          },
        });
        await this.prismaService.japGppEntry.deleteMany({
          where: { source: 'GPP' },
        });
      }

      const { rows, sourceName } = await readImportRows(file);
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

        const startDateObj = startFromDate ? new Date(startFromDate) : new Date(normalizedStart, 0, 1);
        const endDateObj = endFromDate ? new Date(endFromDate) : new Date(normalizedEnd, 11, 31);

        let domainId = null;
        const domeinName = readCell(row, indexes.domein);
        if (domeinName && domeinName !== 'Vul aan') {
          let domain = await this.prismaService.domain.findUnique({
            where: { name: domeinName },
          });
          if (!domain) {
            domain = await this.prismaService.domain.create({
              data: { name: domeinName },
            });
          }
          domainId = domain.id;
        }

        const gppEntry = await this.prismaService.japGppEntry.create({
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

        await ensureExecutor(this.prismaService, gppEntry.executor);

        importedGppCount += 1;
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
  }

  @Get()
  async listGppEntries(
    @Query('search') search: string | undefined,
    @Res() res: Response,
  ) {
    try {
      const where: any = { source: 'GPP' };

      if (search && typeof search === 'string') {
        const q = search.toLowerCase();
        where.OR = [
          { goalMeasure: { contains: q, mode: 'insensitive' } },
          { domain: { name: { contains: q, mode: 'insensitive' } } },
        ];
      }

      const entries = await this.prismaService.japGppEntry.findMany({
        where,
        include: {
          domain: true,
          comments: true,
        },
        orderBy: [{ startYear: 'desc' }, { id: 'desc' }],
      });

      return res.json({ entries: entries.map(formatGppEntry) });
    } catch (error) {
      console.error('Error fetching GPP entries:', error);
      return res.status(500).json({ message: 'Fout bij ophalen GPP entries' });
    }
  }

  @Get(':id/comments')
  async listComments(@Param('id') idParam: string, @Res() res: Response) {
    try {
      const id = Number(idParam);
      const entry = await this.prismaService.japGppEntry.findUnique({
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

      const comments = entry.comments.map((comment: any) => ({
        id: comment.id,
        author: comment.author,
        text: comment.text,
        createdAt: comment.createdAt.toISOString(),
      }));

      return res.json({ comments });
    } catch (error) {
      console.error('Error fetching comments:', error);
      return res.status(500).json({ message: 'Fout bij ophalen commentaar' });
    }
  }

  @Post(':id/comments')
  async createComment(
    @Param('id') idParam: string,
    @Body() body: { author?: string; text?: string },
    @Res() res: Response,
  ) {
    try {
      const id = Number(idParam);
      const { author, text } = body;

      if (!text?.trim()) {
        return res.status(400).json({ message: 'Tekst is verplicht' });
      }

      const entry = await this.prismaService.japGppEntry.findUnique({
        where: { id },
      });

      if (!entry) {
        return res.status(404).json({ message: 'Entry niet gevonden' });
      }

      const comment = await this.prismaService.japComment.create({
        data: {
          entryId: id,
          author: author?.trim() || 'Onbekend',
          text: text.trim(),
        },
      });

      try {
        const users = await this.prismaService.user.findMany({
          where: { OR: [{ isAdmin: true }, { japGppAccess: true }] },
          select: { id: true },
        });
        const recipientIds = users.map((user: any) => user.id);
        if (recipientIds.length > 0) {
          await this.notificationsService.notifyUsers({
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

      return res.status(201).json({
        comment: {
          id: comment.id,
          author: comment.author,
          text: comment.text,
          createdAt: comment.createdAt.toISOString(),
        },
      });
    } catch (error) {
      console.error('Error creating comment:', error);
      return res.status(500).json({ message: 'Fout bij aanmaken commentaar' });
    }
  }

  @Post()
  async createEntry(@Body() body: any, @Res() res: Response) {
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
      } = body;

      const [startYear, endYear] = normaliseYearRange(
        Number(startJaar) || new Date().getFullYear(),
        Number(eindJaar) || new Date().getFullYear(),
      );

      let domainId = null;
      if (domein) {
        let domain = await this.prismaService.domain.findUnique({
          where: { name: domein },
        });
        if (!domain) {
          domain = await this.prismaService.domain.create({
            data: { name: domein },
          });
        }
        domainId = domain.id;
      }

      const parsedStartIso = parseExcelDate(startdatum);
      const parsedEndIso = parseExcelDate(einddatum);
      const finalStartDate = parsedStartIso && /^\d{4}-\d{2}-\d{2}$/.test(parsedStartIso)
        ? new Date(parsedStartIso)
        : new Date(startYear, 0, 1);
      const finalEndDate = parsedEndIso && /^\d{4}-\d{2}-\d{2}$/.test(parsedEndIso)
        ? new Date(parsedEndIso)
        : new Date(endYear, 11, 31);

      const gppEntry = await this.prismaService.japGppEntry.create({
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

      await ensureExecutor(this.prismaService, uitvoerder);

      try {
        const users = await this.prismaService.user.findMany({
          where: { OR: [{ isAdmin: true }, { japGppAccess: true }] },
          select: { id: true },
        });
        const recipientIds = users.map((user: any) => user.id);
        if (recipientIds.length > 0) {
          await this.notificationsService.notifyUsers({
            recipientUserIds: recipientIds,
            type: NotificationType.JAP_NEW,
            title: 'Nieuwe GPP entry toegevoegd',
            body: `${doelstellingMaatregel ?? 'Nieuwe GPP'}`,
            metadata: { entryId: gppEntry.id, module: 'GPP' },
          });
        }
      } catch (err) {
        console.warn('Failed to notify users for GPP creation', err);
      }

      return res.status(201).json({ entry: formatGppEntry(gppEntry) });
    } catch (error) {
      console.error('Error creating GPP entry:', error);
      return res.status(500).json({ message: 'Fout bij aanmaken GPP entry' });
    }
  }

  @Patch(':id')
  async updateEntry(
    @Param('id') idParam: string,
    @Body() body: any,
    @Res() res: Response,
  ) {
    try {
      const id = Number(idParam);

      const previous = await this.prismaService.japGppEntry.findUnique({
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
      } = body;

      let domainId = previous.domainId;
      if (domein !== undefined) {
        if (domein) {
          let domain = await this.prismaService.domain.findUnique({
            where: { name: domein },
          });
          if (!domain) {
            domain = await this.prismaService.domain.create({
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

      const providedStartIso = startdatum !== undefined ? parseExcelDate(startdatum) : null;
      const providedEndIso = einddatum !== undefined ? parseExcelDate(einddatum) : null;
      const startDateValue = startdatum !== undefined
        ? (providedStartIso && /^\d{4}-\d{2}-\d{2}$/.test(providedStartIso) ? new Date(providedStartIso) : null)
        : undefined;
      const endDateValue = einddatum !== undefined
        ? (providedEndIso && /^\d{4}-\d{2}-\d{2}$/.test(providedEndIso) ? new Date(providedEndIso) : null)
        : undefined;

      const updated = await this.prismaService.japGppEntry.update({
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

      await ensureExecutor(this.prismaService, uitvoerder);

      if (opmerking && opmerking.trim() !== '' && (!previous.remark || previous.remark.trim() === '')) {
        try {
          const users = await this.prismaService.user.findMany({
            where: { OR: [{ isAdmin: true }, { japGppAccess: true }] },
            select: { id: true },
          });
          const recipientIds = users.map((user: any) => user.id);
          if (recipientIds.length > 0) {
            await this.notificationsService.notifyUsers({
              recipientUserIds: recipientIds,
              type: NotificationType.JAP_COMMENT,
              title: 'Nieuwe opmerking op GPP',
              body: opmerking.toString().slice(0, 200),
              metadata: { entryId: updated.id, module: 'GPP' },
            });
          }
        } catch (err) {
          console.warn('Failed to notify users for GPP comment', err);
        }
      }

      return res.json({ entry: formatGppEntry(updated) });
    } catch (error) {
      console.error('Error updating GPP entry:', error);
      return res.status(500).json({ message: 'Fout bij bijwerken GPP entry' });
    }
  }

  @Delete(':id')
  async deleteEntry(@Param('id') idParam: string, @Res() res: Response) {
    try {
      const id = Number(idParam);

      await this.prismaService.japGppEntry.deleteMany({
        where: { generatedFromGppId: id },
      });

      await this.prismaService.japGppEntry.delete({
        where: { id },
      });

      return res.status(204).send();
    } catch (error: any) {
      if (error.code === 'P2025') {
        return res.status(404).json({ message: 'Entry niet gevonden' });
      }
      console.error('Error deleting GPP entry:', error);
      return res.status(500).json({ message: 'Fout bij verwijderen GPP entry' });
    }
  }
}