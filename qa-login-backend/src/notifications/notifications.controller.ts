import {
  Body,
  Controller,
  Get,
  Patch,
  Query,
  Req,
  UnauthorizedException,
} from '@nestjs/common';
import { AuthenticatedRequest } from '../auth/jwt-auth.guard';
import { NotificationsService } from './notifications.service';

@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Get()
  async listMine(
    @Req() req: AuthenticatedRequest,
    @Query('limit') limit?: string,
  ) {
    const parsedLimit = Number(limit);
    return this.notificationsService.listForUser(this.readActorId(req), {
      limit: Number.isInteger(parsedLimit) && parsedLimit > 0
        ? Math.min(parsedLimit, 100)
        : 50,
    });
  }

  @Get('unread-count')
  async unreadCount(@Req() req: AuthenticatedRequest) {
    return this.notificationsService.getUnreadCount(this.readActorId(req));
  }

  @Patch('mark-read')
  async markRead(
    @Req() req: AuthenticatedRequest,
    @Body() body: { notificationIds: number[] },
  ) {
    return this.notificationsService.markRead(
      this.readActorId(req),
      body?.notificationIds ?? [],
    );
  }

  @Patch('mark-all-read')
  async markAllRead(@Req() req: AuthenticatedRequest) {
    return this.notificationsService.markAllRead(this.readActorId(req));
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
