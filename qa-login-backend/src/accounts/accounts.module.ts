import { Module } from '@nestjs/common';
import { AccountsController } from './accounts.controller';
import { AccountsService } from './accounts.service';
import { AdminGuard } from './admin.guard';
import { NotificationsModule } from '../notifications/notifications.module';
import { PrismaModule } from '../prisma/prisma.module';
import { UserModule } from '../user/user.module';

@Module({
  imports: [UserModule, PrismaModule, NotificationsModule],
  controllers: [AccountsController],
  providers: [AccountsService, AdminGuard],
})
export class AccountsModule {}
