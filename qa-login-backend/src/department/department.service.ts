// src/department/department.service.ts
import { Injectable, NotFoundException } from '@nestjs/common';
import { CreateDepartmentDto, UpdateDepartmentDto } from './department.dto';
import { PrismaService } from 'src/prisma/prisma.service';

@Injectable()
export class DepartmentService {
  constructor(private prisma: PrismaService) {}

  findAll() {
    return this.prisma.department.findMany({
      include: {
        leaders: {
          include: { user: true },
        },
      },
      orderBy: { name: 'asc' },
    });
  }

  async create(data: CreateDepartmentDto) {
    return this.prisma.department.create({
      data: {
        name: data.name,
        leaders: {
          create: data.leaderIds.map((userId) => ({ userId })),
        },
      },
      include: {
        leaders: { include: { user: true } },
      },
    });
  }

  async update(id: number, data: UpdateDepartmentDto) {
    const existing = await this.prisma.department.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Department not found');

    // eenvoudige aanpak: eerst alle leaders weg, dan opnieuw aanmaken
    return this.prisma.$transaction(async (tx) => {
      await tx.departmentLeader.deleteMany({ where: { departmentId: id } });

      return tx.department.update({
        where: { id },
        data: {
          name: data.name ?? existing.name,
          leaders: data.leaderIds
            ? {
                create: data.leaderIds.map((userId) => ({ userId })),
              }
            : undefined,
        },
        include: {
          leaders: { include: { user: true } },
        },
      });
    });
  }

  async remove(id: number) {
    await this.prisma.departmentLeader.deleteMany({ where: { departmentId: id } });
    return this.prisma.department.delete({ where: { id } });
  }
}
