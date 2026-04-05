import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { BranchesModule } from '../branches/branches.module';
import { LocationsModule } from '../locations/locations.module';
import { AccountsModule } from './accounts/accounts.module';
import { AppController } from './app.controller';
import { AuthModule } from './auth/auth.module';
import { JwtAuthGuard } from './auth/jwt-auth.guard';
import { DepartmentsModule } from './department/department.module';
import { OvaModule } from './ova/ova.module';
import { PrismaModule } from './prisma/prisma.module';
import { UserModule } from './user/user.module';

@Module({
  imports: [
    PrismaModule,
    AuthModule,
    UserModule,
    DepartmentsModule,
    AccountsModule,
    BranchesModule,
    LocationsModule,
    OvaModule,
  ],
  controllers: [AppController],
  providers: [
    {
      provide: APP_GUARD,
      useClass: JwtAuthGuard,
    },
  ],
})
export class AppModule {}
