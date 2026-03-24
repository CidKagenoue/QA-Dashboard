import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

export const managedAccountSelect = {
  id: true,
  email: true,
  name: true,
  isAdmin: true,
  basisAccess: true,
  whsToursAccess: true,
  ovaAccess: true,
  japGppAccess: true,
  maintenanceInspectionsAccess: true,
} satisfies Prisma.UserSelect;

export type ManagedAccount = Prisma.UserGetPayload<{
  select: typeof managedAccountSelect;
}>;

@Injectable()
export class UserService {
  constructor(private prisma: PrismaService) {}

  async create(data: Prisma.UserCreateInput) {
    return this.prisma.user.create({ data });
  }

  async findByEmail(email: string) {
    return this.prisma.user.findUnique({ where: { email } });
  }

  async findById(id: number) {
    return this.prisma.user.findUnique({ where: { id } });
  }

  async countUsers() {
    return this.prisma.user.count();
  }

  async countAdmins(excludeUserId?: number) {
    return this.prisma.user.count({
      where: {
        isAdmin: true,
        ...(excludeUserId ? { id: { not: excludeUserId } } : {}),
      },
    });
  }

  async findManagedById(id: number) {
    return this.prisma.user.findUnique({
      where: { id },
      select: managedAccountSelect,
    });
  }

  async findManagedByEmail(email: string) {
    return this.prisma.user.findUnique({
      where: { email },
      select: managedAccountSelect,
    });
  }

  async listManagedAccounts(search?: string) {
    const where = search
      ? {
          OR: [
            { email: { contains: search, mode: Prisma.QueryMode.insensitive } },
            { name: { contains: search, mode: Prisma.QueryMode.insensitive } },
          ],
        }
      : undefined;

    const users = await this.prisma.user.findMany({
      where,
      select: managedAccountSelect,
    });

    return users.sort((left, right) => {
      const leftLabel = left.name?.trim().toLowerCase() || left.email.toLowerCase();
      const rightLabel = right.name?.trim().toLowerCase() || right.email.toLowerCase();

      return leftLabel.localeCompare(rightLabel) || left.email.localeCompare(right.email);
    });
  }

  async createManagedAccount(data: Prisma.UserCreateInput) {
    return this.prisma.user.create({
      data,
      select: managedAccountSelect,
    });
  }

  async updateManagedAccount(id: number, data: Prisma.UserUpdateInput) {
    return this.prisma.user.update({
      where: { id },
      data,
      select: managedAccountSelect,
    });
  }

  async deleteManagedAccount(id: number) {
    return this.prisma.user.delete({
      where: { id },
      select: managedAccountSelect,
    });
  }
}
