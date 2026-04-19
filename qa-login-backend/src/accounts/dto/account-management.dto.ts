export class CreateAccountDto {
  email!: string;
  password!: string;
  name?: string;
  departmentIds?: number[];
  isAdmin?: boolean;
  basisAccess?: boolean;
  whsToursAccess?: boolean;
  ovaAccess?: boolean;
  japGppAccess?: boolean;
  maintenanceInspectionsAccess?: boolean;
  // Notification preferences
  notifyWhsTours?: boolean;
  notifyOva?: boolean;
  notifyJapGpp?: boolean;
  notifyMaintenance?: boolean;
}

export class UpdateAccountAccessDto {
  isAdmin?: boolean;
  basisAccess?: boolean;
  whsToursAccess?: boolean;
  ovaAccess?: boolean;
  japGppAccess?: boolean;
  maintenanceInspectionsAccess?: boolean;
  // Notification preferences
  notifyWhsTours?: boolean;
  notifyOva?: boolean;
  notifyJapGpp?: boolean;
  notifyMaintenance?: boolean;
}

// For updating only notification settings
export class UpdateNotificationSettingsDto {
  notifyWhsTours?: boolean;
  notifyOva?: boolean;
  notifyJapGpp?: boolean;
  notifyMaintenance?: boolean;
}
