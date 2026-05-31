import { BadRequestException, Body, Controller, Delete, Get, HttpCode, Param, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { JapGppAccessGuard } from '../jap-gpp/jap-gpp-access.guard';
import { ExecutorService } from './executor.service';

@Controller('executor')
@UseGuards(JwtAuthGuard, JapGppAccessGuard)
export class ExecutorController {
  constructor(private readonly executorService: ExecutorService) {}

  @Get()
  async findAll() {
    const executors = await this.executorService.findAll();
    return { executors };
  }

  @Post()
  async create(@Body() body: { name: string }) {
    if (!body.name || body.name.trim().length === 0) {
      throw new BadRequestException('Executor name is required');
    }

    try {
      const executor = await this.executorService.create(body.name.trim());
      return { executor };
    } catch (error) {
      if (error.code === 'P2002') {
        throw new BadRequestException('Executor already exists');
      }
      throw error;
    }
  }

  @Delete(':name')
  @HttpCode(204)
  async delete(@Param('name') name: string) {
    if (!name || name.trim().length === 0) {
      throw new BadRequestException('Invalid executor name');
    }

    await this.executorService.deleteByName(name.trim());
  }
}
