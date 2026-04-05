import { Module } from '@nestjs/common';
import { AdminGuard } from 'src/accounts/admin.guard';
import { LocationsService } from './locations.service';
import { LocationsController } from './locations.controller';
import { PrismaModule } from 'src/prisma/prisma.module';
import { UserModule } from 'src/user/user.module';

@Module({
  imports: [PrismaModule, UserModule],
  controllers: [LocationsController],
  providers: [LocationsService, AdminGuard],
})
export class LocationsModule {}
