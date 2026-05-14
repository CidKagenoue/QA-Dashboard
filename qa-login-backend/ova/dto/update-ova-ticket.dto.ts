// qa-login-backend/src/ova/dto/update-ova-ticket.dto.ts
import { IsString, IsEnum, IsOptional, IsArray, IsDateString } from 'class-validator';

export class UpdateOvaTicketDto {
  @IsOptional()
  @IsEnum(['incomplete', 'in_progress', 'completed', 'closed'])
  status?: string;

  @IsOptional()
  @IsString()
  ovaType?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  reasons?: string[];

  @IsOptional()
  @IsString()
  otherReason?: string;

  @IsOptional()
  @IsString()
  description?: string; // Maps to incidentDescription

  @IsOptional()
  @IsString()
  causeAnalysisMethod?: string;

  @IsOptional()
  @IsString()
  causeAnalysisNotes?: string;

  @IsOptional()
  @IsString()
  followUpActions?: string;

  @IsOptional()
  @IsDateString()
  effectivenessDate?: string;

  @IsOptional()
  @IsString()
  effectivenessNotes?: string;

  @IsOptional()
  @IsString()
  resolution?: string; 

  @IsOptional()
  @IsString()
  priority?: string; 
}