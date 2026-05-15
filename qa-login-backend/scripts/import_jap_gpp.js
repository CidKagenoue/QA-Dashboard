const fs = require('fs');
const path = require('path');
const XLSX = require('xlsx');
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

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
    for (const r of rows) {
      // normalize keys by trimming
      const jaar = r['Jaar'] ?? r['jaar'] ?? r['Jaar '];
      const doel = r['Doelstelling - maatregel'] ?? r['Doelstelling - maatregel'] ?? r['Doelstelling - maatregel '];
      const domain = r['Domein'] ?? r['Domein '];
      const risicoveld = r['Risicoveld'] ?? '';
      const prior = r['Prioriteit (tijdsplanning)'] ?? r['Prioriteit'] ?? '';
      const uitvoerder = r['Uitvoerder'] ?? '';
      const middelen = r['Middelen : \nBudget of werkuren'] ?? r['Middelen : \nBudget of werkuren'] ?? r['Middelen : Budget of werkuren'] ?? '';
      const startdatum = r['Startdatum'] ?? '';
      const realisatie = r['Realisatie'] ?? '';
      const einddatum = r['Einddatum'] ?? '';
      const opmerkingen = r['Opmerkingen'] ?? '';

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
  }
}

run();
