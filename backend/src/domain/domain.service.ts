import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class DomainService {
  constructor(private prisma: PrismaService) {}

  async findAll() {
    return this.prisma.domain.findMany({
      orderBy: { name: 'asc' },
    });
  }

  async findById(id: number) {
    return this.prisma.domain.findUnique({
      where: { id },
    });
  }

  async create(name: string) {
    return this.prisma.domain.create({
      data: { name },
    });
  }

  async delete(id: number) {
    const domain = await this.prisma.domain.findUnique({
      where: { id },
    });

    if (!domain) {
      throw new NotFoundException('Domain not found');
    }

    return this.prisma.$transaction(async (tx) => {
      await tx.japGppEntry.updateMany({
        where: { domainId: id },
        data: { domainId: null },
      });

      return tx.domain.delete({
        where: { id },
      });
    });
  }
}
