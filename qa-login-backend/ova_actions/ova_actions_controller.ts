// qa-login-backend/src/ova/ova-actions.controller.ts
import {
  Controller,
  Get,
  Patch,
  Param,
  Body,
  ParseIntPipe,
  UseGuards,
  Request,
} from '@nestjs/common';
import { JwtAuthGuard } from 'src/auth/jwt-auth.guard';
import { OvaActionsService } from './ova_actions_service';

@UseGuards(JwtAuthGuard)
@Controller('ova/actions')
export class OvaActionsController {
  constructor(private readonly ovaActionsService: OvaActionsService) {}

  /**
   * GET /ova/actions/my
   * Geeft alle opvolgacties terug die zijn toegewezen aan de ingelogde gebruiker.
   */
  @Get('my')
  async getMyActions(@Request() req) {
    // JWT payload kan 'sub', 'id', of 'userId' bevatten afhankelijk van je auth setup
    const userId: number = req.user.sub ?? req.user.id ?? req.user.userId;
    const actions = await this.ovaActionsService.findByAssignee(userId);
    return { actions };
  }

  /**
   * PATCH /ova/actions/:id
   * Wijzigt de status van een specifieke opvolgactie.
   */
  @Patch(':id')
  async updateAction(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { status?: string },
  ) {
    const action = await this.ovaActionsService.updateAction(id, body);
    return { action };
  }
}