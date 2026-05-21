import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';
import { PrismaModule } from '../prisma/prisma.module';
import { GppController } from './gpp.controller';
import { JapController } from './jap.controller';

@Module({
  imports: [PrismaModule, NotificationsModule],
  controllers: [JapController, GppController],
})
export class JapGppModule {}