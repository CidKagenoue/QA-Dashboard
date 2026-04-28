import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { NotificationSettingsModule } from '../notification-settings/notification-settings.module';
import { NotificationService } from './notifications.service';
import { NotificationsController } from './notifications.controller';

@Module({
  imports: [PrismaModule, NotificationSettingsModule],
  controllers: [NotificationsController],
  providers: [NotificationService],
  exports: [NotificationService],
})
export class NotificationsModule {}
