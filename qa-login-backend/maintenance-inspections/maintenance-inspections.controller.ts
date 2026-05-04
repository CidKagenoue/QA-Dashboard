import {
  Body,
  Controller,
  Delete,
  ForbiddenException,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Req,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import { UserService } from 'src/user/user.service';
import { AuthenticatedRequest } from 'src/auth/jwt-auth.guard';
import { JwtAuthGuard } from 'src/auth/jwt-auth.guard';
import {
  CreateMaintenanceInspectionDto,
  UpdateMaintenanceInspectionDto,
} from './dto/create_maintenance_inspection.dto';
import { MaintenanceInspectionsService } from './maintenance-inspections.service';

@UseGuards(JwtAuthGuard)
@Controller('maintenance-inspections')
export class MaintenanceInspectionsController {
  constructor(
    private readonly maintenanceInspectionsService: MaintenanceInspectionsService,
    private readonly userService: UserService,
  ) {}

  @Get('form-data')
  async getFormData(@Req() req: AuthenticatedRequest) {
    await this.assertAccess(req);
    return this.maintenanceInspectionsService.getFormData();
  }

  @Get()
  async findAll(@Req() req: AuthenticatedRequest) {
    await this.assertAccess(req);
    return this.maintenanceInspectionsService.findAll();
  }

  @Get(':id')
  async findOne(
    @Param('id', ParseIntPipe) id: number,
    @Req() req: AuthenticatedRequest,
  ) {
    await this.assertAccess(req);
    return this.maintenanceInspectionsService.findOne(id);
  }

  @Post()
  async create(
    @Body() dto: CreateMaintenanceInspectionDto,
    @Req() req: AuthenticatedRequest,
  ) {
    await this.assertAccess(req);
    return this.maintenanceInspectionsService.create(dto);
  }

  @Patch(':id')
  async update(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateMaintenanceInspectionDto,
    @Req() req: AuthenticatedRequest,
  ) {
    await this.assertAccess(req);
    return this.maintenanceInspectionsService.update(id, dto);
  }

  @Delete(':id')
  async remove(
    @Param('id', ParseIntPipe) id: number,
    @Req() req: AuthenticatedRequest,
  ) {
    await this.assertAccess(req);
    return this.maintenanceInspectionsService.remove(id);
  }

  private async assertAccess(req: AuthenticatedRequest) {
    const actorId = this.readActorId(req);
    const user = await this.userService.findById(actorId);

    if (!user) {
      throw new UnauthorizedException('User does not exist');
    }

    if (!user.isAdmin && !user.maintenanceInspectionsAccess) {
      throw new ForbiddenException('Maintenance access is required');
    }
  }

  private readActorId(req: AuthenticatedRequest) {
    if (!req.user || typeof req.user === 'string') {
      throw new UnauthorizedException('Invalid token payload');
    }

    const actorId =
      typeof req.user.sub === 'number' ? req.user.sub : Number(req.user.sub);

    if (!Number.isInteger(actorId) || actorId <= 0) {
      throw new UnauthorizedException('Invalid token subject');
    }

    return actorId;
  }
}
