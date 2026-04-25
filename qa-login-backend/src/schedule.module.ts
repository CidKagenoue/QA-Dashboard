import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { OvaDeadlineJob } from './ova/ova-deadline.job';
import { PrismaModule } from './prisma/prisma.module';
import { NotificationsModule } from './notifications/notifications.module';

@Module({
  imports: [ScheduleModule.forRoot(), PrismaModule, NotificationsModule],
  providers: [OvaDeadlineJob],
})
export class CustomScheduleModule {}
