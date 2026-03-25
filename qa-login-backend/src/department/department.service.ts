// src/departments/departments.service.ts
import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateDepartmentDto } from './dto/update_department.dto';
import { CreateDepartmentDto } from './dto/create_department.dto';

const INCLUDE = {
  leaders: {
    include: {
      user: {
        select: { id: true, email: true, name: true },
      },
    },
  },
};

@Injectable()
export class DepartmentsService {
  constructor(private prisma: PrismaService) {}

  findAll() {
    return this.prisma.department.findMany({
      orderBy: { name: 'asc' },
      include: INCLUDE,
    });
  }

  async findOne(id: number) {
    const dept = await this.prisma.department.findUnique({
      where: { id },
      include: INCLUDE,
    });
    if (!dept) throw new NotFoundException(`Afdeling ${id} niet gevonden`);
    return dept;
  }

  async create(dto: CreateDepartmentDto) {
    return this.prisma.department.create({
      data: {
        name: dto.name,
        leaders: {
          create: (dto.leaderIds ?? []).map((userId) => ({ userId })),
        },
      },
      include: INCLUDE,
    });
  }

  async update(id: number, dto: UpdateDepartmentDto) {
    await this.findOne(id); // gooit 404 als niet bestaat

    // Verwijder alle bestaande koppelingen en maak nieuwe aan
    await this.prisma.departmentLeader.deleteMany({ where: { departmentId: id } });

    return this.prisma.department.update({
      where: { id },
      data: {
        name: dto.name,
        leaders: {
          create: (dto.leaderIds ?? []).map((userId) => ({ userId })),
        },
      },
      include: INCLUDE,
    });
  }

  async remove(id: number) {
    await this.findOne(id);
    // Cascade via Prisma schema; anders eerst leaders verwijderen
    await this.prisma.departmentLeader.deleteMany({ where: { departmentId: id } });
    return this.prisma.department.delete({ where: { id } });
  }
}