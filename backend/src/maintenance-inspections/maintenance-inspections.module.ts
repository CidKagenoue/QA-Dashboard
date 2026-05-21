import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { UserModule } from '../user/user.module';
import { MaintenanceInspectionsController } from './maintenance-inspections.controller';
import { MaintenanceInspectionsService } from './maintenance-inspections.service';
import { MaintenanceDeadlineJob } from './maintenance-due.job';

@Module({
  imports: [PrismaModule, UserModule, NotificationsModule],
  controllers: [MaintenanceInspectionsController],
  providers: [MaintenanceInspectionsService, MaintenanceDeadlineJob],
})
export class MaintenanceInspectionsModule {}