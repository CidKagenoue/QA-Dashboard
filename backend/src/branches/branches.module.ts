import { Module } from '@nestjs/common';
import { AdminGuard } from '../accounts/admin.guard';
import { BranchesService } from './branches.service';
import { BranchesController } from './branches.controller';
import { PrismaModule } from '../prisma/prisma.module';
import { UserModule } from '../user/user.module';

@Module({
  imports: [PrismaModule, UserModule],
  controllers: [BranchesController],
  providers: [BranchesService, AdminGuard],
})
export class BranchesModule {}