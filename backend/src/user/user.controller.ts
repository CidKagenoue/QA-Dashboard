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
  async findAll() {
    const users = await this.userService.findAll();
    return users.map((user) => ({
      ...user,
      departments: user.departments.map((d) => d.department),
    }));
  }

  @Get(':id')
  async findById(
    @Param('id', ParseIntPipe) id: number,
    @Req() req: AuthenticatedRequest,
  ) {
    await this.assertSelfOrAdmin(req, id);
    const user = await this.userService.findManagedById(id);
    return {
      ...user,
      departments: user.departments.map((d) => d.department),
    };
  }

  @Patch(':id')
  async update(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateUserDto,
    @Req() req: AuthenticatedRequest,
  ) {
    const { isAdmin } = await this.assertSelfOrAdmin(req, id);

    // Whitelist: via deze route mogen enkel profielvelden gewijzigd worden.
    // Rechten (isAdmin / *Access) lopen uitsluitend via accountbeheer, zodat
    // een gebruiker zichzelf hier nooit kan promoveren.
    const safeUpdate: UpdateUserDto = {};
    if (dto.name !== undefined) safeUpdate.name = dto.name;
    if (dto.email !== undefined) safeUpdate.email = dto.email;
    if (dto.profileImage !== undefined) safeUpdate.profileImage = dto.profileImage;
    // Afdelingen bepalen welke data je ziet → alleen admins mogen ze wijzigen.
    if (isAdmin && dto.departmentIds !== undefined) {
      safeUpdate.departmentIds = dto.departmentIds;
    }

    const user = await this.userService.update(id, safeUpdate);
    return {
      ...user,
      departments: user.departments.map((d) => d.department),
    };
  }

  private async assertSelfOrAdmin(
    req: AuthenticatedRequest,
    requestedUserId: number,
  ): Promise<{ isAdmin: boolean }> {
    const actorId = this.readActorId(req);
    const actor = await this.userService.findById(actorId);
    if (!actor) {
      throw new UnauthorizedException('User does not exist');
    }

    if (actorId === requestedUserId) {
      return { isAdmin: actor.isAdmin };
    }

    if (!actor.isAdmin) {
      throw new ForbiddenException('Admin access is required');
    }

    return { isAdmin: true };
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
