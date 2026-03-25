import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from 'src/prisma/prisma.service';
import { CreateBranchDto } from './dto/create_branches.dto';

@Injectable()
export class BranchesService {
  constructor(private prisma: PrismaService) {}

  findAll() {
    // Gebruik 'branch' (enkelvoud) zoals gedefinieerd in je Prisma schema
    return this.prisma.branch.findMany({
      include: { locations: true },
      orderBy: { name: 'asc' },
    });
  }

  async findOne(id: number) {
    const branch = await this.prisma.branch.findUnique({
      where: { id },
      include: { locations: true },
    });
    if (!branch) throw new NotFoundException(`Branch #${id} niet gevonden`);
    return branch;
  }

  create(dto: CreateBranchDto) {
    return this.prisma.branch.create({
      data: { name: dto.name },
      include: { locations: true },
    });
  }

  async update(id: number, dto: CreateBranchDto) {
    await this.findOne(id);
    return this.prisma.branch.update({
      where: { id },
      data: { name: dto.name },
      include: { locations: true },
    });
  }

  async remove(id: number) {
    await this.findOne(id);
    return this.prisma.branch.delete({ 
      where: { id } 
    });
  }
}