import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { AppController } from './app.controller';
import { AuthModule } from './auth/auth.module';
import { JwtAuthGuard } from './auth/jwt-auth.guard';
import { PrismaModule } from './prisma/prisma.module';
import { UserModule } from './user/user.module';
import { DepartmentsModule } from './department/department.module';
import { LocationsModule } from '../locations/locations.module';
import { BranchesModule } from 'branches/branches.module';

@Module({
  imports: [PrismaModule, AuthModule, UserModule, DepartmentsModule, BranchesModule, LocationsModule],
  controllers: [AppController],
  providers: [
    {
      provide: APP_GUARD,
      useClass: JwtAuthGuard,
    },
  ],
})
export class AppModule {}