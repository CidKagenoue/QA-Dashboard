import { Module } from '@nestjs/common';
import { AccountsController } from './accounts.controller';
import { AccountsService } from './accounts.service';
import { AdminGuard } from './admin.guard';
import { PrismaModule } from '../prisma/prisma.module';
import { UserModule } from '../user/user.module';

@Module({
  imports: [UserModule, PrismaModule],
  controllers: [AccountsController],
  providers: [AccountsService, AdminGuard],
})
export class AccountsModule {}
