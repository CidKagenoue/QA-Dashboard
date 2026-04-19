import { NotificationModule, NotificationType } from '@prisma/client';

export class UpdateNotificationSettingDto {
  module: NotificationModule;
  type: NotificationType;
  enabled: boolean;
  email: boolean;
}

export class NotificationSettingDto {
  id: number;
  module: NotificationModule;
  type: NotificationType;
  enabled: boolean;
  email: boolean;
  createdAt: Date;
  updatedAt: Date;
}
