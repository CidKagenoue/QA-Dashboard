import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';
import { PrismaModule } from '../prisma/prisma.module';
import { UserModule } from '../user/user.module';
import { GppController } from './gpp.controller';
import { JapGppAccessGuard } from './jap-gpp-access.guard';
import { JapController } from './jap.controller';

@Module({
  imports: [PrismaModule, NotificationsModule, UserModule],
  controllers: [JapController, GppController],
  providers: [JapGppAccessGuard],
})
export class JapGppModule {}
