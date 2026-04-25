import { Body, Controller, Get, Patch, Req, UseGuards } from '@nestjs/common';
import { NotificationSettingsService } from './notification-settings.service';
import { UpdateNotificationSettingDto } from './notification-settings.dto';
import { AuthenticatedRequest } from '../auth/jwt-auth.guard';
import { JwtPayload } from 'jsonwebtoken';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@Controller('notification-settings')
@UseGuards(JwtAuthGuard)
export class NotificationSettingsController {
  constructor(private readonly service: NotificationSettingsService) {}

  @Get()
  async getAll(@Req() req: AuthenticatedRequest) {
    const user = req.user as JwtPayload;
    const userId = user.id ?? user.sub;
    const settings = await this.service.getAllForUser(Number(userId));
    return { settings };
  }

  @Patch()
  async update(@Req() req: AuthenticatedRequest, @Body() body: { settings: UpdateNotificationSettingDto[] }) {
    const user = req.user as JwtPayload;
    const userId = user.id ?? user.sub;
    console.log('PATCH /notification-settings called');
    console.log('userId:', userId);
    console.log('body:', JSON.stringify(body));
    if (!body.settings || !Array.isArray(body.settings)) {
      console.error('Invalid body, missing settings array');
      return { success: false, error: 'Missing settings array' };
    }
    await this.service.replaceAllForUser(Number(userId), body.settings);
    return { success: true };
  }
}
