import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { UserModule } from '../user/user.module';
import { OvaController } from './ova.controller';
import { OvaService } from './ova.service';

@Module({
  imports: [PrismaModule, UserModule],
  controllers: [OvaController],
  providers: [OvaService],
})
export class OvaModule {}
