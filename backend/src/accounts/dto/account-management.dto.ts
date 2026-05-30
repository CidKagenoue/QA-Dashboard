import {
  IsArray,
  IsBoolean,
  IsEmail,
  IsInt,
  IsOptional,
  IsString,
} from 'class-validator';

export class CreateAccountDto {
  @IsEmail()
  email!: string;

  // Sterkte wordt afgedwongen door het wachtwoordbeleid in de service.
  @IsString()
  password!: string;

  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsArray()
  @IsInt({ each: true })
  departmentIds?: number[];

  @IsOptional()
  @IsBoolean()
  isAdmin?: boolean;

  @IsOptional()
  @IsBoolean()
  basisAccess?: boolean;

  @IsOptional()
  @IsBoolean()
  whsToursAccess?: boolean;

  @IsOptional()
  @IsBoolean()
  ovaAccess?: boolean;

  @IsOptional()
  @IsBoolean()
  japGppAccess?: boolean;

  @IsOptional()
  @IsBoolean()
  maintenanceInspectionsAccess?: boolean;

  // Notification preferences
  @IsOptional()
  @IsBoolean()
  notifyWhsTours?: boolean;

  @IsOptional()
  @IsBoolean()
  notifyOva?: boolean;

  @IsOptional()
  @IsBoolean()
  notifyJapGpp?: boolean;

  @IsOptional()
  @IsBoolean()
  notifyMaintenance?: boolean;
}

export class UpdateAccountAccessDto {
  @IsOptional()
  @IsBoolean()
  isAdmin?: boolean;

  @IsOptional()
  @IsBoolean()
  basisAccess?: boolean;

  @IsOptional()
  @IsBoolean()
  whsToursAccess?: boolean;

  @IsOptional()
  @IsBoolean()
  ovaAccess?: boolean;

  @IsOptional()
  @IsBoolean()
  japGppAccess?: boolean;

  @IsOptional()
  @IsBoolean()
  maintenanceInspectionsAccess?: boolean;

  // Notification preferences
  @IsOptional()
  @IsBoolean()
  notifyWhsTours?: boolean;

  @IsOptional()
  @IsBoolean()
  notifyOva?: boolean;

  @IsOptional()
  @IsBoolean()
  notifyJapGpp?: boolean;

  @IsOptional()
  @IsBoolean()
  notifyMaintenance?: boolean;
}

export class UpdateAccountDetailsDto {
  @IsOptional()
  @IsEmail()
  email?: string;

  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsString()
  password?: string;
}

// For updating only notification settings
export class UpdateNotificationSettingsDto {
  @IsOptional()
  @IsBoolean()
  notifyWhsTours?: boolean;

  @IsOptional()
  @IsBoolean()
  notifyOva?: boolean;

  @IsOptional()
  @IsBoolean()
  notifyJapGpp?: boolean;

  @IsOptional()
  @IsBoolean()
  notifyMaintenance?: boolean;
}
