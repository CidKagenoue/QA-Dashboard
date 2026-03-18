import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AuthModule } from './auth/auth.module';
import { UserModule } from './user/user.module';
import { PrismaModule } from './auth/prisma/prisma.module';
import { DepartmentModule } from './department/department.module';


@Module({
  imports: [PrismaModule, AuthModule, UserModule, DepartmentModule],
  controllers: [AppController],
})
export class AppModule {}