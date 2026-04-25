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
import { NotificationService } from './notifications.service';

@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notificationService: NotificationService) {}

  @Get()
  async listMine(
    @Req() req: AuthenticatedRequest,
    @Query('limit') limit?: string,
  ) {
    const parsedLimit = Number(limit);
    return this.notificationService.listForUser(this.readActorId(req), {
      limit: Number.isInteger(parsedLimit) && parsedLimit > 0
        ? Math.min(parsedLimit, 100)
        : 50,
    });
  }

  @Get('unread-count')
  async unreadCount(@Req() req: AuthenticatedRequest) {
    return this.notificationService.getUnreadCount(this.readActorId(req));
  }

  @Patch('mark-read')
  async markRead(
    @Req() req: AuthenticatedRequest,
    @Body() body: { notificationIds: number[] },
  ) {
    return this.notificationService.markRead(
      this.readActorId(req),
      body?.notificationIds ?? [],
    );
  }

  @Patch('mark-all-read')
  async markAllRead(@Req() req: AuthenticatedRequest) {
    return this.notificationService.markAllRead(this.readActorId(req));
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
