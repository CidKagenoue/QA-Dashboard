import { Module } from '@nestjs/common';
import { PrismaModule } from 'src/prisma/prisma.module';
import { UserModule } from 'src/user/user.module';
import { MaintenanceInspectionsController } from './maintenance-inspections.controller';
import { MaintenanceInspectionsService } from './maintenance-inspections.service';

@Module({
  imports: [PrismaModule, UserModule],
  controllers: [MaintenanceInspectionsController],
  providers: [MaintenanceInspectionsService],
})
export class MaintenanceInspectionsModule {}
