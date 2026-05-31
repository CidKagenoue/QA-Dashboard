import { Module } from '@nestjs/common';
import { DomainController } from './domain.controller';
import { DomainService } from './domain.service';
import { PrismaModule } from '../prisma/prisma.module';
import { UserModule } from '../user/user.module';
import { JapGppAccessGuard } from '../jap-gpp/jap-gpp-access.guard';

@Module({
  imports: [PrismaModule, UserModule],
  controllers: [DomainController],
  providers: [DomainService, JapGppAccessGuard],
  exports: [DomainService],
})
export class DomainModule {}
