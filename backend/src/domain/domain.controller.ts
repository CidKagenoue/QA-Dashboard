import { Controller, Get, Post, Delete, Body, Param, UseGuards, HttpCode, BadRequestException } from '@nestjs/common';
import { DomainService } from './domain.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@Controller('domain')
@UseGuards(JwtAuthGuard)
export class DomainController {
  constructor(private readonly domainService: DomainService) {}

  @Get()
  async findAll() {
    const domains = await this.domainService.findAll();
    return { domains };
  }

  @Post()
  async create(@Body() body: { name: string }) {
    if (!body.name || body.name.trim().length === 0) {
      throw new BadRequestException('Domain name is required');
    }

    try {
      const domain = await this.domainService.create(body.name.trim());
      return { domain };
    } catch (error) {
      if (error.code === 'P2002') {
        throw new BadRequestException('Domain already exists');
      }
      throw error;
    }
  }

  @Delete(':id')
  @HttpCode(204)
  async delete(@Param('id') id: string) {
    const domainId = parseInt(id, 10);
    if (isNaN(domainId)) {
      throw new BadRequestException('Invalid domain ID');
    }
    await this.domainService.delete(domainId);
  }
}
