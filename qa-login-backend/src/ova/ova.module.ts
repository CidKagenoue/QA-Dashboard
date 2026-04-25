
import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { UserModule } from '../user/user.module';
import { OvaController } from './ova.controller';
import { OvaService } from './ova.service';
import { NotificationSettingsModule } from '../notification-settings/notification-settings.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [PrismaModule, UserModule, NotificationSettingsModule, NotificationsModule],
  controllers: [OvaController],
  providers: [OvaService],
})
export class OvaModule {}
