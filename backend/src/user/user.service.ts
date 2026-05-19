import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateUserDto } from './dto/update-user.dto';

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
  profileImage: true, // <-- profielfoto wordt nu meegegeven
  departments: {
    select: {
      department: {
        select: {
          id: true,
          name: true,
        },
      },
    },
  },
} satisfies Prisma.UserSelect;

export type ManagedAccount = Prisma.UserGetPayload<{
  select: typeof managedAccountSelect;
}>;

export const assignableOvaUserSelect = {
  id: true,
  email: true,
  name: true,
} satisfies Prisma.UserSelect;

export type AssignableOvaUser = Prisma.UserGetPayload<{
  select: typeof assignableOvaUserSelect;
}>;

@Injectable()
export class UserService {
  constructor(private readonly prisma: PrismaService) {}

  async create(data: Prisma.UserCreateInput) {
    if (typeof data.email === 'string') {
      data.email = this.normalizeEmail(data.email);
    }

    return this.prisma.user.create({ data });
  }

  async findByEmail(email: string) {
    const normalizedEmail = this.normalizeEmail(email);
    return this.prisma.user.findFirst({
      where: {
        email: {
          equals: normalizedEmail,
          mode: 'insensitive',
        },
      },
    });
  }

  async findById(id: number) {
    return this.prisma.user.findUnique({ where: { id } });
  }

  async update(id: number, data: Prisma.UserUpdateInput | UpdateUserDto) {
    // Check of departmentIds is meegegeven (voor PATCH vanuit frontend)
    let departmentIds: number[] | undefined = undefined;
    let dataCopy: any = { ...data };
    if ('departmentIds' in dataCopy && Array.isArray(dataCopy.departmentIds)) {
      departmentIds = dataCopy.departmentIds;
      delete dataCopy.departmentIds;
    }

    const updatedUser = await this.prisma.user.update({
      where: { id },
      data: this.normalizeUserUpdateInput(dataCopy),
      select: managedAccountSelect,
    });

    // Indien departmentIds meegegeven, update de UserDepartment-relaties
    if (departmentIds) {
      // Verwijder bestaande koppelingen
      await this.prisma.userDepartment.deleteMany({ where: { userId: id } });
      // Voeg nieuwe koppelingen toe
      await Promise.all(
        departmentIds.map(departmentId =>
          this.prisma.userDepartment.create({
            data: { userId: id, departmentId },
          })
        )
      );
    }

    // Geef de user terug met de nieuwe afdelingen
    return this.prisma.user.findUnique({
      where: { id },
      select: managedAccountSelect,
    });
  }

  async findAll() {
    return this.prisma.user.findMany({
      select: managedAccountSelect,
    });
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
    const normalizedEmail = this.normalizeEmail(email);
    return this.prisma.user.findFirst({
      where: {
        email: {
          equals: normalizedEmail,
          mode: Prisma.QueryMode.insensitive,
        },
      },
      select: managedAccountSelect,
    });
  }

  async listManagedAccounts(search?: string) {
    const normalizedSearch = search?.trim();
    const where = normalizedSearch
      ? {
          OR: [
            {
              email: {
                contains: normalizedSearch,
                mode: Prisma.QueryMode.insensitive,
              },
            },
            {
              name: {
                contains: normalizedSearch,
                mode: Prisma.QueryMode.insensitive,
              },
            },
          ],
        }
      : undefined;

    const users = await this.prisma.user.findMany({
      where,
      select: managedAccountSelect,
    });

    return users.sort((left, right) => {
      const leftLabel =
        left.name?.trim().toLowerCase() || left.email.toLowerCase();
      const rightLabel =
        right.name?.trim().toLowerCase() || right.email.toLowerCase();

      return (
        leftLabel.localeCompare(rightLabel) ||
        left.email.localeCompare(right.email)
      );
    });
  }

  async listAssignableOvaUsers() {
    const users = await this.prisma.user.findMany({
      select: assignableOvaUserSelect,
    });

    return users.sort((left, right) => {
      const leftLabel =
        left.name?.trim().toLowerCase() || left.email.toLowerCase();
      const rightLabel =
        right.name?.trim().toLowerCase() || right.email.toLowerCase();

      return (
        leftLabel.localeCompare(rightLabel) ||
        left.email.localeCompare(right.email)
      );
    });
  }

  async createManagedAccount(data: Prisma.UserCreateInput) {
    if (typeof data.email === 'string') {
      data.email = this.normalizeEmail(data.email);
    }

    return this.prisma.user.create({
      data,
      select: managedAccountSelect,
    });
  }

  async updateManagedAccount(id: number, data: Prisma.UserUpdateInput) {
    return this.prisma.user.update({
      where: { id },
      data: this.normalizeUserUpdateInput(data),
      select: managedAccountSelect,
    });
  }

  async deleteManagedAccount(id: number) {
    return this.prisma.user.delete({
      where: { id },
      select: managedAccountSelect,
    });
  }

  private normalizeEmail(email: string) {
    return email.trim().toLowerCase();
  }

  private normalizeUserUpdateInput(data: Prisma.UserUpdateInput) {
    const email = data.email;
    if (typeof email === 'string') {
      return {
        ...data,
        email: this.normalizeEmail(email),
      };
    }

    if (
      email &&
      typeof email === 'object' &&
      'set' in email &&
      typeof email.set === 'string'
    ) {
      return {
        ...data,
        email: {
          ...email,
          set: this.normalizeEmail(email.set),
        },
      };
    }

    return data;
  }
}
