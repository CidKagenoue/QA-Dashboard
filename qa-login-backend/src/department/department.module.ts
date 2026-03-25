// src/departments/departments.module.ts
import { Module } from '@nestjs/common';
import { DepartmentsController } from './department.controller';
import { DepartmentsService } from './department.service';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [DepartmentsController],
  providers: [DepartmentsService],
})
export class DepartmentsModule {}