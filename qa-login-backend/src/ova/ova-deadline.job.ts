import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationService } from '../notifications/notifications.service';
import { NotificationType } from '@prisma/client';

@Injectable()
export class OvaDeadlineJob {
  private readonly logger = new Logger(OvaDeadlineJob.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationService: NotificationService,
  ) {}

  // Dagelijks om 8:00 uitvoeren
  @Cron(CronExpression.EVERY_DAY_AT_8AM)
  async handleDeadlineReminders() {
    const twoDaysFromNow = new Date();
    twoDaysFromNow.setDate(twoDaysFromNow.getDate() + 2);
    twoDaysFromNow.setHours(0, 0, 0, 0);

    const nextDay = new Date(twoDaysFromNow);
    nextDay.setDate(nextDay.getDate() + 1);

    // Zoek alle opvolgacties met deadline over 2 dagen, status niet OK, en interne verantwoordelijke
    const actions = await this.prisma.ovaFollowUpAction.findMany({
      where: {
        dueDate: {
          gte: twoDaysFromNow,
          lt: nextDay,
        },
        status: { not: 'ok' },
        assigneeType: 'internal',
        internalAssigneeId: { not: null },
      },
      select: {
        id: true,
        description: true,
        type: true,
        dueDate: true,
        internalAssigneeId: true,
        ticketId: true,
      },
    });

    for (const action of actions) {
      await this.notificationService.notifyUser({
        recipientUserId: action.internalAssigneeId!,
        type: NotificationType.OVA_DEADLINE,
        title: 'Opvolgactie nadert deadline',
        body: `De deadline voor opvolgactie "${action.description}" (type: ${action.type}) op ticket #${action.ticketId} is over 2 dagen: ${action.dueDate.toLocaleDateString('nl-BE')}.`,
        metadata: {
          actionId: action.id,
          ticketId: action.ticketId,
          dueDate: action.dueDate,
        },
      });
    }

    this.logger.log(`Verstuurde ${actions.length} deadline herinneringen voor opvolgacties.`);
  }
}
