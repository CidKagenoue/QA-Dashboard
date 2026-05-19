require('dotenv/config');

const fs = require('fs');
const path = require('path');
const XLSX = require('xlsx');
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
    const workbook = XLSX.readFile(csvPath, { raw: false });
    const sheet = workbook.Sheets[workbook.SheetNames[0]];
    const rows = XLSX.utils.sheet_to_json(sheet, { defval: '' });

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
