import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Req,
  UnauthorizedException,
} from '@nestjs/common';
import { AuthenticatedRequest } from '../auth/jwt-auth.guard';
import { CreateOvaTicketDto, UpdateOvaTicketDto } from './dto/ova-ticket.dto';
import { OvaService } from './ova.service';

@Controller('ova')
export class OvaController {
  constructor(private readonly ovaService: OvaService) {}

  @Get('tickets')
  async listTickets(@Req() req: AuthenticatedRequest) {
    return this.ovaService.listTickets(this.readActorId(req));
  }

  @Post('tickets')
  async createTicket(
    @Body() createOvaTicketDto: CreateOvaTicketDto,
    @Req() req: AuthenticatedRequest,
  ) {
    return this.ovaService.createTicket(
      this.readActorId(req),
      createOvaTicketDto,
    );
  }

  @Get('tickets/:id')
  async getTicket(
    @Param('id', ParseIntPipe) ticketId: number,
    @Req() req: AuthenticatedRequest,
  ) {
    return this.ovaService.getTicket(ticketId, this.readActorId(req));
  }

  @Patch('tickets/:id')
  async updateTicket(
    @Param('id', ParseIntPipe) ticketId: number,
    @Body() updateOvaTicketDto: UpdateOvaTicketDto,
    @Req() req: AuthenticatedRequest,
  ) {
    return this.ovaService.updateTicket(
      ticketId,
      this.readActorId(req),
      updateOvaTicketDto,
    );
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
