import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { NotificationType, Prisma } from "@prisma/client";
import { PrismaService } from "../prisma/prisma.service";
import { NotificationService } from "../notifications/notifications.service";
import {
  CreateMaintenanceInspectionDto,
  UpdateMaintenanceInspectionDto,
} from "./dto/create_maintenance_inspection.dto";

const MAINTENANCE_INCLUDE = {
  branches: {
    include: {
      branch: true,
    },
    orderBy: {
      branch: {
        name: "asc",
      },
    },
  },
} satisfies Prisma.MaintenanceInspectionInclude;

type MaintenanceInspectionWithBranches =
  Prisma.MaintenanceInspectionGetPayload<{
    include: typeof MAINTENANCE_INCLUDE;
  }>;

@Injectable()
export class MaintenanceInspectionsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationService: NotificationService,
  ) {}

  async getFormData() {
    const branches = await this.prisma.branch.findMany({
      select: { id: true, name: true },
      orderBy: { name: "asc" },
    });

    return { branches };
  }

  async findAll() {
    const records = await this.prisma.maintenanceInspection.findMany({
      include: MAINTENANCE_INCLUDE,
      orderBy: [{ dueDate: "asc" }, { id: "desc" }],
    });

    return records.map((record) => this.serialize(record));
  }

  async findOne(id: number) {
    const record = await this.prisma.maintenanceInspection.findUnique({
      where: { id },
      include: MAINTENANCE_INCLUDE,
    });
    if (!record) {
      throw new NotFoundException(`Onderhoud/keuring #${id} niet gevonden`);
    }

    return this.serialize(record);
  }

  async create(dto: CreateMaintenanceInspectionDto) {
    const { branchIds, ...payload } = await this.buildPayload(dto);
    const record = await this.prisma.maintenanceInspection.create({
      data: {
        ...payload,
        branches: {
          create: branchIds.map((branchId) => ({ branchId })),
        },
      },
      include: MAINTENANCE_INCLUDE,
    });
    const serialized = this.serialize(record);
    await this.notifyMaintenanceCreated(serialized);
    return serialized;
  }

  async update(id: number, dto: UpdateMaintenanceInspectionDto) {
    await this.assertExists(id);
    const { branchIds, ...payload } = await this.buildPayload(dto);
    const record = await this.prisma.maintenanceInspection.update({
      where: { id },
      data: {
        ...payload,
        branches: {
          deleteMany: {},
          create: branchIds.map((branchId) => ({ branchId })),
        },
      },
      include: MAINTENANCE_INCLUDE,
    });
    return this.serialize(record);
  }

  async remove(id: number) {
    await this.assertExists(id);
    return this.prisma.maintenanceInspection.delete({
      where: { id },
    });
  }

  async findUpcoming(limit = 20) {
    const now = new Date();
    now.setHours(0, 0, 0, 0);
    const cutoff = new Date(now);
    cutoff.setDate(cutoff.getDate() + 30);

    const records = await this.prisma.maintenanceInspection.findMany({
      where: {
        dueDate: { lte: cutoff },
        NOT: { status: "Closed" },
      },
      include: MAINTENANCE_INCLUDE,
      orderBy: { dueDate: "asc" },
      take: limit,
    });

    return records.map((record) => ({
      id: record.id,
      equipment: record.equipment,
      dueDate: record.dueDate,
      branches: record.branches.map((link) => link.branch.name),
    }));
  }

  private async assertExists(id: number) {
    const existing = await this.prisma.maintenanceInspection.findUnique({
      where: { id },
      select: { id: true },
    });

    if (!existing) {
      throw new NotFoundException(`Onderhoud/keuring #${id} niet gevonden`);
    }
  }

  private async buildPayload(dto: CreateMaintenanceInspectionDto) {
    const equipment = dto.equipment?.trim() ?? "";
    const inspectionType = dto.inspectionType?.trim() ?? "";
    const inspectionInstitution = dto.inspectionInstitution?.trim() ?? "";
    const frequency = dto.frequency?.trim() ?? "";
    const dueDate = this.parseDate(dto.dueDate, "dueDate");
    let dueDateComputed: Date | null = dueDate;
    if (!dueDateComputed) {
      const last = this.parseDate(dto.lastInspectionDate, "lastInspectionDate");
      const numMatch = (frequency.match(/(\d+)/) || [null])[0];
      const yearsToAdd = numMatch ? Math.max(1, parseInt(numMatch, 10)) : 1;
      const base = last ?? new Date();
      dueDateComputed = new Date(base);
      dueDateComputed.setFullYear(dueDateComputed.getFullYear() + yearsToAdd);
    }

    if (!equipment || !inspectionType || !inspectionInstitution || !frequency) {
      throw new BadRequestException("Verplichte velden ontbreken");
    }

    const branchIds = Array.from(
      new Set(
        Array.isArray(dto.branchIds)
          ? dto.branchIds.filter(
              (value) => Number.isInteger(value) && value > 0,
            )
          : [],
      ),
    );

    if (branchIds.length === 0) {
      throw new BadRequestException("Selecteer minstens een vestiging");
    }

    const existingBranches = await this.prisma.branch.findMany({
      where: { id: { in: branchIds } },
      select: { id: true },
    });
    const existingIds = new Set(existingBranches.map((branch) => branch.id));
    const missingIds = branchIds.filter(
      (branchId) => !existingIds.has(branchId),
    );

    if (missingIds.length > 0) {
      throw new BadRequestException(
        `Onbekende vestigingen geselecteerd: ${missingIds.join(", ")}`,
      );
    }

    return {
      equipment,
      inspectionType,
      inspectionInstitution,
      contactInfo: dto.contactInfo?.trim() || null,
      branchIds,
      frequency,
      selfContact: dto.selfContact ?? false,
      lastInspectionDate: this.parseDate(
        dto.lastInspectionDate,
        "lastInspectionDate",
      ),
      dueDate: dueDateComputed,
      status: dto.status?.trim() || null,
      notes: dto.notes?.trim() || null,
    };
  }

  private parseDate(value: string | null | undefined, field: string) {
    if (!value) {
      return null;
    }

    const parsed = new Date(value);
    if (Number.isNaN(parsed.getTime())) {
      throw new BadRequestException(`Ongeldige datum voor ${field}`);
    }

    return parsed;
  }

  private serialize(record: MaintenanceInspectionWithBranches) {
    return {
      id: record.id,
      equipment: record.equipment,
      inspectionType: record.inspectionType,
      inspectionInstitution: record.inspectionInstitution,
      contactInfo: record.contactInfo,
      branches: record.branches.map((link) => link.branch.name),
      frequency: record.frequency,
      selfContact: record.selfContact,
      lastInspectionDate: record.lastInspectionDate,
      dueDate: record.dueDate,
      status: record.status,
      notes: record.notes,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    };
  }

  private async notifyMaintenanceCreated(record: {
    id: number;
    equipment: string;
    inspectionType: string;
    inspectionInstitution: string;
    branches: string[];
    dueDate: Date;
  }) {
    const recipients = await this.prisma.user.findMany({
      where: {
        OR: [{ isAdmin: true }, { maintenanceInspectionsAccess: true }],
      },
      select: { id: true },
    });

    await this.notificationService.notifyUsers({
      recipientUserIds: recipients.map((user) => user.id),
      type: NotificationType.MAINTENANCE_NEW,
      title: "Nieuwe onderhoud/keuring aangemaakt",
      body: `${record.equipment} (${record.inspectionType}) is aangemaakt voor ${record.branches.join(", ") || "onbekende vestiging"} en is gepland tegen ${record.dueDate.toLocaleDateString("nl-BE")}.`,
      metadata: {
        maintenanceInspectionId: record.id,
        equipment: record.equipment,
        inspectionType: record.inspectionType,
        inspectionInstitution: record.inspectionInstitution,
        dueDate: record.dueDate,
        branches: record.branches,
      },
    });
  }
}
