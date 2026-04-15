import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { UserModule } from '../user/user.module';
import { OvaController } from './ova.controller';
import { OvaService } from './ova.service';

@Module({
  imports: [PrismaModule, UserModule, NotificationsModule],
  controllers: [OvaController],
  providers: [OvaService],
})
export class OvaModule {}
