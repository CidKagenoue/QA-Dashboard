import { Module } from '@nestjs/common';
import { PrismaModule } from 'src/prisma/prisma.module';
import { NotificationsModule } from 'src/notifications/notifications.module';
import { UserModule } from 'src/user/user.module';
import { MaintenanceInspectionsController } from './maintenance-inspections.controller';
import { MaintenanceInspectionsService } from './maintenance-inspections.service';
import { MaintenanceDeadlineJob } from './maintenance-due.job';

@Module({
  imports: [PrismaModule, UserModule, NotificationsModule],
  controllers: [MaintenanceInspectionsController],
  providers: [MaintenanceInspectionsService, MaintenanceDeadlineJob],
})
export class MaintenanceInspectionsModule {}
