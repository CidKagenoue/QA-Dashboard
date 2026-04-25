

import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateNotificationSettingDto } from './notification-settings.dto';
import { NotificationType } from '@prisma/client';


@Injectable()
export class NotificationSettingsService {
  constructor(private prisma: PrismaService) {}

  /**
   * Checks if a notification (or email) should be sent for a user, type, and module.
   * @param userId - The user ID
   * @param type - The notification type (NotificationType)
   * @param module - The notification module (string or enum)
   * @param channel - 'inApp' | 'email' (default: 'inApp')
   * @returns Promise<boolean>
   */
  async shouldSendNotification(userId: number, type: NotificationType, module: string, channel: 'inApp' | 'email' = 'inApp'): Promise<boolean> {
    const setting = await this.prisma.notificationSetting.findUnique({
      where: {
        userId_type: {
          userId,
          type,
        },
      },
    });
    if (!setting) return true; // Default: send if no setting exists
    if (channel === 'inApp') return !!setting.enabled;
    if (channel === 'email') return !!setting.email;
    return false;
  }

  async getAllForUser(userId: number) {
    return this.prisma.notificationSetting.findMany({
      where: { userId },
    });
  }

  async updateOrCreate(userId: number, dto: UpdateNotificationSettingDto) {
    return this.prisma.notificationSetting.upsert({
      where: {
        userId_type: {
          userId,
          type: dto.type,
        },
      },
      update: {
        enabled: dto.enabled,
        email: dto.email,
      },
      create: {
        userId,
        module: dto.module,
        type: dto.type,
        enabled: dto.enabled,
        email: dto.email,
      },
    });
  }

  async replaceAllForUser(userId: number, settings: UpdateNotificationSettingDto[]) {
    // Verwijder alle bestaande settings voor deze gebruiker
    await this.prisma.notificationSetting.deleteMany({ where: { userId } });

    // Filter dubbele type's eruit (laatste waarde blijft over bij dubbele type)
    const uniqueSettingsMap = new Map();
    for (const s of settings) {
      uniqueSettingsMap.set(s.type, s);
    }
    const uniqueSettings = Array.from(uniqueSettingsMap.values());

    // Voeg alle unieke settings toe
    if (uniqueSettings.length > 0) {
      await this.prisma.notificationSetting.createMany({
        data: uniqueSettings.map(s => ({
          userId,
          module: s.module,
          type: s.type,
          enabled: s.enabled,
          email: s.email,
        })),
      });
    }
  }
}

// Cleaned up duplicate code. File should end with the class closing brace above.
