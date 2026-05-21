import { Module } from '@nestjs/common';
import { AdminGuard } from '../accounts/admin.guard';
import { LocationsService } from './locations.service';
import { LocationsController } from './locations.controller';
import { PrismaModule } from '../prisma/prisma.module';
import { UserModule } from '../user/user.module';

@Module({
  imports: [PrismaModule, UserModule],
  controllers: [LocationsController],
  providers: [LocationsService, AdminGuard],
})
export class LocationsModule {}