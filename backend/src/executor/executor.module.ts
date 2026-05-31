import { Module } from '@nestjs/common';
import { ExecutorController } from './executor.controller';
import { ExecutorService } from './executor.service';
import { PrismaModule } from '../prisma/prisma.module';
import { UserModule } from '../user/user.module';
import { JapGppAccessGuard } from '../jap-gpp/jap-gpp-access.guard';

@Module({
  imports: [PrismaModule, UserModule],
  controllers: [ExecutorController],
  providers: [ExecutorService, JapGppAccessGuard],
  exports: [ExecutorService],
})
export class ExecutorModule {}
