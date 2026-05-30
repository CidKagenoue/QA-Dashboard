import {
  IsArray,
  IsInt,
  IsOptional,
  IsString,
} from 'class-validator';

// Geneste typen (alleen gebruikt binnen CreateOvaTicketDto.actions). Ze worden
// niet rechtstreeks als @Body gevalideerd; het bovenliggende `actions`-veld is
// bewust enkel @IsArray zodat de geneste velden niet gestript worden.
export class OvaExternalResponsibleDto {
  id?: number;
  firstName?: string | null;
  lastName?: string | null;
  email?: string | null;
}

export class OvaFollowUpActionDto {
  id?: number;
  type?: string | null;
  description?: string | null;
  dueDate?: string | null;
  status?: string | null;
  assigneeType?: string | null;
  internalAssigneeId?: number | null;
  externalResponsible?: OvaExternalResponsibleDto | null;
}

export class UpdateOvaFollowUpActionDto {
  @IsOptional()
  @IsString()
  status?: string | null;
}

export class CreateOvaTicketDto {
  @IsOptional()
  @IsString()
  findingDate?: string | null;

  @IsOptional()
  @IsString()
  ovaType?: string | null;

  @IsOptional()
  @IsInt()
  departmentId?: number | null;

  @IsOptional()
  @IsInt()
  branchId?: number | null;

  @IsOptional()
  @IsString()
  departmentFallback?: string | null;

  @IsOptional()
  @IsString()
  branchFallback?: string | null;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  reasons?: string[];

  @IsOptional()
  @IsString()
  otherReason?: string | null;

  @IsOptional()
  @IsString()
  incidentDescription?: string | null;

  @IsOptional()
  @IsString()
  causeAnalysisMethod?: string | null;

  @IsOptional()
  @IsString()
  causeAnalysisNotes?: string | null;

  @IsOptional()
  @IsString()
  followUpActions?: string | null;

  @IsOptional()
  @IsArray()
  actions?: OvaFollowUpActionDto[];

  @IsOptional()
  @IsString()
  effectivenessDate?: string | null;

  @IsOptional()
  @IsString()
  effectivenessNotes?: string | null;

  @IsOptional()
  @IsString()
  closureNotes?: string | null;

  @IsOptional()
  @IsInt()
  currentStep?: number;

  @IsOptional()
  @IsString()
  status?: string;
}

export class UpdateOvaTicketDto extends CreateOvaTicketDto {}
