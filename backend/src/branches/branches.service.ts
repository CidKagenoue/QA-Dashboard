import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { Prisma } from "@prisma/client";
import { PrismaService } from "../prisma/prisma.service";
import { CreateBranchDto } from "./dto/create-branch.dto";

const BRANCH_INCLUDE = {
  departments: {
    include: {
      department: true,
    },
    orderBy: {
      department: {
        name: "asc",
      },
    },
  },
} satisfies Prisma.BranchInclude;

type BranchWithRelations = Prisma.BranchGetPayload<{
  include: typeof BRANCH_INCLUDE;
}>;

@Injectable()
export class BranchesService {
  constructor(private prisma: PrismaService) {}

  async findAll() {
    const branches = await this.prisma.branch.findMany({
      include: BRANCH_INCLUDE,
      orderBy: { name: "asc" },
    });
    return branches.map((branch) => this.serializeBranch(branch));
  }

  async findOne(id: number) {
    const branch = await this.prisma.branch.findUnique({
      where: { id },
      include: BRANCH_INCLUDE,
    });
    if (!branch) throw new NotFoundException(`Branch #${id} niet gevonden`);
    return this.serializeBranch(branch);
  }

  async create(dto: CreateBranchDto) {
    const departmentIds =
      dto.departmentIds === undefined
        ? await this.findAllDepartmentIds()
        : this.normalizeDepartmentIds(dto.departmentIds);
    await this.assertDepartmentsExist(departmentIds);

    const branch = await this.prisma.branch.create({
      data: {
        name: dto.name,
        departments: {
          create: departmentIds.map((departmentId) => ({ departmentId })),
        },
      },
      include: BRANCH_INCLUDE,
    });

    return this.serializeBranch(branch);
  }

  async update(id: number, dto: CreateBranchDto) {
    await this.findOne(id);
    const shouldSyncDepartments = dto.departmentIds !== undefined;
    const departmentIds = shouldSyncDepartments
      ? this.normalizeDepartmentIds(dto.departmentIds)
      : [];
    await this.assertDepartmentsExist(departmentIds);

    const branch = await this.prisma.$transaction(async (tx) => {
      if (shouldSyncDepartments) {
        await tx.branchDepartment.deleteMany({ where: { branchId: id } });
      }

      return tx.branch.update({
        where: { id },
        data: {
          name: dto.name,
          ...(shouldSyncDepartments
            ? {
                departments: {
                  create: departmentIds.map((departmentId) => ({
                    departmentId,
                  })),
                },
              }
            : {}),
        },
        include: BRANCH_INCLUDE,
      });
    });

    return this.serializeBranch(branch);
  }

  async remove(id: number) {
    await this.findOne(id);

    const maintenanceInspectionCount =
      await this.prisma.maintenanceInspectionBranch.count({
        where: { branchId: id },
      });
    if (maintenanceInspectionCount > 0) {
      throw new BadRequestException(
        "Vestiging kan niet verwijderd worden zolang ze aan onderhoud of keuringen gekoppeld is",
      );
    }

    return this.prisma.branch.delete({
      where: { id },
    });
  }

  private normalizeDepartmentIds(departmentIds?: number[]) {
    if (departmentIds === undefined) {
      return [];
    }

    if (!Array.isArray(departmentIds)) {
      throw new BadRequestException("departmentIds must be an array");
    }

    const uniqueDepartmentIds = Array.from(new Set(departmentIds));
    if (uniqueDepartmentIds.some((id) => !Number.isInteger(id) || id <= 0)) {
      throw new BadRequestException(
        "departmentIds must contain positive integers",
      );
    }

    return uniqueDepartmentIds;
  }

  private async findAllDepartmentIds() {
    const departments = await this.prisma.department.findMany({
      where: {
        name: {
          not: "Ander",
          mode: Prisma.QueryMode.insensitive,
        },
      },
      select: {
        id: true,
      },
    });

    return departments.map((department) => department.id);
  }

  private async assertDepartmentsExist(departmentIds: number[]) {
    if (departmentIds.length === 0) {
      return;
    }

    const count = await this.prisma.department.count({
      where: {
        id: {
          in: departmentIds,
        },
      },
    });

    if (count !== departmentIds.length) {
      throw new BadRequestException("One or more departments do not exist");
    }
  }

  private serializeBranch(branch: BranchWithRelations) {
    const departments = branch.departments.map((link) => link.department);

    return {
      id: branch.id,
      name: branch.name,
      createdAt: branch.createdAt,
      departmentIds: departments.map((department) => department.id),
      departments,
    };
  }
}
