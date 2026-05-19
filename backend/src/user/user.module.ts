import { Module } from '@nestjs/common';
import { AdminGuard } from '../accounts/admin.guard';
import { UserService } from './user.service';
import { UserController } from './user.controller';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [UserController],
  providers: [UserService, AdminGuard],
  exports: [UserService],
})
export class UserModule {}
