import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { NotificationType } from '@prisma/client';
import { PrismaService } from 'src/prisma/prisma.service';
import { NotificationService } from 'src/notifications/notifications.service';
import {
  CreateMaintenanceInspectionDto,
  UpdateMaintenanceInspectionDto,
} from './dto/create_maintenance_inspection.dto';

interface MaintenanceInspectionRecord {
  id: number;
  equipment: string;
  inspectionType: string;
  inspectionInstitution: string;
  contactInfo: string | null;
  locationIds: number[];
  frequency: string;
  selfContact: boolean;
  lastInspectionDate: Date | null;
  dueDate: Date;
  status: string | null;
  notes: string | null;
  createdAt: Date;
  updatedAt: Date;
}

@Injectable()
export class MaintenanceInspectionsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationService: NotificationService,
  ) {}

  private get maintenanceInspectionModel(): any {
    return this.prisma as any;
  }

  async getFormData() {
    const branches = await this.prisma.branch.findMany({
      select: { id: true, name: true },
      orderBy: { name: 'asc' },
    });

    return { branches };
  }

  async findAll() {
    const [records, branches] = await Promise.all([
      this.maintenanceInspectionModel.maintenanceInspection.findMany({
        orderBy: [{ dueDate: 'asc' }, { id: 'desc' }],
      }),
      this.prisma.branch.findMany({
        select: { id: true, name: true },
      }),
    ]);

    const branchLookup = new Map(
      branches.map((branch) => [branch.id, branch.name]),
    );

    return records.map((record) => this.serialize(record, branchLookup));
  }

  async findOne(id: number) {
    const record = await this.maintenanceInspectionModel.maintenanceInspection.findUnique({
      where: { id },
    });
    if (!record) {
      throw new NotFoundException(`Onderhoud/keuring #${id} niet gevonden`);
    }

    const branches = await this.prisma.branch.findMany({
      select: { id: true, name: true },
    });

    const branchLookup = new Map(
      branches.map((branch) => [branch.id, branch.name]),
    );

    return this.serialize(record, branchLookup);
  }

  async create(dto: CreateMaintenanceInspectionDto) {
    const payload = await this.buildPayload(dto);
    const record = await this.maintenanceInspectionModel.maintenanceInspection.create({
      data: payload,
    });
    const branchLookup = await this.getLocationLookup();
    const serialized = this.serialize(record, branchLookup);
    await this.notifyMaintenanceCreated(serialized);
    return serialized;
  }

  async update(id: number, dto: UpdateMaintenanceInspectionDto) {
    await this.assertExists(id);
    const payload = await this.buildPayload(dto);
    const record = await this.maintenanceInspectionModel.maintenanceInspection.update({
      where: { id },
      data: payload,
    });
    return this.serialize(record, await this.getLocationLookup());
  }

  async remove(id: number) {
    await this.assertExists(id);
    return this.maintenanceInspectionModel.maintenanceInspection.delete({ where: { id } });
  }

  private async assertExists(id: number) {
    const existing = await this.maintenanceInspectionModel.maintenanceInspection.findUnique({
      where: { id },
      select: { id: true },
    });

    if (!existing) {
      throw new NotFoundException(`Onderhoud/keuring #${id} niet gevonden`);
    }
  }

  private async getLocationLookup() {
    const branches = await this.prisma.branch.findMany({
      select: { id: true, name: true },
    });

    return new Map(branches.map((branch) => [branch.id, branch.name]));
  }

  private async buildPayload(dto: CreateMaintenanceInspectionDto) {
    const equipment = dto.equipment?.trim() ?? '';
    const inspectionType = dto.inspectionType?.trim() ?? '';
    const inspectionInstitution = dto.inspectionInstitution?.trim() ?? '';
    const frequency = dto.frequency?.trim() ?? '';
    const dueDate = this.parseDate(dto.dueDate, 'dueDate');

    if (!equipment || !inspectionType || !inspectionInstitution || !frequency) {
      throw new BadRequestException('Verplichte velden ontbreken');
    }

    const locationIds = Array.isArray(dto.locationIds)
      ? dto.locationIds.filter((value) => Number.isInteger(value) && value > 0)
      : [];

    if (locationIds.length === 0) {
      throw new BadRequestException('Selecteer minstens één vestiging');
    }

    const existingBranches = await this.prisma.branch.findMany({
      where: { id: { in: locationIds } },
      select: { id: true },
    });
    const existingIds = new Set(existingBranches.map((branch) => branch.id));
    const missingIds = locationIds.filter((locationId) => !existingIds.has(locationId));

    if (missingIds.length > 0) {
      throw new BadRequestException(
        `Onbekende vestigingen geselecteerd: ${missingIds.join(', ')}`,
      );
    }

    return {
      equipment,
      inspectionType,
      inspectionInstitution,
      contactInfo: dto.contactInfo?.trim() || null,
      locationIds,
      frequency,
      selfContact: dto.selfContact ?? false,
      lastInspectionDate: this.parseDate(dto.lastInspectionDate, 'lastInspectionDate'),
      dueDate,
      status: dto.status?.trim() || 'Open',
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

  private serialize(
    record: MaintenanceInspectionRecord,
    branches: Map<number, string>,
  ) {
    return {
      id: record.id,
      equipment: record.equipment,
      inspectionType: record.inspectionType,
      inspectionInstitution: record.inspectionInstitution,
      contactInfo: record.contactInfo,
      locations: record.locationIds
        .map((locationId) => branches.get(locationId))
        .filter((branchName): branchName is string => Boolean(branchName)),
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
    locations: string[];
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
      title: 'Nieuwe onderhoud/keuring aangemaakt',
      body: `${record.equipment} (${record.inspectionType}) is aangemaakt voor ${record.locations.join(', ') || 'onbekende vestiging'} en is gepland tegen ${record.dueDate.toLocaleDateString('nl-BE')}.`,
      metadata: {
        maintenanceInspectionId: record.id,
        equipment: record.equipment,
        inspectionType: record.inspectionType,
        inspectionInstitution: record.inspectionInstitution,
        dueDate: record.dueDate,
        locations: record.locations,
      },
    });
  }
}
