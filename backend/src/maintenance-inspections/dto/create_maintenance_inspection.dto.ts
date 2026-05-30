import {
  IsArray,
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
} from 'class-validator';

export class CreateMaintenanceInspectionDto {
  @IsOptional()
  @IsString()
  equipment?: string;

  @IsOptional()
  @IsString()
  inspectionType?: string;

  @IsOptional()
  @IsString()
  inspectionInstitution?: string;

  @IsOptional()
  @IsString()
  contactInfo?: string | null;

  @IsOptional()
  @IsArray()
  @IsInt({ each: true })
  locationIds?: number[];

  @IsOptional()
  @IsString()
  frequency?: string;

  @IsOptional()
  @IsBoolean()
  selfContact?: boolean;

  @IsOptional()
  @IsString()
  lastInspectionDate?: string | null;

  @IsOptional()
  @IsString()
  dueDate?: string;

  @IsOptional()
  @IsString()
  status?: string | null;

  @IsOptional()
  @IsString()
  notes?: string | null;
}

export class UpdateMaintenanceInspectionDto extends CreateMaintenanceInspectionDto {}
