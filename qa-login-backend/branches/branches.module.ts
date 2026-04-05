import { Module } from '@nestjs/common';
import { AdminGuard } from 'src/accounts/admin.guard';
import { BranchesService } from './branches.service';
import { BranchesController } from './branches.controller';
import { PrismaModule } from 'src/prisma/prisma.module';
import { UserModule } from 'src/user/user.module';

@Module({
  imports: [PrismaModule, UserModule],
  controllers: [BranchesController],
  providers: [BranchesService, AdminGuard],
})
export class BranchesModule {}
