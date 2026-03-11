import { Injectable } from '@nestjs/common';
import { PrismaService } from './prisma/prisma.service';

@Injectable()
export class AppService {
  constructor(private readonly prisma: PrismaService) {}

  getHealth() {
    return { status: 'ok', timestamp: new Date().toISOString() };
  }

  async getUsers() {
    return this.prisma.user.findMany();
  }
}
