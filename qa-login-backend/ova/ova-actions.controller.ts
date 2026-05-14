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
import { OvaActionsService } from './ova-actions.service';

@UseGuards(JwtAuthGuard)
@Controller('ova/actions')
export class OvaActionsController {
  constructor(private readonly ovaActionsService: OvaActionsService) {}

  /**
   * GET /ova/actions/my
   * Retrieves all follow-up actions assigned to the logged-in user.
   */
  @Get('my')
  async getMyActions(@Request() req) {
    const userId: number = req.user.sub ?? req.user.id ?? req.user.userId;
    const actions = await this.ovaActionsService.findByAssignee(userId);
    return { actions };
  }

  /**
   * PATCH /ova/actions/:id
   * Updates the status of a specific follow-up action.
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