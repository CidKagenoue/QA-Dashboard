require('dotenv/config');

const fs = require('fs');
const path = require('path');
const ExcelJS = require('exceljs');
const { Pool } = require('pg');
const { PrismaPg } = require('@prisma/adapter-pg');
const { PrismaClient } = require('@prisma/client');

const databaseUrl = process.env.DATABASE_URL;

if (!databaseUrl) {
  throw new Error('DATABASE_URL is required');
}

const pool = new Pool({ connectionString: databaseUrl });
const prisma = new PrismaClient({ adapter: new PrismaPg(pool) });

function parseDate(text) {
  if (!text) return null;
  if (text instanceof Date && !isNaN(text.getTime())) return text;
  if (typeof text === 'number' && Number.isFinite(text)) {
    const epoch = Date.UTC(1899, 11, 30);
    const date = new Date(epoch + Math.round(text * 86400000));
    return isNaN(date.getTime()) ? null : date;
  }
  const t = String(text).trim();
  if (!t) return null;
  // Accept formats like 1.01.2021 or 01.01.2025 or 2021-01-01
  const dotParts = t.split('.');
  if (dotParts.length === 3) {
    const day = parseInt(dotParts[0], 10);
    const month = parseInt(dotParts[1], 10);
    const year = parseInt(dotParts[2], 10);
    if (!isNaN(day) && !isNaN(month) && !isNaN(year)) {
      return new Date(year, month - 1, day);
    }
  }
  // ISO fallback
  const d = new Date(t);
  if (!isNaN(d.getTime())) return d;
  return null;
}

function pickDelimiter(text) {
  const sample = text.split(/\r?\n/).slice(0, 8).join('\n');
  const candidates = ['\t', ';', ','];
  return candidates
    .map((delimiter) => ({
      delimiter,
      count: sample.split(delimiter).length - 1,
    }))
    .sort((a, b) => b.count - a.count)[0]?.delimiter || '\t';
}

function worksheetToRows(worksheet) {
  const rows = [];
  worksheet.eachRow({ includeEmpty: false }, (row) => {
    const values = Array.isArray(row.values) ? row.values.slice(1) : [];
    rows.push(values.map((value) => (
      value && typeof value === 'object' && Object.prototype.hasOwnProperty.call(value, 'text')
        ? String(value.text || '')
        : (value ?? '')
    )));
  });
  return rows;
}

function parseYearField(jaar) {
  if (!jaar) return { type: 'unknown' };
  const t = String(jaar).trim();
  // look for range like "2021 - 2026" or "2021 - 2026"
  const rangeMatch = t.match(/(\d{4})\s*[-–]\s*(\d{4})/);
  if (rangeMatch) return { type: 'range', start: parseInt(rangeMatch[1], 10), end: parseInt(rangeMatch[2], 10) };
  const singleMatch = t.match(/^(\d{4})$/);
  if (singleMatch) return { type: 'single', year: parseInt(singleMatch[1], 10) };
  return { type: 'unknown' };
}

