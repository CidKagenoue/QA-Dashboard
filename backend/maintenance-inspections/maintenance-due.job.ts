import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { NotificationType } from '@prisma/client';
import { PrismaService } from 'src/prisma/prisma.service';
import { NotificationService } from 'src/notifications/notifications.service';

@Injectable()
export class MaintenanceDeadlineJob {
  private readonly logger = new Logger(MaintenanceDeadlineJob.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationService: NotificationService,
  ) {}

  @Cron(CronExpression.EVERY_DAY_AT_8AM)
  async handleDeadlineReminders() {
    const twoDaysFromNow = new Date();
    twoDaysFromNow.setDate(twoDaysFromNow.getDate() + 2);
    twoDaysFromNow.setHours(0, 0, 0, 0);

    const nextDay = new Date(twoDaysFromNow);
    nextDay.setDate(nextDay.getDate() + 1);

    const inspections = await this.prisma.maintenanceInspection.findMany({
      where: {
        dueDate: {
          gte: twoDaysFromNow,
          lt: nextDay,
        },
        status: { not: 'Closed' },
      },
      select: {
        id: true,
        equipment: true,
        inspectionType: true,
        dueDate: true,
        locationIds: true,
      },
    });

    if (inspections.length === 0) {
      this.logger.log('Geen naderende onderhouds- of keuringsdeadlines gevonden.');
      return;
    }

    const branches = await this.prisma.branch.findMany({
      select: { id: true, name: true },
    });
    const branchLookup = new Map(branches.map((branch) => [branch.id, branch.name]));

    const recipients = await this.prisma.user.findMany({
      where: {
        OR: [{ isAdmin: true }, { maintenanceInspectionsAccess: true }],
      },
      select: { id: true },
    });

    const recipientUserIds = recipients.map((user) => user.id);
    if (recipientUserIds.length === 0) {
      this.logger.warn('Geen ontvangers met onderhoudstoegang gevonden voor deadline-notificaties.');
      return;
    }

    for (const inspection of inspections) {
      const locations = inspection.locationIds
        .map((locationId) => branchLookup.get(locationId))
        .filter((location): location is string => Boolean(location));

      await this.notificationService.notifyUsers({
        recipientUserIds,
        type: NotificationType.MAINTENANCE_DUE,
        title: 'Onderhouds- of keuringsdeadline nadert',
        body: `${inspection.equipment} (${inspection.inspectionType}) voor ${locations.join(', ') || 'onbekende vestiging'} vervalt op ${inspection.dueDate.toLocaleDateString('nl-BE')}.`,
        metadata: {
          maintenanceInspectionId: inspection.id,
          equipment: inspection.equipment,
          inspectionType: inspection.inspectionType,
          dueDate: inspection.dueDate,
          locations,
        },
      });
    }

    this.logger.log(`Verstuurde ${inspections.length} onderhoudsdeadline-herinneringen.`);
  }
}