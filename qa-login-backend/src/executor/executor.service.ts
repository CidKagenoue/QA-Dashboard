import { Injectable, NotFoundException, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ExecutorService implements OnModuleInit {
  constructor(private prisma: PrismaService) {}

  async onModuleInit() {
    await this.seedFromEntries();
  }

  private async seedFromEntries() {
    const entries = await this.prisma.japGppEntry.findMany({
      select: { executor: true },
    });

    const names = new Set<string>();
    for (const entry of entries) {
      const name = String(entry.executor ?? '').trim();
      if (name) {
        names.add(name);
      }
    }

    for (const name of names) {
      await this.prisma.executor.upsert({
        where: { name },
        create: { name },
        update: {},
      });
    }
  }

  async findAll() {
    return this.prisma.executor.findMany({
      orderBy: { name: 'asc' },
    });
  }

  async create(name: string) {
    return this.prisma.executor.create({
      data: { name },
    });
  }

  async deleteByName(name: string) {
    const executor = await this.prisma.executor.findUnique({
      where: { name },
    });

    if (!executor) {
      throw new NotFoundException('Executor not found');
    }

    return this.prisma.executor.delete({
      where: { name },
    });
  }
}