async function run() {
  try {
    const argPath = process.argv[2];
    const csvPath = argPath ? path.resolve(argPath) : path.resolve(__dirname, '..', '..', 'jap&gpp_data.csv');
    if (!fs.existsSync(csvPath)) {
      console.error('CSV file not found at', csvPath);
      process.exit(1);
    }

    console.log('Reading', csvPath);
    const workbook = new ExcelJS.Workbook();
    const ext = path.extname(csvPath).toLowerCase();

    if (ext === '.xlsx') {
      await workbook.xlsx.readFile(csvPath);
    } else if (ext === '.csv' || ext === '.tsv' || ext === '.txt') {
      const raw = fs.readFileSync(csvPath, 'utf8');
      await workbook.csv.readFile(csvPath, {
        parserOptions: {
          delimiter: pickDelimiter(raw),
        },
      });
    } else {
      throw new Error(`Unsupported import file extension: ${ext || 'none'}. Use .xlsx or .csv/.tsv.`);
    }

    const sheet = workbook.worksheets[0];
    if (!sheet) throw new Error('No worksheet found in import file.');
    const matrixRows = worksheetToRows(sheet);
    if (matrixRows.length === 0) throw new Error('No rows found in import file.');

    const [headerRow, ...dataRows] = matrixRows;
    const headers = headerRow.map((h) => String(h ?? '').trim());
    const rows = dataRows.map((dataRow) => (
      headers.reduce((acc, header, idx) => {
        acc[header] = dataRow[idx] ?? '';
        return acc;
      }, {})
    ));

    const toCreate = [];
    function cell(r, ...keys) {
      for (const k of keys) {
        if (k in r && r[k] !== undefined && r[k] !== null && String(r[k]).trim() !== '') return r[k];
      }
      return '';
    }

    for (const r of rows) {
      // normalize keys by trying multiple header variants
      const jaar = cell(r, 'Jaar', 'jaar', 'Jaar ');
      const doel = cell(r, 'Doelstelling - maatregel', 'Doelstelling - maatregel ', 'doelstelling', 'Doelstelling');
      const domain = cell(r, 'Domein', 'Domein ', 'domein');
      const risicoveld = cell(r, 'Risicoveld', 'Risico veld', 'Risico', 'risicoveld') || '';
      const prior = cell(r, 'Prioriteit (tijdsplanning)', 'Prioriteit', 'prioriteit') || '';
      const uitvoerder = cell(r, 'Uitvoerder', 'Verantwoordelijke', 'Verantwoordelijke ', 'uitvoerder', 'verantwoordelijke') || '';
      const middelen = cell(r, 'Middelen : \nBudget of werkuren', 'Middelen : Budget of werkuren', 'Middelen', 'middelen') || '';
      const startdatum = cell(r, 'Startdatum', 'startdatum') || '';
      const realisatie = cell(r, 'Realisatie', 'realisatie') || '';
      const einddatum = cell(r, 'Einddatum', 'einddatum') || '';
      const opmerkingen = cell(r, 'Opmerkingen', 'Opmerkingen ', 'opmerkingen') || '';

      if (!doel || String(doel).trim() === '') continue;

      const yf = parseYearField(jaar);
      if (yf.type === 'single') {
        toCreate.push({
          source: 'JAP',
          year: yf.year,
          startYear: null,
          endYear: null,
          goalMeasure: String(doel),
          domain: domain || null,
          riskField: risicoveld || null,
          resourcesBudget: middelen || null,
          priority: prior || null,
          realisation: realisatie || null,
          executor: uitvoerder || null,
          // ensure Date objects: prefer parsed cell dates, fallback to Jan 1 / Dec 31 of the year
          startDate: parseDate(startdatum) || new Date(yf.year, 0, 1),
          endDate: parseDate(einddatum) || new Date(yf.year, 11, 31),
          remark: opmerkingen || null,
        });
      } else if (yf.type === 'range') {
        toCreate.push({
          source: 'GPP',
          year: null,
          startYear: yf.start,
          endYear: yf.end,
          goalMeasure: String(doel),
          domain: domain || null,
          riskField: risicoveld || null,
          resourcesBudget: middelen || null,
          priority: prior || null,
          realisation: realisatie || null,
          executor: uitvoerder || null,
          // ensure Date objects: prefer parsed cell dates, fallback to year boundaries
          startDate: parseDate(startdatum) || new Date(yf.start, 0, 1),
          endDate: parseDate(einddatum) || new Date(yf.end, 11, 31),
          remark: opmerkingen || null,
        });
      } else {
        // unknown year format; treat as GPP-range fallback
        toCreate.push({
          source: 'GPP',
          year: null,
          startYear: null,
          endYear: null,
          goalMeasure: String(doel),
          domain: domain || null,
          riskField: risicoveld || null,
          resourcesBudget: middelen || null,
          priority: prior || null,
          realisation: realisatie || null,
          executor: uitvoerder || null,
          startDate: parseDate(startdatum) || null,
          endDate: parseDate(einddatum) || null,
          remark: opmerkingen || null,
        });
      }
    }

    console.log('Parsed rows:', toCreate.length);

    console.log('Clearing existing JapGppEntry rows...');
    await prisma.japGppEntry.deleteMany();

    console.log('Inserting rows...');
    // Prisma createMany expects dates in JS Date format; chunk if necessary
    const chunkSize = 500;
    for (let i = 0; i < toCreate.length; i += chunkSize) {
      const chunk = toCreate.slice(i, i + chunkSize);
      await prisma.japGppEntry.createMany({ data: chunk });
    }

    console.log('Done. Inserted', toCreate.length);
  } catch (err) {
    console.error('Error:', err);
  } finally {
    await prisma.$disconnect();
    await pool.end();
  }
}

run();
