import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { BranchesModule } from '../branches/branches.module';
import { LocationsModule } from '../locations/locations.module';
import { MaintenanceInspectionsModule } from '../maintenance-inspections/maintenance-inspections.module';
import { AccountsModule } from './accounts/accounts.module';
import { AppController } from './app.controller';
import { AuthModule } from './auth/auth.module';
import { JwtAuthGuard } from './auth/jwt-auth.guard';
import { DepartmentsModule } from './department/department.module';
import { OvaModule } from './ova/ova.module';
import { CustomScheduleModule } from './schedule.module';
import { NotificationSettingsModule } from './notification-settings/notification-settings.module';
import { NotificationsModule } from './notifications/notifications.module';
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
    MaintenanceInspectionsModule,
    OvaModule,
    CustomScheduleModule,
    NotificationSettingsModule,
    NotificationsModule,
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
