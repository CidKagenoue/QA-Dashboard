import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  Req,
  UnauthorizedException,
} from '@nestjs/common';
import { AuthenticatedRequest } from '../auth/jwt-auth.guard';
import {
  CreateOvaTicketDto,
  UpdateOvaFollowUpActionDto,
  UpdateOvaTicketDto,
} from './dto/ova-ticket.dto';
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

  @Get('tickets/assignable-users')
  async listAssignableUsers(@Req() req: AuthenticatedRequest) {
    return this.ovaService.listAssignableUsers(this.readActorId(req));
  }

  @Get('tickets/external-contacts')
  async listExternalContacts(
    @Req() req: AuthenticatedRequest,
    @Query('query') query?: string,
  ) {
    return this.ovaService.listExternalContacts(this.readActorId(req), query);
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

  @Get('actions/my')
  async listMyActions(@Req() req: AuthenticatedRequest) {
    return this.ovaService.listMyActions(this.readActorId(req));
  }

  @Patch('actions/:id')
  async updateAction(
    @Param('id', ParseIntPipe) actionId: number,
    @Body() updateOvaFollowUpActionDto: UpdateOvaFollowUpActionDto,
    @Req() req: AuthenticatedRequest,
  ) {
    return this.ovaService.updateAction(
      actionId,
      this.readActorId(req),
      updateOvaFollowUpActionDto,
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
