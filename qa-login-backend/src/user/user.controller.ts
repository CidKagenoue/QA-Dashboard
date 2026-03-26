import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Req,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import { AdminGuard } from '../accounts/admin.guard';
import { AuthenticatedRequest } from '../auth/jwt-auth.guard';
import { UserService } from './user.service';
import { UpdateUserDto } from './dto/update-user.dto';

@Controller('users')
export class UserController {
  constructor(private userService: UserService) {}

  @Get()
  @UseGuards(AdminGuard)
  findAll() {
    return this.userService.findAll();
  }

  @Get(':id')
  async findById(
    @Param('id', ParseIntPipe) id: number,
    @Req() req: AuthenticatedRequest,
  ) {
    await this.assertSelfOrAdmin(req, id);
    return this.userService.findManagedById(id);
  }

  @Patch(':id')
  async update(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateUserDto,
    @Req() req: AuthenticatedRequest,
  ) {
    await this.assertSelfOrAdmin(req, id);
    return this.userService.update(id, dto);
  }

  private async assertSelfOrAdmin(
    req: AuthenticatedRequest,
    requestedUserId: number,
  ) {
    const actorId = this.readActorId(req);
    if (actorId == requestedUserId) {
      return;
    }

    const actor = await this.userService.findById(actorId);
    if (!actor) {
      throw new UnauthorizedException('User does not exist');
    }

    if (!actor.isAdmin) {
      throw new ForbiddenException('Admin access is required');
    }
  }

  private readActorId(req: AuthenticatedRequest) {
    if (!req.user || typeof req.user === 'string') {
      throw new UnauthorizedException('Invalid token payload');
    }

    const actorId = typeof req.user.sub === 'number'
        ? req.user.sub
        : Number(req.user.sub);

    if (!Number.isInteger(actorId) || actorId <= 0) {
      throw new UnauthorizedException('Invalid token subject');
    }

    return actorId;
  }
}
