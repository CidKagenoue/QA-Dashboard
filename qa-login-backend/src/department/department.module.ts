// src/departments/departments.module.ts
import { Module } from '@nestjs/common';
import { AdminGuard } from '../accounts/admin.guard';
import { DepartmentsController } from './department.controller';
import { DepartmentsService } from './department.service';
import { PrismaModule } from '../prisma/prisma.module';
import { UserModule } from '../user/user.module';

@Module({
  imports: [PrismaModule, UserModule],
  controllers: [DepartmentsController],
  providers: [DepartmentsService, AdminGuard],
})
export class DepartmentsModule {}
