import { Controller, Get, Param, Query, Res, UseGuards } from '@nestjs/common';
import { Response } from 'express';
import { PrismaService } from '../prisma/prisma.service';
import { JapGppAccessGuard } from './jap-gpp-access.guard';

@Controller('jap')
@UseGuards(JapGppAccessGuard)
export class JapController {
  constructor(private readonly prismaService: PrismaService) {}

  @Get()
  async listJapEntries(
    @Query('search') search: string | undefined,
    @Query('groupBy') groupBy: string | undefined,
    @Res() res: Response,
  ) {
    try {
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

      const entries = await this.prismaService.japGppEntry.findMany({
        where,
        include: {
          domain: true,
          comments: {
            orderBy: { createdAt: 'desc' },
          },
        },
        orderBy: { year: 'desc' },
      });

      const result = entries.map((entry) => this.formatJapEntry(entry));

      if (groupBy === 'year') {
        const groupsMap = new Map<number, any[]>();
        for (const entry of result) {
          const bucket = groupsMap.get(entry.jaar) ?? [];
          bucket.push(entry);
          groupsMap.set(entry.jaar, bucket);
        }
        const groups = Array.from(groupsMap.entries())
          .sort((a, b) => b[0] - a[0])
          .map(([year, groupedEntries]) => ({ year, entries: groupedEntries }));

        return res.json({ groups });
      }

      return res.json({ entries: result });
    } catch (error) {
      console.error('Error fetching JAP entries:', error);
      return res.status(500).json({ message: 'Fout bij ophalen JAP entries' });
    }
  }

  @Get('generated/:year')
  async generatedJapEntries(@Param('year') yearParam: string, @Res() res: Response) {
    try {
      const year = Number(yearParam);
      if (!Number.isInteger(year) || year < 1900 || year > 3000) {
        return res.status(400).json({ message: 'Ongeldig jaar' });
      }

      const gppEntries = await this.prismaService.japGppEntry.findMany({
        where: {
          source: 'GPP',
          startYear: { lte: year },
          endYear: { gte: year },
        },
        include: { domain: true, comments: true },
        orderBy: [{ startYear: 'desc' }, { id: 'desc' }],
      });

      const generated = gppEntries.map((entry: any) => ({
        id: -entry.id,
        jaar: year,
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
      }));

      return res.json({ entries: generated });
    } catch (error) {
      console.error('Error generating JAP entries for year:', error);
      return res.status(500).json({ message: 'Fout bij genereren JAP entries' });
    }
  }

  @Get('recent-comments')
  async recentComments(@Res() res: Response) {
    try {
      const japEntries = await this.prismaService.japGppEntry.findMany({
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

      const gppEntries = await this.prismaService.japGppEntry.findMany({
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
        .filter((entry) => entry.remark && entry.remark.trim() !== '')
        .map((entry) => ({
          id: entry.id,
          module: 'JAP' as const,
          title: entry.goalMeasure ?? '',
          author: entry.executor ?? '',
          comment: entry.remark ?? '',
        }));

      const gppWithRemarks = gppEntries
        .filter((entry) => entry.remark && entry.remark.trim() !== '')
        .map((entry) => ({
          id: entry.id,
          module: 'GPP' as const,
          title: entry.goalMeasure ?? '',
          author: entry.executor ?? '',
          comment: entry.remark ?? '',
        }));

      const combined = [...japWithRemarks, ...gppWithRemarks]
        .sort((a, b) => b.id - a.id)
        .slice(0, 3);

      return res.json({ comments: combined });
    } catch (error) {
      console.error('Error fetching recent comments:', error);
      return res.status(500).json({ message: 'Fout bij ophalen commentaar' });
    }
  }

  private formatJapEntry(entry: any) {
    return {
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
      comments: entry.comments?.map((comment: any) => ({
        id: comment.id,
        author: comment.author,
        text: comment.text,
        createdAt: comment.createdAt.toISOString(),
      })) ?? [],
    };
  }
}
