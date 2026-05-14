// qa-login-backend/src/ova/ova-tickets.controller.ts
import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Body,
  ParseIntPipe,
  UseGuards,
  Request,
  UnauthorizedException,
  ForbiddenException,
} from '@nestjs/common';
import { JwtAuthGuard, AuthenticatedRequest } from 'src/auth/jwt-auth.guard';
import { OvaTicketsService } from './ova-tickets.service';
import { UserService } from 'src/user/user.service';
import { UpdateOvaTicketDto } from './dto/update-ova-ticket.dto';

@UseGuards(JwtAuthGuard)
@Controller('ova/tickets')
export class OvaTicketsController {
  constructor(
    private readonly ovaTicketsService: OvaTicketsService,
    private readonly userService: UserService,
  ) {}

  @Patch(':id')
  async updateTicket(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateOvaTicketDto,
    @Request() req: AuthenticatedRequest,
  ) {
    await this.assertOvaAccess(req);
    const ticket = await this.ovaTicketsService.update(id, dto);
    return { ticket };
  }

  @Delete(':id')
  async deleteTicket(
    @Param('id', ParseIntPipe) id: number,
    @Request() req: AuthenticatedRequest,
  ) {
    await this.assertOvaAccess(req);
    await this.ovaTicketsService.remove(id);
    return { message: 'Ticket verwijderd' };
  }

  private async assertOvaAccess(req: AuthenticatedRequest) {
    const actorId = this.readActorId(req);
    const user = await this.userService.findById(actorId);

    if (!user) {
      throw new UnauthorizedException('User does not exist');
    }

    if (!user.isAdmin && !user.ovaAccess) {
      throw new ForbiddenException('OVA access is required');
    }
  }

  private readActorId(req: AuthenticatedRequest): number {
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